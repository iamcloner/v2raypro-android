// =======================================================================
// [File Name]: core_service.dart
// [Description]: Primary service managing the Xray proxy core lifecycle on Android.
// Oversees core execution, connection state monitoring, port allocation,
// traffic statistics sampling, and coordination with TunService for VPN mode.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "../models/service_models.dart";
import "../models/traffic_stats.dart";
import "../models/proxy_node.dart";
import "../models/log_entry.dart";
import "core_config_builder.dart";
import "tun_service.dart";
import "log_service.dart";
import "storage_service.dart";
import "port_helper.dart";

/// Proxy core service coordinating execution processes and active connection sessions on Android.
/// Provides connection, configuration switching, disconnection methods, and real-time traffic streams.
class CoreService {
  /// Singleton instance of the core service.
  static final CoreService instance = CoreService._internal();

  /// Internal private constructor initializing persistent settings.
  CoreService._internal() {
    initSettings();
  }

  /// Current core operating state (disconnected, connecting, connected, or error).
  CoreState _state = CoreState.disconnected;
  CoreState get state => _state;
  final _stateStreamController = StreamController<CoreState>.broadcast();
  Stream<CoreState> get stateStream => _stateStreamController.stream;

  /// Current operating mode (local proxy or full TUN mode).
  CoreMode _mode = CoreMode.proxy;
  CoreMode get mode => _mode;

  /// Active local HTTP inbound port.
  int _httpPort = 10888;
  int get httpPort => _httpPort;
  set httpPort(int port) => _httpPort = port;

  /// Active local SOCKS inbound port.
  int _socksPort = 10999;
  int get socksPort => _socksPort;
  set socksPort(int port) => _socksPort = port;

  /// Internal API port for collecting traffic statistics.
  int _apiPort = 10085;
  int get apiPort => _apiPort;

  /// Global network configuration settings.
  bool _allowLan = false;
  bool _allowInsecure = false;
  bool _enableMux = false;

  /// Current active core configuration and file.
  CoreConfig? _activeConfig;
  CoreConfig? get activeConfig => _activeConfig;
  File? _activeConfigFile;
  Process? _coreProcess;
  String? _currentBinaryPath;

  String? _androidBinaryPath;
  String? get androidBinaryPath => _androidBinaryPath;
  Directory? _androidAssetDir;
  Directory? get androidAssetDir => _androidAssetDir;
  String? get currentBinaryPath => _currentBinaryPath ?? _findCoreBinary(CoreType.xray);
  String? get workingDirectory => _androidAssetDir?.path;
  Map<String, String>? get coreEnvironment => _getCoreEnvironment();

  Timer? _durationTimer;
  DateTime? _connectedAt;
  final _durationStreamController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationStreamController.stream;

  Timer? _trafficTimer;
  final _trafficStreamController = StreamController<TrafficStats>.broadcast();
  Stream<TrafficStats> get trafficStream => _trafficStreamController.stream;
  TrafficStats _currentTrafficStats = const TrafficStats();
  TrafficStats get currentTrafficStats => _currentTrafficStats;

  Future<void> initSettings() async {
    try {
      _httpPort = await StorageService.instance.loadHttpPort();
      _socksPort = await StorageService.instance.loadSocksPort();
      _allowLan = await StorageService.instance.loadAllowLan();
      _allowInsecure = await StorageService.instance.loadGlobalAllowInsecure();
      _enableMux = await StorageService.instance.loadGlobalEnableMux();
    } catch (_) {}
  }

  static Future<bool> isPortAvailable(int port) => PortHelper.isPortAvailable(port);

  /// Finds the first available open port if requested port is occupied.
  static Future<int> findAvailablePort(int startingPort) => PortHelper.findAvailablePort(startingPort);

