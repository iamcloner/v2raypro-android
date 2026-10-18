// =======================================================================
// [File Name]: tun_service.dart
// [Description]: Tunnel interface and VPN management service on Android.
// Handles interaction with the native V2RayVpnService via MethodChannel
// for establishing, disconnecting, routing traffic, and receiving VPN logs.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:io";
import "package:flutter/services.dart";
import "../models/service_models.dart";
import "../models/log_entry.dart";
import "log_service.dart";

/// Service managing network tunnel and interaction with the native VpnService on Android.
/// Responsible for establishing VPN sessions and coordinating traffic flow with the Xray core.
class TunService {
  /// Global singleton instance for application-wide access.
  static final TunService instance = TunService._internal();

  /// Private internal constructor implementing the singleton pattern.
  TunService._internal();

  /// Communication channel with Android Kotlin MainActivity and V2RayVpnService.
  static const _androidChannel = MethodChannel("com.v2raypro.app/native");

  /// Current network tunnel status (connected or disconnected).
  TunStatus _status = TunStatus.disconnect;

  /// Retrieves current tunnel operating status.
  TunStatus get status => _status;

  /// Quick check whether the network tunnel is connected.
  bool get isConnected => _status == TunStatus.connect;

  /// Current local SOCKS socket port.
  int _currentSocksPort = 10999;

  /// Current local HTTP proxy port.
  int _currentHttpPort = 10888;

  /// Retrieves current SOCKS proxy port.
  int get socksPort => _currentSocksPort;

  /// Retrieves current HTTP proxy port.
  int get httpPort => _currentHttpPort;

  /// System proxy status flag (traffic is always routed on Android via TUN interface).
  bool _isSystemProxySet = false;

  /// Retrieves system proxy status.
  bool get isSystemProxySet => _isSystemProxySet;

  /// Callback for disconnect notification from Android notification.
  VoidCallback? onNotificationDisconnect;

  /// Hash cache of synced logs to prevent duplicate Android log entries.
  final Set<String> _syncedAndroidLogSet = <String>{};

  /// Main method configuring tunnel state corresponding to VPN connect or disconnect requests.
  /// Sends port parameters and configuration to the service when connecting.
  Future<bool> setStatus({
    required TunStatus status,
    required int socksPort,
    required int httpPort,
    String? notificationTitle,
    String? disconnectText,
    String? configName,
    String? appRoutingMode,
    List<String>? appRoutingList,
    String? xrayBinary,
    String? configPath,
    String? assetDir,
  }) async {
    _currentSocksPort = socksPort;
    _currentHttpPort = httpPort;

    if (status == TunStatus.connect) {
      return await connect(
        socksPort: socksPort,
        httpPort: httpPort,
        notificationTitle: notificationTitle,
        disconnectText: disconnectText,
        configName: configName,
        appRoutingMode: appRoutingMode,
        appRoutingList: appRoutingList,
        xrayBinary: xrayBinary,
        configPath: configPath,
        assetDir: assetDir,
      );
    } else {
      await disconnect();
      return true;
    }
  }

  /// Initializes and activates the TUN interface via Android native service.
  /// Transmits required core execution info and packet forwarding params to Kotlin layer.
  Future<bool> connect({
    required int socksPort,
    required int httpPort,
    String? notificationTitle,
    String? disconnectText,
    String? configName,
    String? appRoutingMode,
    List<String>? appRoutingList,
    String? xrayBinary,
    String? configPath,
    String? assetDir,
  }) async {
    _currentSocksPort = socksPort;
    _currentHttpPort = httpPort;

    LogService.instance.add(
      "TunService: فعال‌سازی تونل شبکه در اندروید (SOCKS: $socksPort, HTTP: $httpPort)...",
      level: LogLevel.info,
      source: "tun",
    );

    final started = await _startAndroidTun(
      socksPort: socksPort,
      httpPort: httpPort,
      notificationTitle: notificationTitle,
      disconnectText: disconnectText,
      configName: configName,
      appRoutingMode: appRoutingMode,
      appRoutingList: appRoutingList,
      xrayBinary: xrayBinary,
      configPath: configPath,
      assetDir: assetDir,
    );

    if (started) {
      _status = TunStatus.connect;
    }
    return started;
  }

