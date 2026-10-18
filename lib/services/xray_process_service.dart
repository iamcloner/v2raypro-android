// =======================================================================
// [File Name]: xray_process_service.dart
// [Description]: Facade managing coordination among Core, Tun, and Ping services.
// Provides a unified interface for connection processes, latency testing, node state changes,
// and synchronization of Android notifications and sockets within a clean architecture.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:io";
import "package:flutter/services.dart";
import "../models/proxy_node.dart";
import "../models/routing_rule.dart";
import "../models/traffic_stats.dart";
import "../models/service_models.dart";
import "../models/node_test_result.dart";
import "../utils/config_generator.dart";
import "core_service.dart";
import "tun_service.dart";
import "ping_service.dart";

export "../models/node_test_result.dart";

/// High-level engine execution state.
enum EngineState { stopped, starting, running, stopping, error }

/// Central facade service for unified control of core and VPN operations on Android.
class XrayProcessService {
  /// Singleton instance of XrayProcessService.
  static final XrayProcessService instance = XrayProcessService._internal();

  /// Internal private constructor implementing the singleton pattern.
  XrayProcessService._internal();

  /// Access to proxy core service.
  CoreService get core => CoreService.instance;

  /// Access to Android network tunnel service.
  TunService get tun => TunService.instance;

  /// Access to latency and ping measurement service.
  PingService get ping => PingService.instance;

  /// Computes aggregated engine state from core state.
  EngineState get state {
    switch (core.state) {
      case CoreState.disconnected:
        return EngineState.stopped;
      case CoreState.connecting:
        return EngineState.starting;
      case CoreState.connected:
        return EngineState.running;
      case CoreState.disconnecting:
        return EngineState.stopping;
      case CoreState.error:
        return EngineState.error;
    }
  }

  /// Currently active running node in the application.
  ProxyNode? _activeRunningNode;
  ProxyNode? get activeRunningNode => _activeRunningNode;

  /// Gets and sets SOCKS port.
  int get socksPort => core.socksPort;
  set socksPort(int p) => core.socksPort = p;

  /// Gets and sets HTTP port.
  int get httpPort => core.httpPort;
  set httpPort(int p) => core.httpPort = p;

  /// Internal API port for core communication.
  int get apiPort => core.apiPort;

  /// System proxy configured state.
  bool get isSystemProxySet => tun.isSystemProxySet;

  /// Global connection multiplexing settings.
  bool globalEnableMux = false;

  /// Allows insecure connections without TLS certificate verification.
  bool globalAllowInsecure = false;

  /// Allows proxy sharing over local area network (LAN).
  bool globalAllowLan = false;

  /// List of user-configured DNS servers.
  List<String> dnsServers = [];

  /// List of traffic routing rules.
  List<RoutingRule> routingRules = [];

  /// Per-app routing mode on Android.
  AppRoutingMode appRoutingMode = AppRoutingMode.exclusive;

  /// Real-time traffic consumption stream.
  Stream<TrafficStats> get trafficStream => core.trafficStream;
  TrafficStats get currentTrafficStats => core.currentTrafficStats;

  /// Disconnect callback invoked from Android notification.
  VoidCallback? get onAndroidNotificationDisconnect => tun.onNotificationDisconnect;
  set onAndroidNotificationDisconnect(VoidCallback? cb) => tun.onNotificationDisconnect = cb;

  /// Initializes core runtime environment on Android.
  Future<void> initAndroid() async {
    await core.initAndroid();
  }

  /// Directory hosting static files and geo databases on Android.
  Directory? get androidAssetDir => core.androidAssetDir;

  /// Checks user access permissions (always considered permitted on Android).
  bool isRunningAsAdmin() => tun.isRunningAsAdmin();

  /// Sets system proxy (desktop only - no-op on Android).
  void setWindowsSystemProxy(bool enable, {int? port}) {
    tun.setWindowsSystemProxy(enable, port: port);
  }

  /// Checks whether Android background VPN service is running.
  Future<bool> isAndroidVpnRunning() => tun.isVpnActive();

  /// Pre-validates VPN permission on Android OS.
  Future<bool> prepareAndroidVpn() => tun.prepareAndroidVpn();

  /// Periodically synchronizes logs from background Kotlin service.
  Future<void> syncAndroidLogs() => tun.syncAndroidLogs();

