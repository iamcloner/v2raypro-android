package com.v2raypro.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat

/**
 * Android VpnService implementation for V2RayPro.
 *
 * Responsibilities:
 * - Allocates and manages the Linux TUN virtual network interface
 * - Routes traffic through hev-socks5-tunnel into the local Xray SOCKS inbound
 * - Supports seamless in-place configuration reloads without breaking the TUN interface
 * - Manages the foreground notification and partial wake lock during startup
 * - Performs per-app proxy routing (inclusive/exclusive modes)
 */
class V2RayVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.v2raypro.app.VPN_START"
        const val ACTION_STOP = "com.v2raypro.app.VPN_STOP"
        const val ACTION_DISCONNECT = "com.v2raypro.app.VPN_DISCONNECT"
        const val ACTION_VPN_DISCONNECTED = "com.v2raypro.app.VPN_DISCONNECTED"
        const val CHANNEL_ID = "v2raypro_vpn_channel"
        const val NOTIFICATION_ID = 1001

        var isRunning = false
            private set

        var onDisconnectListener: (() -> Unit)? = null
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var wakeLock: android.os.PowerManager.WakeLock? = null
    private var xrayProcess: java.lang.Process? = null
    private val logLock = Any()

    // Active connection state tracking for seamless config switching
    private var currentSocksPort: Int = 10999
    private var currentIsTun: Boolean = true
    private var currentRoutingMode: String = "exclusive"
    private var currentRoutingList: ArrayList<String> = arrayListOf()

    private val disconnectReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            stopVpn()
            notifyDisconnected()
        }
    }

    private fun notifyDisconnected() {
        onDisconnectListener?.invoke()
        try {
            val notifyIntent = Intent(ACTION_VPN_DISCONNECTED).setPackage(packageName)
            sendBroadcast(notifyIntent)
        } catch (_: Exception) {}
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        val filter = IntentFilter(ACTION_DISCONNECT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(disconnectReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(disconnectReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_STOP || action == ACTION_DISCONNECT) {
            stopVpn()
            if (action == ACTION_DISCONNECT) {
                notifyDisconnected()
            }
            return START_NOT_STICKY
        }

        if (action == ACTION_START) {
            val configName = intent.getStringExtra("configName") ?: "V2RayPro"
            val httpPort = intent.getIntExtra("httpPort", 10888)
            val socksPort = intent.getIntExtra("socksPort", 10999)
            val isTun = intent.getBooleanExtra("isTun", true)
            val notificationTitle = intent.getStringExtra("notificationTitle") ?: "V2RayPro - متصل"
            val disconnectText = intent.getStringExtra("disconnectText") ?: "قطع اتصال"
            val appRoutingMode = intent.getStringExtra("appRoutingMode") ?: "exclusive"
            val appRoutingList = intent.getStringArrayListExtra("appRoutingList") ?: arrayListOf<String>()
            val xrayBinary = intent.getStringExtra("xrayBinary") ?: ""
            val configPath = intent.getStringExtra("configPath") ?: ""
            val assetDir = intent.getStringExtra("assetDir") ?: ""

            startVpn(
                configName,
                httpPort,
                socksPort,
                isTun,
                notificationTitle,
                disconnectText,
                appRoutingMode,
                appRoutingList,
                xrayBinary,
                configPath,
                assetDir
            )
            return START_STICKY
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "V2RayPro VPN"
            val descriptionText = "Active VPN Connection Notification"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(
        configName: String,
        notificationTitle: String,
        disconnectText: String
    ): Notification {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val disconnectIntent = Intent(ACTION_DISCONNECT).setPackage(packageName)
        val disconnectPendingIntent = PendingIntent.getBroadcast(
            this, 1, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(notificationTitle)
            .setContentText(configName)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true) // User cannot swipe away until disconnected
            .setContentIntent(mainPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                disconnectText,
                disconnectPendingIntent
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun startXray(xrayBinary: String, configPath: String, assetDir: String) {
        stopXray()
        if (xrayBinary.isEmpty() || configPath.isEmpty()) return

        try {
            val pb = ProcessBuilder(xrayBinary, "run", "-c", configPath)
            if (assetDir.isNotEmpty() && java.io.File(assetDir).exists()) {
                pb.directory(java.io.File(assetDir))
                pb.environment()["XRAY_LOCATION_ASSET"] = assetDir
            }
            pb.redirectErrorStream(true)
            val proc = pb.start()
            xrayProcess = proc

            Thread {
                try {
                    val logFile = java.io.File(cacheDir, "xray.log")
                    val buffer = StringBuilder()
                    var lineCount = 0

                    proc.inputStream.bufferedReader().use { reader ->
                        var line: String? = reader.readLine()
                        while (proc.isAlive && line != null) {
                            buffer.append(line).append("\n")
                            lineCount++

                            // Bounded batch flushing: avoids continuous disk I/O and CPU spikes
                            if (lineCount >= 20) {
                                synchronized(logLock) {
                                    try {
                                        if (logFile.exists() && logFile.length() > 256 * 1024) {
                                            val lines = logFile.readLines()
                                            val keep = if (lines.size > 150) lines.takeLast(150) else lines
                                            logFile.writeText(keep.joinToString("\n") + "\n")
                                        }
                                        logFile.appendText(buffer.toString())
                                    } catch (_: Exception) {}
                                }
                                buffer.setLength(0)
                                lineCount = 0
                            }
                            line = reader.readLine()
                        }

                        if (buffer.isNotEmpty()) {
                            synchronized(logLock) {
                                try {
                                    logFile.appendText(buffer.toString())
                                } catch (_: Exception) {}
                            }
                        }
                    }
                } catch (_: Exception) {}
            }.start()

            // Wait 200ms to ensure process starts cleanly
            Thread.sleep(200)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopXray() {
        try {
            val proc = xrayProcess
            if (proc != null) {
                proc.destroy()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    proc.destroyForcibly()
                }
                proc.waitFor(300, java.util.concurrent.TimeUnit.MILLISECONDS)
            }
        } catch (_: Exception) {}
        xrayProcess = null
    }

    private fun startVpn(
        configName: String,
        httpPort: Int,
        socksPort: Int,
        isTun: Boolean,
        notificationTitle: String,
        disconnectText: String,
        appRoutingMode: String = "exclusive",
        appRoutingList: ArrayList<String> = arrayListOf(),
        xrayBinary: String = "",
        configPath: String = "",
        assetDir: String = ""
    ) {
        // 1. Check if we can perform a seamless in-place config switch:
        // If VPN is already active, TUN interface is valid, and routing/ports have not changed,
        // we keep the existing VPN interface and hev tunnel intact and simply restart Xray core with the new config!
        val canSeamlessSwitch = isRunning &&
                isTun == currentIsTun &&
                socksPort == currentSocksPort &&
                appRoutingMode == currentRoutingMode &&
                appRoutingList == currentRoutingList &&
                (if (isTun) (vpnInterface != null && vpnInterface?.fileDescriptor?.valid() == true) else true)

        if (canSeamlessSwitch) {
            val notification = createNotification(configName, notificationTitle, disconnectText)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, notification)

            if (xrayBinary.isNotEmpty() && configPath.isNotEmpty()) {
                // 1. Stop old Xray core and allow port release
                stopXray()
                try {
                    Thread.sleep(100)
                } catch (_: Exception) {}

                // 2. Stop old tunnel worker to clean up previous SOCKS sessions
                if (isTun && vpnInterface != null) {
                    try {
                        hev.htproxy.TProxyService.TProxyStopService()
                    } catch (_: Exception) {}
                }
                // 3. Start new Xray core with new config
                startXray(xrayBinary, configPath, assetDir)
                // 4. Attach fresh tunnel worker to existing VPN file descriptor
                if (isTun && vpnInterface != null) {
                    val tunConfig = java.io.File(cacheDir, "tunnel.yaml")
                    try {
                        hev.htproxy.TProxyService.TProxyStartService(tunConfig.absolutePath, vpnInterface!!.fd)
                    } catch (_: Exception) {}
                }
            }
            return
        }

        // 2. Full start or full re-establishment:
        // If previous session was active, cleanly stop old tunnel and core first
        if (isRunning) {
            stopXray()
            try {
                hev.htproxy.TProxyService.TProxyStopService()
            } catch (_: Exception) {}
            try {
                vpnInterface?.close()
                vpnInterface = null
            } catch (_: Exception) {}
        }

        val notification = createNotification(configName, notificationTitle, disconnectText)
        startForeground(NOTIFICATION_ID, notification)

        // Transient 10s wake lock during startup only to prevent sleep during initial connection,
        // without permanently draining battery in background.
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            wakeLock = pm?.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "V2RayPro:VpnStartupLock")
            wakeLock?.acquire(10 * 1000L)
        } catch (_: Exception) {}

        if (isTun) {
            try {
                val builder = Builder()
                    .setSession("V2RayPro: $configName")
                    .addAddress("26.26.26.1", 24)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer("1.1.1.1")
                    .addDnsServer("8.8.8.8")
                    .setMtu(1500) // Standard 1500 MTU to eliminate packet fragmentation and restore max upload speed

                if (appRoutingMode == "inclusive" && appRoutingList.isNotEmpty()) {
                    for (pkg in appRoutingList) {
                        try {
                            builder.addAllowedApplication(pkg)
                        } catch (_: Exception) {}
                    }
                } else {
                    try {
                        builder.addDisallowedApplication(packageName)
                    } catch (_: Exception) {}

                    for (pkg in appRoutingList) {
                        if (pkg != packageName) {
                            try {
                                builder.addDisallowedApplication(pkg)
                            } catch (_: Exception) {}
                        }
                    }
                }

                // Establish TUN interface first. Android creates the VPN descriptor and displays
                // the VPN key icon in the system status bar immediately.
                var pfd = builder.establish()
                if (pfd == null) {
                    // System may need a brief delay after permission grant or previous interface cleanup
                    for (attempt in 1..3) {
                        try {
                            Thread.sleep(150)
                            pfd = builder.establish()
                            if (pfd != null) break
                        } catch (_: Exception) {}
                    }
                }

                vpnInterface = pfd
                if (pfd != null) {
                    // 1. Start Xray core process
                    if (xrayBinary.isNotEmpty() && configPath.isNotEmpty()) {
                        startXray(xrayBinary, configPath, assetDir)
                    }

                    // 2. Configure and start hev-socks5-tunnel on the established TUN file descriptor
                    val tunConfig = java.io.File(cacheDir, "tunnel.yaml")
                    val configContent = """
tunnel:
  mtu: 1500
  ipv4: 26.26.26.1

socks5:
  port: $socksPort
  address: 127.0.0.1
  udp: 'udp'

misc:
  task-stack-size: 20480
  connect-timeout: 5000
  read-write-timeout: 60000
  tcp-buffer-size: 65536
  udp-recv-buffer-size: 65536
  limit-nofile: 65535
  log-level: warn
""".trimIndent()
                    tunConfig.writeText(configContent)

                    hev.htproxy.TProxyService.TProxyStartService(tunConfig.absolutePath, pfd.fd)
                } else {
                    val logFile = java.io.File(cacheDir, "xray.log")
                    try {
                        logFile.appendText("[VPN Service] Builder.establish() failed to allocate TUN interface after retries.\n")
                    } catch (_: Exception) {}
                    stopVpn()
                    return
                }
                isRunning = true
                currentSocksPort = socksPort
                currentIsTun = isTun
                currentRoutingMode = appRoutingMode
                currentRoutingList = ArrayList(appRoutingList)
            } catch (e: Exception) {
                e.printStackTrace()
                stopVpn()
            }
        } else {
            // Proxy Mode: No VPN tunnel is established; VPN key icon does NOT appear!
            vpnInterface = null
            if (xrayBinary.isNotEmpty() && configPath.isNotEmpty()) {
                startXray(xrayBinary, configPath, assetDir)
            }
            isRunning = true
            currentSocksPort = socksPort
            currentIsTun = false
            currentRoutingMode = appRoutingMode
            currentRoutingList = ArrayList(appRoutingList)
        }

        if (isRunning) {
            try {
                val flagFile = java.io.File(cacheDir, "vpn_running.flag")
                flagFile.writeText("${android.os.Process.myPid()}")
            } catch (_: Exception) {}
        }
    }

    private fun stopVpn() {
        isRunning = false
        try {
            val flagFile = java.io.File(cacheDir, "vpn_running.flag")
            if (flagFile.exists()) flagFile.delete()
        } catch (_: Exception) {}

        stopXray()

        try {
            hev.htproxy.TProxyService.TProxyStopService()
        } catch (_: Exception) {}
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Exception) {}

        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(disconnectReceiver)
        } catch (_: Exception) {}
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        notifyDisconnected()
        super.onRevoke()
    }
}