  /// Stops the TUN service and releases Android device VPN interface.
  Future<void> disconnect() async {
    LogService.instance.add("TunService: بستن اینترفیس وی‌پی‌ان...", level: LogLevel.info, source: "tun");
    await _stopAndroidTun();
    _status = TunStatus.disconnect;
  }

  /// Sends request to launch Android VpnService via MethodChannel.
  Future<bool> _startAndroidTun({
    required int socksPort,
    required int httpPort,
    String? notificationTitle,
    String? disconnectText,
    String? configName,
    String? appRoutingMode,
    List<String>? appRoutingList,
    String? xrayBinary,
    String? configPath,
    String? assetDir,
  }) async {
    try {
      final payload = {
        "configName": configName ?? notificationTitle ?? "V2RayPro",
        "nodeName": configName ?? notificationTitle ?? "V2RayPro",
        "isTun": true,
        "socksPort": socksPort,
        "httpPort": httpPort,
        if (notificationTitle != null) "notificationTitle": notificationTitle,
        if (disconnectText != null) "disconnectText": disconnectText,
        if (appRoutingMode != null) "appRoutingMode": appRoutingMode,
        if (appRoutingList != null) "appRoutingList": appRoutingList,
        if (xrayBinary != null) "xrayBinary": xrayBinary,
        if (configPath != null) "configPath": configPath,
        if (assetDir != null) "assetDir": assetDir,
      };

      bool? res;
      try {
        res = await _androidChannel.invokeMethod<bool>("startVpnService", payload);
      } catch (_) {
        res = await _androidChannel.invokeMethod<bool>("startVpn", payload);
      }
      return res ?? false;
    } catch (e) {
      LogService.instance.add("TunService: خطا در استارت VPN اندروید: $e", level: LogLevel.error, source: "tun");
      return false;
    }
  }

  /// Sends request to stop active VPN service to Android native layer.
  Future<void> _stopAndroidTun() async {
    try {
      await _androidChannel.invokeMethod("stopVpnService");
    } catch (_) {
      try {
        await _androidChannel.invokeMethod("stopVpn");
      } catch (_) {}
    }
  }

  /// Pre-validates user authorization for VPN permission via Android system dialog.
  Future<bool> prepareAndroidVpn() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _androidChannel.invokeMethod<bool>("prepareVpn");
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches logs captured in background Kotlin service and forwards them to app logger.
  Future<void> syncAndroidLogs() async {
    if (!Platform.isAndroid) return;
    try {
      final lines = await _androidChannel.invokeMethod<List<dynamic>>("getRecentVpnLogs");
      if (lines != null && lines.isNotEmpty) {
        for (final raw in lines) {
          final line = raw.toString().trim();
          if (line.isNotEmpty && !_syncedAndroidLogSet.contains(line)) {
            _syncedAndroidLogSet.add(line);
            LogLevel lvl = LogLevel.info;
            final lwr = line.toLowerCase();
            if (lwr.contains("error") || lwr.contains("failed") || lwr.contains("fatal")) {
              lvl = LogLevel.error;
            } else if (lwr.contains("warn")) {
              lvl = LogLevel.warning;
            }
            LogService.instance.add(line, level: lvl, source: "android-vpn");
          }
        }
      }
    } catch (_) {}
  }

  /// Checks online connectivity status of Android VPN service.
  Future<bool> isVpnActive() async {
    if (!Platform.isAndroid) return isConnected;
    try {
      final res = await _androidChannel.invokeMethod<bool>("isVpnRunning");
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks admin permissions (VPN permission is used on Android and always returns true).
  bool isRunningAsAdmin() => true;

  /// Optional proxy reset method for interface compatibility.
  void setWindowsSystemProxy(bool enable, {int? port}) {
    _isSystemProxySet = enable;
  }
}
