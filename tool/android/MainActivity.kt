package com.example.brew

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingHomeDir: String? = null

    private val vpnReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val result = pendingStartResult ?: return
            when (intent?.action) {
                BrewVpnService.ACTION_CONNECTED -> {
                    pendingStartResult = null
                    pendingHomeDir = null
                    result.success(true)
                }
                BrewVpnService.ACTION_ERROR -> {
                    pendingStartResult = null
                    pendingHomeDir = null
                    result.error(
                        "VPN_START_FAILED",
                        intent.getStringExtra(BrewVpnService.EXTRA_ERROR) ?: "Не удалось запустить Mihomo",
                        null,
                    )
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter().apply {
            addAction(BrewVpnService.ACTION_CONNECTED)
            addAction(BrewVpnService.ACTION_ERROR)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(vpnReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(vpnReceiver, filter)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "brew/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "mihomoPath" -> result.success(applicationInfo.nativeLibraryDir + "/libmihomo.so")
                    "startVpn" -> {
                        val homeDir = call.argument<String>("homeDir")
                        if (homeDir.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "Не указан каталог конфигурации", null)
                            return@setMethodCallHandler
                        }
                        if (pendingStartResult != null) {
                            result.error("VPN_STARTING", "Подключение уже запускается", null)
                            return@setMethodCallHandler
                        }
                        pendingStartResult = result
                        pendingHomeDir = homeDir
                        val prepareIntent = VpnService.prepare(this)
                        if (prepareIntent != null) {
                            @Suppress("DEPRECATION")
                            startActivityForResult(prepareIntent, REQUEST_VPN_PERMISSION)
                        } else {
                            startVpnService(homeDir)
                        }
                    }
                    "stopVpn" -> {
                        val intent = Intent(this, BrewVpnService::class.java).apply {
                            action = BrewVpnService.ACTION_STOP
                        }
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android API; retained for compatibility with VPN consent flow")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_VPN_PERMISSION) return
        val homeDir = pendingHomeDir
        if (resultCode == RESULT_OK && homeDir != null) {
            startVpnService(homeDir)
        } else {
            pendingStartResult?.error("VPN_PERMISSION_DENIED", "Разрешение на VPN не предоставлено", null)
            pendingStartResult = null
            pendingHomeDir = null
        }
    }

    private fun startVpnService(homeDir: String) {
        val intent = Intent(this, BrewVpnService::class.java).apply {
            action = BrewVpnService.ACTION_START
            putExtra(BrewVpnService.EXTRA_HOME_DIR, homeDir)
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
        } catch (e: Exception) {
            pendingStartResult?.error("VPN_SERVICE_START_FAILED", e.message, null)
            pendingStartResult = null
            pendingHomeDir = null
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(vpnReceiver)
        } catch (_: Exception) {
        }
        pendingStartResult?.error("ACTIVITY_DESTROYED", "Экран приложения закрылся во время подключения", null)
        pendingStartResult = null
        super.onDestroy()
    }

    companion object {
        private const val REQUEST_VPN_PERMISSION = 4217
    }
}