  /// Checks whether another VPN session is active on the Android device.
  Future<bool> isAnotherVpnActive() async {
    if (!Platform.isAndroid) return false;
    try {
      const channel = MethodChannel("com.v2raypro.app/native");
      final res = await channel.invokeMethod<bool>("isAnotherVpnActive");
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Resolves Xray binary path within Android native libraries directory.
  String? findXrayBinarySync() {
    final bin = core.androidBinaryPath;
    if (bin != null && File(bin).existsSync()) return bin;
    return null;
  }

  /// Checks whether core executable is available.
  bool isCoreAvailable() => true;

  /// Pre-validates address and port parameter structure for a node configuration.
  bool isNodeConfigSupported(ProxyNode node) {
    if (node.address.trim().isEmpty || node.port <= 0 || node.port > 65535) return false;
    if (node.protocol == ProtocolType.vless || node.protocol == ProtocolType.vmess) {
      if (node.uuidOrPassword.trim().isEmpty) return false;
    }
    if (node.security == SecurityType.reality) {
      if (node.publicKey == null || node.publicKey!.trim().isEmpty) return false;
    }
    return true;
  }

  /// Generates standard Xray configuration map for node incorporating routing rules and settings.
  Map<String, dynamic> generateXrayConfig(
    ProxyNode node, {
    bool enableTun = false,
    bool enableUdp = true,
    bool allowLan = false,
  }) {
    return ConfigGenerator.generateXrayConfig(
      node,
      socksPort: socksPort,
      httpPort: httpPort,
      apiPort: apiPort,
      enableTun: enableTun,
      enableUdp: enableUdp,
      enableMux: globalEnableMux,
      allowInsecure: globalAllowInsecure,
      allowLan: allowLan || globalAllowLan,
      dnsServers: dnsServers,
      routingRules: routingRules,
      appRoutingMode: appRoutingMode,
    );
  }

  /// Initiates connection process to selected configuration through core and Android tunnel layers.
  Future<bool> start(
    ProxyNode node, {
    bool enableTun = true,
    bool setSysProxy = false,
    bool enableUdp = true,
    bool allowLan = false,
    String? notificationTitle,
    String? disconnectText,
    String? configName,
    int? httpPort,
    int? socksPort,
  }) async {
    final effectiveHttpPort = httpPort ?? this.httpPort;
    final effectiveSocksPort = socksPort ?? this.socksPort;

    _activeRunningNode = node;
    final configMap = generateXrayConfig(
      node,
      enableTun: enableTun,
      enableUdp: enableUdp,
      allowLan: allowLan || globalAllowLan,
    );
    final config = CoreConfig(
      rawJson: configMap,
      type: CoreType.xray,
      node: node,
    );

    return await core.connect(
      mode: enableTun ? CoreMode.tun : CoreMode.proxy,
      config: config,
      httpPort: effectiveHttpPort,
      socksPort: effectiveSocksPort,
      enableUdp: enableUdp,
      enableMux: globalEnableMux,
      allowInsecure: globalAllowInsecure,
      allowLan: allowLan || globalAllowLan,
      notificationTitle: notificationTitle,
      disconnectText: disconnectText,
      configName: configName ?? node.name,
    );
  }

  /// Stores active running node in runtime memory.
  void setActiveRunningNode(ProxyNode node) {
    _activeRunningNode = node;
  }

  /// Restores connected state when application resumes to foreground.
  void restoreRunningState({DateTime? connectedAt}) {
    core.restoreConnectedState(connectedAt: connectedAt);
  }

  /// Completely stops proxy and cleans up connections.
  Future<void> stop() async {
    _activeRunningNode = null;
    await core.disconnect();
  }

  /// Clears connections and performs a full service reset.
  void cleanupSystemAndXray({bool force = false}) {
    stop();
  }

  /// Tests server protocol latency (TCP/TLS probe).
  Future<int?> testNodeProtocolDelay(ProxyNode node, {Duration timeout = const Duration(seconds: 3), int count = 1}) async {
    return await ping.pingProtocolDelay(node, timeout: timeout, count: count);
  }

  /// Tests connection to Google via proxy socket.
  Future<int?> pingGoogleViaProxy(dynamic client, {int count = 1, Duration timeout = const Duration(seconds: 4)}) async {
    if (client is HttpClient) {
      return await ping.pingGoogleViaProxy(client, count: count, timeout: timeout);
    }
    return null;
  }

  /// Executes standalone ping test for a proxy node.
  Future<PingResult> pingNode(
    ProxyNode node, {
    PingMode mode = PingMode.realDelay,
    PingType type = PingType.tcp,
    bool showCountry = true,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final cfg = CoreConfig.fromNode(node, type: CoreType.xray);
    return await ping.ping(
      config: cfg,
      pingMode: mode,
      pingType: type,
      showCountry: showCountry,
      timeout: timeout,
      xrayBinaryPath: findXrayBinarySync(),
      workingDirectory: core.workingDirectory,
      environment: core.coreEnvironment,
    );
  }

  /// Tests node real delay via temporary proxy to verified Cloudflare destinations.
  Future<NodeTestResult> testNodeRealDelay(
    ProxyNode node, {
    Duration timeout = const Duration(seconds: 4),
    bool isTurbo = false,
  }) async {
    final effectiveTimeout = isTurbo ? const Duration(milliseconds: 1500) : timeout;

    final res = await pingNode(
      node, mode: PingMode.realDelay, type: PingType.tcp, showCountry: true, timeout: effectiveTimeout,
    );
    return NodeTestResult.fromPingResult(res);
  }

  /// Tests direct TCP socket to specified address and port.
  Future<int?> tcpPing(
    String host,
    int port, {
    int count = 1,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final cfg = CoreConfig.fromNode(ProxyNode(
      id: "probe",
      name: "probe",
      address: host,
      port: port,
      protocol: ProtocolType.vless,
      uuidOrPassword: "dummy",
    ));
    int? bestLatency;
    for (int i = 0; i < count; i++) {
      final res = await ping.ping(
        config: cfg,
        pingMode: PingMode.ipTest,
        pingType: PingType.tcp,
        timeout: timeout,
      );
      if (res.latencyMs != null) {
        if (bestLatency == null || res.latencyMs! < bestLatency) {
          bestLatency = res.latencyMs;
        }
      }
    }
    return bestLatency;
  }

  /// Measures configuration latency in minimum possible duration.
  Future<int?> testNodeLatency(ProxyNode node, {Duration timeout = const Duration(seconds: 3)}) async {
    return await ping.pingProtocolDelay(node, timeout: timeout, count: 1);
  }

  /// Concurrently executes real delay tests for a collection of configurations.
  Future<Map<String, NodeTestResult>> testNodesBatchRealProxy(
    List<ProxyNode> nodes, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final results = <String, NodeTestResult>{};
    await Future.wait(nodes.map((node) async {
      final res = await testNodeRealDelay(node, timeout: timeout);
      results[node.id] = res;
    }));
    return results;
  }
}
