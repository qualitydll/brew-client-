package dev.brew.brew

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.github.oviron.libmihomo.Clash
import org.json.JSONObject
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareVpn" -> prepareVpn(result)
                    "validateConfig" -> validateConfig(call.argument("path"), result)
                    "startVpn" -> startVpn(call.argument("configPath"), result)
                    "stopVpn" -> stopVpn(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error(
                "vpn_permission_pending",
                "VPN permission request is already in progress.",
                null,
            )
            return
        }
        permissionResult = result
        startActivityForResult(intent, VPN_PERMISSION_REQUEST)
    }

    private fun validateConfig(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("invalid_config_path", "A configuration file path is required.", null)
            return
        }
        try {
            loadMihomo()
            val action = JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("method", "validateConfig")
                .put("data", path)
            Clash.invokeAction(action.toString()) { response ->
                try {
                    val message = JSONObject(response ?: "")
                        .optString("data")
                        .takeIf { it.isNotBlank() }
                    runOnUiThread { result.success(message) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error(
                            "mihomo_validation_failed",
                            "Could not read Mihomo's validation result: ${error.message}",
                            null,
                        )
                    }
                }
            }
        } catch (error: Exception) {
            result.error("mihomo_load_failed", error.message, null)
        }
    }

    private fun startVpn(configPath: String?, result: MethodChannel.Result) {
        if (configPath.isNullOrBlank()) {
            result.error("invalid_config_path", "A configuration file path is required.", null)
            return
        }
        if (VpnService.prepare(this) != null) {
            result.error("vpn_permission_required", "VPN permission has not been granted.", null)
            return
        }
        val intent = Intent(this, MihomoVpnService::class.java)
            .setAction(MihomoVpnService.ACTION_START)
            .putExtra(MihomoVpnService.EXTRA_CONFIG_PATH, configPath)
            .putExtra(MihomoVpnService.EXTRA_RESULT, resultReceiver(result))
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (error: Exception) {
            result.error("vpn_start_failed", error.message, null)
        }
    }

    private fun stopVpn(result: MethodChannel.Result) {
        val intent = Intent(this, MihomoVpnService::class.java)
            .setAction(MihomoVpnService.ACTION_STOP)
            .putExtra(MihomoVpnService.EXTRA_RESULT, resultReceiver(result))
        try {
            startService(intent)
        } catch (error: Exception) {
            result.error("vpn_stop_failed", error.message, null)
        }
    }

    private fun resultReceiver(result: MethodChannel.Result) =
        object : ResultReceiver(Handler(Looper.getMainLooper())) {
            override fun onReceiveResult(resultCode: Int, data: Bundle?) {
                if (resultCode == Activity.RESULT_OK) {
                    result.success(null)
                } else {
                    result.error(
                        "vpn_service_failed",
                        data?.getString(MihomoVpnService.EXTRA_ERROR)
                            ?: "Mihomo VPN service failed.",
                        null,
                    )
                }
            }
        }

    private fun loadMihomo() {
        Clash.load(applicationInfo.nativeLibraryDir)
        Clash.assertReady()
        check(Clash.bridgeABI() == Clash.EXPECTED_BRIDGE_ABI) {
            "Mihomo JNI bridge ABI mismatch."
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_PERMISSION_REQUEST) {
            val result = permissionResult
            permissionResult = null
            if (resultCode == Activity.RESULT_OK) {
                result?.success(true)
            } else {
                result?.error("vpn_permission_denied", "VPN permission was denied.", null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val CHANNEL = "dev.brew.brew/vpn"
        private const val VPN_PERMISSION_REQUEST = 5201
    }
}
