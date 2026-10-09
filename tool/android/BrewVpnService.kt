package com.example.brew

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import io.github.oviron.libmihomo.Clash
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class BrewVpnService : VpnService() {
    @Volatile private var tun: ParcelFileDescriptor? = null
    @Volatile private var started = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Thread { stopTunnel(); stopSelf(startId) }.start()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val homeDir = intent.getStringExtra(EXTRA_HOME_DIR)
                if (homeDir.isNullOrBlank()) {
                    reportError("Не указан каталог конфигурации")
                    stopSelf(startId)
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, buildNotification("Подключение к серверу…"))
                Thread { startTunnel(homeDir, startId) }.start()
            }
        }
        return START_NOT_STICKY
    }

    private fun startTunnel(homeDir: String, startId: Int) {
        try {
            if (started) {
                stopTunnel()
            }
            val config = File(homeDir, "config.yaml")
            require(config.isFile && config.length() > 0L) {
                "Не найден файл конфигурации Mihomo: ${config.absolutePath}"
            }

            if (!Clash.isLoaded()) {
                Clash.load(applicationInfo.nativeLibraryDir)
            }
            check(Clash.isLoaded()) { "Не удалось загрузить встроенное ядро Mihomo" }

            val builder = Builder()
                .setSession("Brew")
                .setMtu(TUN_MTU)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addAddress("fdfe:dcba:9877::1", 126)
                .addRoute("::", 0)
            val descriptor = builder.establish()
                ?: throw IllegalStateException("Android не создал VPN-интерфейс")
            tun = descriptor

            val setupLatch = CountDownLatch(1)
            var setupError: String? = null
            val initJson = """{"home-dir":${org.json.JSONObject.quote(homeDir)},"version":${Build.VERSION.SDK_INT}}"""
            Clash.quickSetup(initJson, """{"selected-map":{}}""") { message ->
                setupError = message?.takeIf { it.isNotBlank() }
                setupLatch.countDown()
            }
            if (!setupLatch.await(25, TimeUnit.SECONDS)) {
                throw IllegalStateException("Ядро Mihomo не ответило при загрузке конфигурации")
            }
            if (setupError != null) {
                throw IllegalStateException("Ошибка конфигурации Mihomo: $setupError")
            }

            Clash.startTUN(
                descriptor.fd,
                this,
                "brew",
                "system",
                "172.19.0.1/30,fdfe:dcba:9877::1/126",
                "1.1.1.1,8.8.8.8",
                TUN_MTU,
            )
            started = true
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification("VPN подключён"))
            sendBroadcast(Intent(ACTION_CONNECTED).setPackage(packageName))
        } catch (e: Exception) {
            stopTunnel()
            reportError(e.message ?: e.javaClass.simpleName)
            stopSelf(startId)
        }
    }

    override fun protect(fd: Int) {
        super.protect(fd)
    }

    fun resolverProcess(protocol: Int, source: String, target: String, uid: Int): String = ""

    private fun stopTunnel() {
        try {
            if (Clash.isLoaded()) {
                Clash.stopTun()
                val latch = CountDownLatch(1)
                Clash.invokeAction("""{"id":"brew-stop","method":"stopListener"}""") {
                    latch.countDown()
                }
                latch.await(2, TimeUnit.SECONDS)
            }
        } catch (_: Exception) {
        }
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
        started = false
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun reportError(message: String) {
        sendBroadcast(
            Intent(ACTION_ERROR)
                .setPackage(packageName)
                .putExtra(EXTRA_ERROR, message),
        )
    }

    private fun buildNotification(text: String): Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Brew VPN", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0),
        )
        return if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setContentTitle("Brew")
                .setContentText(text)
                .setContentIntent(openApp)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setContentTitle("Brew")
                .setContentText(text)
                .setContentIntent(openApp)
                .setOngoing(true)
                .build()
        }
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "com.qualitydll.brew.START_VPN"
        const val ACTION_STOP = "com.qualitydll.brew.STOP_VPN"
        const val ACTION_CONNECTED = "com.qualitydll.brew.VPN_CONNECTED"
        const val ACTION_ERROR = "com.qualitydll.brew.VPN_ERROR"
        const val EXTRA_HOME_DIR = "homeDir"
        const val EXTRA_ERROR = "error"
        private const val CHANNEL_ID = "brew_vpn"
        private const val NOTIFICATION_ID = 5107
        private const val TUN_MTU = 1500
    }
}
