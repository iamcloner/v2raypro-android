// Connection Lifecycle & VPN State Provider
// Manages the VPN connection lifecycle, connection, disconnection, reconnection, and Android native service coordination.
// Tracks connection states across disconnected, connecting, connected, and error states, applying corresponding settings.

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import '../services/core_service.dart';
import '../services/country_service.dart';
import '../services/ping_service.dart';
import '../services/real_delay_service.dart';
import '../services/storage_service.dart';
import '../services/tray_service.dart';
import '../services/tun_service.dart';
import '../services/xray_process_service.dart';
import 'nodes_provider.dart';
import 'outbound_info_provider.dart';
import 'settings_providers.dart';
import 'traffic_provider.dart';

/// Provider for the singleton Xray Core service instance.
final coreServiceProvider = Provider<CoreService>((ref) => CoreService.instance);

/// Provider for the Android VpnService tunnel service instance.
final tunServiceProvider = Provider<TunService>((ref) => TunService.instance);

/// Provider for the latency and ping measurement service instance.
final pingServiceProvider = Provider<PingService>((ref) => PingService.instance);

/// Connection lifecycle states for the proxy.
enum ConnectionStateEnum {
  /// Completely disconnected.
  disconnected,
  /// Preparing and establishing the tunnel.
  connecting,
  /// Connected and traffic is flowing.
  connected,
  /// Disconnecting tunnel service and stopping core process.
  disconnecting,
  /// Error occurred during startup or tunnel establishment.
  error,
}

/// Manages application-wide proxy connection state.
/// Handles startup, connection, disconnection, and state recovery upon app launch.
class ConnectionStatusNotifier extends StateNotifier<ConnectionStateEnum> {
  final Ref ref;

  /// Initializes with disconnected state and listens for disconnect events from the Android notification.
  ConnectionStatusNotifier(this.ref) : super(ConnectionStateEnum.disconnected) {
    if (Platform.isAndroid) {
      XrayProcessService.instance.onAndroidNotificationDisconnect = () {
        setDisconnected();
      };
      checkExistingConnection();
    }
  }

  /// Checks for an existing active Android connection to restore state immediately when reopened.
  Future<void> checkExistingConnection() async {
    if (!Platform.isAndroid) return;
    try {
      final session = await StorageService.instance.loadActiveSession();
      final isRunning = await XrayProcessService.instance.isAndroidVpnRunning();

      if (!isRunning) {
        if (session != null) {
          await StorageService.instance.clearActiveSession();
        }
        state = ConnectionStateEnum.disconnected;
        return;
      }

      if (session != null) {
        final connectedAt = session['connectedAt'] as DateTime?;
        final nodeId = session['nodeId'] as String?;
        final exitIp = session['exitIp'] as String?;
        final country = session['country'] as String?;
        final countryCode = session['countryCode'] as String?;
        final up = session['uplinkBytes'] as int? ?? 0;
        final down = session['downlinkBytes'] as int? ?? 0;

        ref.read(connectedAtProvider.notifier).state = connectedAt ?? DateTime.now();
        ref.read(trafficStatsProvider.notifier).restoreBaseline(up, down);

        if (exitIp != null || countryCode != null) {
          ref.read(outboundInfoProvider.notifier).setRestored(
            ipv4: exitIp?.contains('.') == true ? exitIp : null,
            ipv6: exitIp?.contains(':') == true ? exitIp : null,
            country: country,
            countryCode: countryCode,
          );
        }

        if (nodeId != null) {
          ref.read(nodesProvider.notifier).setActive(nodeId);
          final nodes = ref.read(nodesProvider);
          final active = nodes.where((n) => n.id == nodeId).firstOrNull;
          if (active != null) {
            XrayProcessService.instance.setActiveRunningNode(active);
          }
        }

        state = ConnectionStateEnum.connected;
        XrayProcessService.instance.restoreRunningState(connectedAt: connectedAt);
        ref.read(outboundInfoProvider.notifier).fetch();
        _testPing();
      } else {
        state = ConnectionStateEnum.connected;
        final now = DateTime.now();
        ref.read(connectedAtProvider.notifier).state ??= now;
        XrayProcessService.instance.restoreRunningState(connectedAt: ref.read(connectedAtProvider));
        ref.read(outboundInfoProvider.notifier).fetch();
        _testPing();
      }
    } catch (_) {}
  }

  /// Marks state as connected, triggers ping test, and fetches outbound info.
  void setConnected() {
    final now = DateTime.now();
    ref.read(connectedAtProvider.notifier).state = now;
    state = ConnectionStateEnum.connected;

    final active = ref.read(nodesProvider).where((n) => n.isActive).firstOrNull;
    if (active != null) {
      StorageService.instance.saveActiveSession(
        nodeId: active.id,
        connectedAt: now,
        country: active.country,
        countryCode: active.countryCode,
      );
    }

    ref.read(outboundInfoProvider.notifier).fetch();
    _testPing();
    AppTrayService.instance.updateTrayMenu();

    if (ref.read(autoEnableSysProxyOnConnectProvider) && !ref.read(isSystemProxyEnabledProvider)) {
      ref.read(isSystemProxyEnabledProvider.notifier).toggle(true);
    }
    if (ref.read(autoEnableTunOnConnectProvider) && !ref.read(isTunEnabledProvider)) {
      ref.read(isTunEnabledProvider.notifier).toggle(true);
    }
  }

