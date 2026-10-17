package com.v2raypro.app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Main application activity for V2RayPro on Android.
 *
 * Handles native platform integration between Flutter and Android OS:
 * - VpnService permission requests and lifecycle management
 * - Notification permission requests for Android 13+
 * - Battery optimization exemption requests
 * - Native library directory and binary path resolution
 * - Foreground VPN service dispatch and broadcast reception
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.v2raypro.app/native"
    private val VPN_REQUEST_CODE = 2026
    private val NOTIFICATION_PERMISSION_CODE = 2027
    private var methodChannel: MethodChannel? = null
    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingConfigName: String = "V2RayPro"
    private var pendingHttpPort: Int = 10888
    private var pendingSocksPort: Int = 10999

    private var pendingIsTun: Boolean = true
    private var pendingNotificationTitle: String = "V2RayPro - متصل"
    private var pendingDisconnectText: String = "قطع اتصال"
    private var pendingAppRoutingMode: String = "exclusive"
    private var pendingAppRoutingList: ArrayList<String> = arrayListOf()
    private var pendingXrayBinary: String = ""
    private var pendingConfigPath: String = ""
    private var pendingAssetDir: String = ""

    private val vpnBroadcastReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            runOnUiThread {
                methodChannel?.invokeMethod("onDisconnectedFromNotification", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        V2RayVpnService.onDisconnectListener = {
            runOnUiThread {
                channel.invokeMethod("onDisconnectedFromNotification", null)
            }
        }

        try {
            val filter = IntentFilter("com.v2raypro.app.VPN_DISCONNECTED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(vpnBroadcastReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(vpnBroadcastReceiver, filter)
            }
        } catch (_: Exception) {}

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val perm = android.Manifest.permission.POST_NOTIFICATIONS
                        val granted = androidx.core.content.ContextCompat.checkSelfPermission(this, perm) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            androidx.core.app.ActivityCompat.requestPermissions(this, arrayOf(perm), NOTIFICATION_PERMISSION_CODE)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "getNativeLibraryDir" -> {
                    result.success(applicationInfo.nativeLibraryDir)
                }
                "getXrayBinary" -> {
                    val libDir = applicationInfo.nativeLibraryDir
                    val xrayLib = File(libDir, "libxray.so")
                    if (xrayLib.exists()) {
                        result.success(xrayLib.absolutePath)
                    } else {
                        val fallback = File(applicationInfo.dataDir, "lib/libxray.so")
                        if (fallback.exists()) {
                            result.success(fallback.absolutePath)
                        } else {
                            result.success(null)
                        }
                    }
                }
                "queryCoreStats" -> {
                    val port = call.argument<Int>("port") ?: 10085
                    val xrayBinary = call.argument<String>("xrayBinary") ?: ""
                    Thread {
                        try {
                            val bin = if (xrayBinary.isNotEmpty() && File(xrayBinary).exists()) {
                                xrayBinary
                            } else {
                                val libDir = applicationInfo.nativeLibraryDir
                                File(libDir, "libxray.so").absolutePath
                            }
                            val pb = ProcessBuilder(bin, "api", "statsquery", "--server=127.0.0.1:$port")
                            val proc = pb.start()
                            val output = proc.inputStream.bufferedReader().use { it.readText() }
                            proc.waitFor(2, java.util.concurrent.TimeUnit.SECONDS)
                            runOnUiThread {
                                result.success(output)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.success(null)
                            }
                        }
                    }.start()
                }
                "isAnotherVpnActive" -> {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    var hasOtherVpn = false
                    val flagFile = File(cacheDir, "vpn_running.flag")
                    val isOurVpnActive = flagFile.exists() || V2RayVpnService.isRunning
                    if (!isOurVpnActive) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val activeNetwork = cm.activeNetwork
                            val caps = cm.getNetworkCapabilities(activeNetwork)
                            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                                hasOtherVpn = true
                            }
                        } else {
                            for (net in cm.allNetworks) {
                                val caps = cm.getNetworkCapabilities(net) ?: continue
                                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                                    hasOtherVpn = true
                                    break
                                }
                            }
                        }
                    }
                    result.success(hasOtherVpn)
                }
                "isVpnRunning" -> {
                    var running = false
                    val flagFile = File(cacheDir, "vpn_running.flag")
                    if (flagFile.exists()) {
                        running = true
                    }
                    if (!running && V2RayVpnService.isRunning) {
                        running = true
                    }
                    if (!running) {
                        try {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            @Suppress("DEPRECATION")
                            val isServiceRunning = am.getRunningServices(100).any {
                                it.service.className == V2RayVpnService::class.java.name
                            }
                            if (isServiceRunning) running = true
                        } catch (_: Exception) {}
                    }
                    if (!running) {
                        try {
                            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val activeNet = cm.activeNetwork
                                val caps = cm.getNetworkCapabilities(activeNet)
                                if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                                    running = true
                                }
                            } else {
                                for (net in cm.allNetworks) {
                                    val caps = cm.getNetworkCapabilities(net) ?: continue
                                    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                                        running = true
                                        break
                                    }
                                }
                            }
                        } catch (_: Exception) {}
                    }
                    result.success(running)
                }
                "getRecentVpnLogs" -> {
                    val logFile = File(cacheDir, "xray.log")
                    if (logFile.exists()) {
                        try {
                            val lines = ArrayList<String>()
                            logFile.bufferedReader().use { reader ->
                                var l = reader.readLine()
                                while (l != null) {
                                    lines.add(l)
                                    if (lines.size > 300) {
                                        lines.removeAt(0)
                                    }
                                    l = reader.readLine()
                                }
                            }
                            val recent = if (lines.size > 150) lines.takeLast(150) else lines
                            result.success(recent)
                        } catch (e: Exception) {
                            result.success(listOf<String>())
                        }
                    } else {
                        result.success(listOf<String>())
                    }
                }
                "clearVpnLogs" -> {
                    val logFile = File(cacheDir, "xray.log")
                    try {
                        if (logFile.exists()) logFile.delete()
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "prepareVpn" -> {
                    val prepareIntent = VpnService.prepare(this)
                    if (prepareIntent != null) {
                        pendingVpnResult = result
                        startActivityForResult(prepareIntent, VPN_REQUEST_CODE)
                    } else {
                        result.success(true)
                    }
                }
                "startVpnService", "startVpn" -> {
                    val configName = call.argument<String>("configName") ?: call.argument<String>("nodeName") ?: "V2RayPro"
                    val httpPort = call.argument<Int>("httpPort") ?: 10888
                    val socksPort = call.argument<Int>("socksPort") ?: 10999
                    val isTun = call.argument<Boolean>("isTun") ?: true
                    val notificationTitle = call.argument<String>("notificationTitle") ?: "V2RayPro - متصل"
                    val disconnectText = call.argument<String>("disconnectText") ?: "قطع اتصال"
                    val appRoutingMode = call.argument<String>("appRoutingMode") ?: "exclusive"
                    val appRoutingList = call.argument<ArrayList<String>>("appRoutingList") ?: arrayListOf<String>()
                    val xrayBinary = call.argument<String>("xrayBinary") ?: ""
                    val configPath = call.argument<String>("configPath") ?: ""
                    val assetDir = call.argument<String>("assetDir") ?: ""

                    if (isTun) {
                        val prepareIntent = VpnService.prepare(this)
                        if (prepareIntent != null) {
                            pendingVpnResult = result
                            pendingConfigName = configName
                            pendingHttpPort = httpPort
                            pendingSocksPort = socksPort
                            pendingIsTun = isTun
                            pendingNotificationTitle = notificationTitle
                            pendingDisconnectText = disconnectText
                            pendingAppRoutingMode = appRoutingMode
                            pendingAppRoutingList = appRoutingList
                            pendingXrayBinary = xrayBinary
                            pendingConfigPath = configPath
                            pendingAssetDir = assetDir
                            startActivityForResult(prepareIntent, VPN_REQUEST_CODE)
                        } else {
                            launchVpnService(
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
                            result.success(true)
                        }
                    } else {
                        // Proxy Mode: No VPN interface needed, start purely as foreground service
                        launchVpnService(
                            configName,
                            httpPort,
                            socksPort,
                            false,
                            notificationTitle,
                            disconnectText,
                            appRoutingMode,
                            appRoutingList,
                            xrayBinary,
                            configPath,
                            assetDir
                        )
                        result.success(true)
                    }
                }
                "stopVpnService", "stopVpn" -> {
                    val stopIntent = Intent(this, V2RayVpnService::class.java).apply {
                        action = V2RayVpnService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val pm = packageManager
                            val intent = Intent(Intent.ACTION_MAIN, null).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            val resolveInfos = pm.queryIntentActivities(intent, 0)
                            val apps = ArrayList<Map<String, String>>()
                            val seen = HashSet<String>()
                            for (ri in resolveInfos) {
                                val pkg = ri.activityInfo.packageName
                                if (pkg != packageName && !seen.contains(pkg)) {
                                    seen.add(pkg)
                                    val label = ri.loadLabel(pm)?.toString() ?: pkg
                                    apps.add(mapOf("name" to label, "packageName" to pkg))
                                }
                            }
                            apps.sortBy { (it["name"] ?: "").lowercase() }
                            runOnUiThread { result.success(apps) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("ERROR", e.message, null) }
                        }
                    }.start()
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: false)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                                } else {
                                    Uri.fromFile(file)
                                }
                                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                                }
                                startActivity(installIntent)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                            }
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchVpnService(
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
        val startIntent = Intent(this, V2RayVpnService::class.java).apply {
            action = V2RayVpnService.ACTION_START
            putExtra("configName", configName)
            putExtra("httpPort", httpPort)
            putExtra("socksPort", socksPort)
            putExtra("isTun", isTun)
            putExtra("notificationTitle", notificationTitle)
            putExtra("disconnectText", disconnectText)
            putExtra("appRoutingMode", appRoutingMode)
            putStringArrayListExtra("appRoutingList", appRoutingList)
            putExtra("xrayBinary", xrayBinary)
            putExtra("configPath", configPath)
            putExtra("assetDir", assetDir)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(startIntent)
        } else {
            startService(startIntent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                // If this preparation was triggered as part of a pending start request, launch the service
                if (pendingConfigPath.isNotEmpty() || pendingConfigName.isNotEmpty()) {
                    window.decorView.postDelayed({
                        launchVpnService(
                            pendingConfigName,
                            pendingHttpPort,
                            pendingSocksPort,
                            pendingIsTun,
                            pendingNotificationTitle,
                            pendingDisconnectText,
                            pendingAppRoutingMode,
                            pendingAppRoutingList,
                            pendingXrayBinary,
                            pendingConfigPath,
                            pendingAssetDir
                        )
                        pendingVpnResult?.success(true)
                        pendingVpnResult = null
                    }, 100)
                } else {
                    pendingVpnResult?.success(true)
                    pendingVpnResult = null
                }
            } else {
                pendingVpnResult?.success(false)
                pendingVpnResult = null
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(vpnBroadcastReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
