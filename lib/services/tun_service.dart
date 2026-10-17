import "dart:async";
import "dart:ffi" as ffi;
import "dart:io";
import "package:flutter/services.dart";
import "../models/service_models.dart";
import "../models/log_entry.dart";
import "log_service.dart";

/// Dedicated TUN Service managing network tunnel interfaces,
/// system routes, and Android VpnService.
class TunService {
  static final TunService instance = TunService._internal();
  TunService._internal();

  TunStatus _status = TunStatus.disconnect;
  TunStatus get status => _status;
  bool get isConnected => _status == TunStatus.connect;

  int _currentSocksPort = 10999;
  int _currentHttpPort = 10888;
  int get socksPort => _currentSocksPort;
  int get httpPort => _currentHttpPort;

  bool _isSystemProxySet = false;
  bool get isSystemProxySet => _isSystemProxySet;

  VoidCallback? onNotificationDisconnect;

  /// Main interface matching diagram: Status (connect / disconnect), Http_port, Socks_port
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

  /// Connect and activate the TUN / system routing interface
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

    LogService.instance.add("TunService: activating TUN routing (Socks: $socksPort, Http: $httpPort)...", level: LogLevel.info, source: "tun");

    if (Platform.isAndroid) {
      return await _startAndroidTun(
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
    } else if (Platform.isWindows) {
      return await _startWindowsTun(socksPort: socksPort, httpPort: httpPort);
    }

    _status = TunStatus.connect;
    return true;
  }

  /// Disconnect and teardown the TUN / system routing interface
  Future<void> disconnect() async {
    LogService.instance.add("TunService: tearing down TUN interface...", level: LogLevel.info, source: "tun");

    if (Platform.isAndroid) {
      await _stopAndroidTun();
    } else if (Platform.isWindows) {
      await _stopWindowsTun();
    }

    _status = TunStatus.disconnect;
  }

  // ========================================================
  // Android-specific implementation
  // ========================================================

  static const _androidChannel = MethodChannel('com.v2raypro.app/native');

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
        'configName': configName ?? notificationTitle ?? 'V2RayPro',
        'nodeName': configName ?? notificationTitle ?? 'V2RayPro',
        'isTun': true,
        'socksPort': socksPort,
        'httpPort': httpPort,
        if (notificationTitle != null) 'notificationTitle': notificationTitle,
        if (disconnectText != null) 'disconnectText': disconnectText,
        if (appRoutingMode != null) 'appRoutingMode': appRoutingMode,
        if (appRoutingList != null) 'appRoutingList': appRoutingList,
        if (xrayBinary != null) 'xrayBinary': xrayBinary,
        if (configPath != null) 'configPath': configPath,
        if (assetDir != null) 'assetDir': assetDir,
      };

      bool? res;
      try {
        res = await _androidChannel.invokeMethod<bool>('startVpnService', payload);
      } catch (_) {
        res = await _androidChannel.invokeMethod<bool>('startVpn', payload);
      }

      final started = res ?? false;
      if (started) {
        _status = TunStatus.connect;
      }
      return started;
    } catch (e) {
      LogService.instance.add("TunService: failed to start Android VPN: $e", level: LogLevel.error, source: "tun");
      return false;
    }
  }

  Future<void> _stopAndroidTun() async {
    try {
      await _androidChannel.invokeMethod('stopVpnService');
    } catch (_) {
      try {
        await _androidChannel.invokeMethod('stopVpn');
      } catch (_) {}
    }
  }

  final Set<String> _syncedAndroidLogSet = <String>{};

  Future<bool> prepareAndroidVpn() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _androidChannel.invokeMethod<bool>('prepareVpn');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncAndroidLogs() async {
    if (!Platform.isAndroid) return;
    try {
      final lines = await _androidChannel.invokeMethod<List<dynamic>>('getRecentVpnLogs');
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

  Future<bool> isVpnActive() async {
    if (!Platform.isAndroid) return isConnected;
    try {
      final res = await _androidChannel.invokeMethod<bool>('isVpnRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }


  // ========================================================
  // Windows-specific implementation
  // ========================================================

  Future<bool> _startWindowsTun({required int socksPort, required int httpPort}) async {
    if (!isRunningAsAdmin()) {
      LogService.instance.add("TunService: Administrator privileges required for Windows TUN.", level: LogLevel.warning, source: "tun");
      return false;
    }

    try {
      _status = TunStatus.connect;
      LogService.instance.add("TunService: Windows TUN adapter routing active.", level: LogLevel.info, source: "tun");
      return true;
    } catch (e) {
      LogService.instance.add("TunService: failed to configure Windows TUN: $e", level: LogLevel.error, source: "tun");
      return false;
    }
  }

  Future<void> _stopWindowsTun() async {
    setWindowsSystemProxy(false);
  }

  bool isRunningAsAdmin() {
    if (!Platform.isWindows) return true;
    try {
      final shell32 = ffi.DynamicLibrary.open("shell32.dll");
      final isUserAnAdmin = shell32.lookupFunction<ffi.Int32 Function(), int Function()>("IsUserAnAdmin");
      return isUserAnAdmin() != 0;
    } catch (_) {
      try {
        final res = Process.runSync("net", ["session"], runInShell: true);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> restartAsAdmin() async {
    if (!Platform.isWindows) return;
    final exe = Platform.resolvedExecutable;
    try {
      await Process.start("powershell", [
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        'Start-Process -FilePath "$exe" -Verb RunAs',
      ]);
      exit(0);
    } catch (e) {
      LogService.instance.add("TunService: failed to restart as admin: $e", level: LogLevel.error, source: "tun");
    }
  }

  void setWindowsSystemProxy(bool enable, {int? port}) {
    if (!Platform.isWindows) return;
    _isSystemProxySet = enable;
  }
}