  /// Marks state as disconnected and clears session data.
  void setDisconnected() {
    ref.read(connectedAtProvider.notifier).state = null;
    ref.read(outboundInfoProvider.notifier).reset();
    ref.read(trafficStatsProvider.notifier).reset();
    StorageService.instance.clearActiveSession();
    state = ConnectionStateEnum.disconnected;
    AppTrayService.instance.updateTrayMenu();
  }

  /// Tests server round-trip latency after establishing connection via local port.
  Future<void> _testPing() async {
    final nodes = ref.read(nodesProvider);
    if (nodes.isEmpty) return;
    final active = nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);

    int? pingLatency;
    String? countryCode;
    String? countryName;

    if (state == ConnectionStateEnum.connected) {
      final httpPort = ref.read(httpPortProvider);
      final client = HttpClient();
      client.findProxy = (uri) => "PROXY 127.0.0.1:$httpPort";
      client.connectionTimeout = const Duration(seconds: 4);

      final testUrls = [
        Uri.parse("http://cp.cloudflare.com/generate_204"),
        Uri.parse("http://www.google.com/generate_204"),
      ];
      for (final testUri in testUrls) {
        try {
          final sw = Stopwatch()..start();
          final req = await client.getUrl(testUri).timeout(const Duration(seconds: 3));
          final resp = await req.close().timeout(const Duration(seconds: 3));
          sw.stop();
          await resp.drain();
          if (resp.statusCode == 200 || resp.statusCode == 204) {
            pingLatency = sw.elapsedMilliseconds;
            break;
          }
        } catch (_) {}
      }
    }

    if (pingLatency == null) {
      final res = await testRealDelay(
        mode: 'normal',
        type: 'xray',
        config: active.toJson(),
      );
      pingLatency = res.ping;
      countryCode = res.country?.toUpperCase();
      countryName = res.countryName;
    }

    final outbound = ref.read(outboundInfoProvider);
    final country = countryCode ?? outbound.countryCode ?? active.countryCode;
    ref.read(nodesProvider.notifier).updateLatency(
      active.id,
      pingLatency ?? active.latencyMs,
      countryCode: country,
      country: countryName ?? (country != null ? CountryService.getCountryName(country) : null) ?? outbound.country ?? active.country,
    );
  }

  /// Switches active node and reconnects if proxy is currently active.
  Future<void> switchNode(String id) async {
    ref.read(nodesProvider.notifier).setActive(id);
    if (state == ConnectionStateEnum.connected || state == ConnectionStateEnum.connecting) {
      final nodes = ref.read(nodesProvider);
      final target = nodes.firstWhere((n) => n.id == id, orElse: () => nodes.first);
      state = ConnectionStateEnum.connecting;
      await connect(target);
    }
  }

  /// Initiates connection process to the target node.
  Future<void> connect([ProxyNode? targetNode]) async {
    final nodes = ref.read(nodesProvider);
    if (nodes.isEmpty) {
      state = ConnectionStateEnum.error;
      return;
    }

    final activeNode = targetNode ?? nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);
    final isTun = ref.read(isTunEnabledProvider) || ref.read(autoEnableTunOnConnectProvider);
    final isSysProxy = ref.read(isSystemProxyEnabledProvider) || ref.read(autoEnableSysProxyOnConnectProvider);
    final enableUdp = ref.read(enableUdpProvider);
    final allowLan = ref.read(allowLanProvider);
    final locale = ref.read(currentLocaleProvider);
    final notificationTitle = locale == 'fa' ? 'وی‌تو‌ری پرو - متصل' : 'V2RayPro - Connected';
    final disconnectText = locale == 'fa' ? 'قطع اتصال' : 'Disconnect';
    final configName = activeNode.name.isNotEmpty
        ? activeNode.name
        : (locale == 'fa' ? 'کانفیگ متصل' : 'Connected Config');

    final httpPort = ref.read(httpPortProvider);
    final socksPort = ref.read(socksPortProvider);

    state = ConnectionStateEnum.connecting;
    final ok = await XrayProcessService.instance.start(
      activeNode,
      enableTun: isTun,
      setSysProxy: isSysProxy,
      enableUdp: enableUdp,
      allowLan: allowLan,
      notificationTitle: notificationTitle,
      disconnectText: disconnectText,
      configName: configName,
      httpPort: httpPort,
      socksPort: socksPort,
    );
    if (ok) {
      setConnected();
    } else {
      state = ConnectionStateEnum.error;
    }
  }

  /// Reconnects to the specified or current node.
  Future<void> reconnect([ProxyNode? targetNode]) async {
    state = ConnectionStateEnum.connecting;
    await connect(targetNode);
  }

  /// Applies modified settings by restarting the current config if connected.
  Future<void> reconnectWithUpdatedSettings() async {
    if (state == ConnectionStateEnum.connected) {
      final nodes = ref.read(nodesProvider);
      if (nodes.isEmpty) return;
      final active = nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);
      state = ConnectionStateEnum.connecting;
      await connect(active);
    }
  }

  /// Toggles connection state (disconnects if connected, connects if disconnected).
  Future<void> toggleConnect() async {
    if (state == ConnectionStateEnum.disconnected || state == ConnectionStateEnum.error) {
      await connect();
    } else if (state == ConnectionStateEnum.connected) {
      state = ConnectionStateEnum.disconnecting;
      await XrayProcessService.instance.stop();
      setDisconnected();
    }
  }
}

/// Riverpod provider for real-time proxy connection status.
final connectionStatusProvider = StateNotifierProvider<ConnectionStatusNotifier, ConnectionStateEnum>((ref) {
  return ConnectionStatusNotifier(ref);
});