  /// Establishes proxy connection and starts the Android VPN service.
  Future<bool> connect({
    required CoreMode mode,
    required CoreConfig config,
    required int httpPort,
    required int socksPort,
    bool enableUdp = true,
    bool enableMux = false,
    bool allowInsecure = false,
    bool allowLan = false,
    String? notificationTitle,
    String? disconnectText,
    String? configName,
  }) async {
    final bool isSwitching = (_state == CoreState.connected || _state == CoreState.connecting);
    int safeSocksPort;
    int safeHttpPort;
    int safeApiPort;

    if (isSwitching && Platform.isAndroid && _mode == mode) {
      safeSocksPort = _socksPort;
      safeHttpPort = _httpPort;
      safeApiPort = _apiPort;
    } else {
      if (isSwitching) await disconnect();
      safeSocksPort = await isPortAvailable(socksPort) ? socksPort : await findAvailablePort(socksPort);
      safeHttpPort = (!await isPortAvailable(httpPort) || httpPort == safeSocksPort)
          ? await findAvailablePort(safeSocksPort + 1) : httpPort;
      safeApiPort = (!await isPortAvailable(_apiPort) || _apiPort == safeSocksPort || _apiPort == safeHttpPort)
          ? await findAvailablePort(safeHttpPort + 1) : _apiPort;
    }

    _mode = mode;
    _httpPort = safeHttpPort;
    _socksPort = safeSocksPort;
    _apiPort = safeApiPort;
    _allowLan = allowLan;
    _allowInsecure = allowInsecure;
    _enableMux = enableMux;
    _activeConfig = config;

    _setState(CoreState.connecting);
    LogService.instance.add("CoreService: در حال اتصال کانفیگ (SOCKS: $_socksPort, HTTP: $_httpPort)...", level: LogLevel.info, source: "core");

    if (Platform.isAndroid && _androidBinaryPath == null) await initAndroid();

    final binaryPath = _findCoreBinary(config.type);
    if (binaryPath == null) {
      _setState(CoreState.error);
      LogService.instance.add("CoreService: فایل اجرایی هسته یافت نشد.", level: LogLevel.error, source: "core");
      return false;
    }
    _currentBinaryPath = binaryPath;

    try {
      final runtimeConfig = CoreConfigBuilder.buildRuntimeConfig(
        config: config, socksPort: _socksPort, httpPort: _httpPort, apiPort: _apiPort,
        enableUdp: enableUdp, enableMux: enableMux, allowInsecure: allowInsecure, allowLan: allowLan,
      );

      final tmpDir = _androidAssetDir ?? Directory.systemTemp;
      _activeConfigFile = File("${tmpDir.path}/v2raypro_active_config.json");
      await _activeConfigFile!.writeAsString(jsonEncode(runtimeConfig));

      final tunOk = await TunService.instance.setStatus(
        status: TunStatus.connect, socksPort: _socksPort, httpPort: _httpPort,
        notificationTitle: notificationTitle, disconnectText: disconnectText, configName: configName,
        xrayBinary: binaryPath, configPath: _activeConfigFile?.path, assetDir: _androidAssetDir?.path,
      );

      if (!tunOk) {
        _setState(CoreState.error);
        await _stopCoreProcess();
        return false;
      }

      _setState(CoreState.connected);
      if (!isSwitching) {
        _startDurationTimer();
        _startTrafficPolling();
      }
      LogService.instance.add("CoreService: اتصال با موفقیت برقرار شد.", level: LogLevel.info, source: "core");
      return true;
    } catch (e) {
      _setState(CoreState.error);
      LogService.instance.add("CoreService: خطا در اتصال: $e", level: LogLevel.error, source: "core");
      await _stopCoreProcess();
      return false;
    }
  }

  /// Seamlessly switches the active configuration without tearing down network tunnel.
  Future<bool> changeConfig(CoreConfig newConfig) async {
    LogService.instance.add("CoreService: تعویض نود به کانفیگ جدید...", level: LogLevel.info, source: "core");
    return await connect(
      mode: _mode, config: newConfig, httpPort: _httpPort, socksPort: _socksPort,
      enableUdp: true, enableMux: _enableMux, allowInsecure: _allowInsecure, allowLan: _allowLan,
      configName: newConfig.node?.name,
    );
  }

  /// Completely disconnects and releases processes and network connections.
  Future<void> disconnect() async {
    LogService.instance.add("CoreService: قطع ارتباط با هسته...", level: LogLevel.info, source: "core");
    _setState(CoreState.disconnecting);
    _stopDurationTimer();
    _stopTrafficPolling();

    await TunService.instance.disconnect();
    await _stopCoreProcess();

    _activeConfig = null;
    _setState(CoreState.disconnected);
  }

  /// Starts timer tracking elapsed connection duration.
  void _startDurationTimer([DateTime? baseline]) {
    _connectedAt = baseline ?? DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        _durationStreamController.add(DateTime.now().difference(_connectedAt!));
      }
    });
  }

  /// Stops connection duration timer and resets stream output.
  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedAt = null;
    _durationStreamController.add(Duration.zero);
  }

  /// Restores connected state when application resumes from background.
  void restoreConnectedState({DateTime? connectedAt}) {
    _state = CoreState.connected;
    _stateStreamController.add(_state);
    _startDurationTimer(connectedAt);
    _startTrafficPolling();
  }

  /// Starts periodic traffic stats polling via background reports and native api.
  void _startTrafficPolling() {
    _trafficTimer?.cancel();
    _currentTrafficStats = const TrafficStats();
    _trafficStreamController.add(_currentTrafficStats);

    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_state != CoreState.connected) return;
      TunService.instance.syncAndroidLogs();
      try {
        const channel = MethodChannel("com.v2raypro.app/native");
        final output = await channel.invokeMethod<String>("queryCoreStats", {
          "port": _apiPort,
          "xrayBinary": _currentBinaryPath ?? _androidBinaryPath ?? "",
        });
        if (output != null && output.isNotEmpty) {
          final json = jsonDecode(output) as Map<String, dynamic>;
          final statList = json["stat"] as List<dynamic>?;
          if (statList != null) {
            int outDown = 0, outUp = 0, inDown = 0, inUp = 0;
            for (final item in statList) {
              if (item is Map) {
                final name = item["name"]?.toString() ?? "";
                final val = item["value"] is num ? (item["value"] as num).toInt() : (int.tryParse("${item["value"]}") ?? 0);
                if (val <= 0) continue;
                if (name.startsWith("outbound>>>") && !name.contains("api") && !name.contains("direct") && !name.contains("block")) {
                  if (name.endsWith(">>>traffic>>>downlink")) outDown += val;
                  if (name.endsWith(">>>traffic>>>uplink")) outUp += val;
                }
                if (name.startsWith("inbound>>>") && !name.contains("api")) {
                  if (name.endsWith(">>>traffic>>>downlink")) inDown += val;
                  if (name.endsWith(">>>traffic>>>uplink")) inUp += val;
                }
              }
            }
            final totalDown = outDown > 0 ? outDown : inDown;
            final totalUp = outUp > 0 ? outUp : inUp;
            _currentTrafficStats = TrafficStats(downlinkBytes: totalDown, uplinkBytes: totalUp);
            _trafficStreamController.add(_currentTrafficStats);
          }
        }
      } catch (_) {}
    });
  }

  /// Stops traffic statistics polling.
  void _stopTrafficPolling() {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    _currentTrafficStats = const TrafficStats();
    _trafficStreamController.add(_currentTrafficStats);
  }

  /// Updates current core state and broadcasts to listeners.
  void _setState(CoreState s) {
    _state = s;
    _stateStreamController.add(s);
  }

  /// Terminates local process and deletes temporary config file.
  Future<void> _stopCoreProcess() async {
    _currentBinaryPath = null;
    _coreProcess?.kill();
    _coreProcess = null;
    try {
      if (_activeConfigFile != null && await _activeConfigFile!.exists()) {
        await _activeConfigFile!.delete();
      }
    } catch (_) {}
  }

  /// Locates Xray core binary in Android native library path.
  String? _findCoreBinary(CoreType type) =>
      (_androidBinaryPath != null && File(_androidBinaryPath!).existsSync()) ? _androidBinaryPath : null;

  /// Essential environment variables for loading geosite and geoip databases.
  Map<String, String>? _getCoreEnvironment() =>
      _androidAssetDir != null ? {"XRAY_LOCATION_ASSET": _androidAssetDir!.path} : null;

  /// Initializes Android environment and resolves native binary and asset directories.
  Future<void> initAndroid() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel("com.v2raypro.app/native");
      final path = await channel.invokeMethod<String>("getXrayBinary");
      if (path != null && File(path).existsSync()) _androidBinaryPath = path;
    } catch (_) {}

    try {
      final appSupport = await getApplicationSupportDirectory();
      final xrayDir = Directory("${appSupport.path}/xray");
      if (!xrayDir.existsSync()) await xrayDir.create(recursive: true);
      _androidAssetDir = xrayDir;
    } catch (_) {}
  }
}
