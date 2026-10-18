// Application Settings & Preferences Providers
// Manages settings for core processes, networking, ports, DNS, permissions, and security features.
// All updates are immediately persisted to local storage and reflected in core configurations.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dns_settings.dart';
import '../services/storage_service.dart';
import '../services/xray_process_service.dart';
import 'app_lifecycle_providers.dart';
import 'test_settings_provider.dart';

export 'app_lifecycle_providers.dart';
export 'test_settings_provider.dart';

/// Controls enabling and disabling system-wide proxy.
class SystemProxyNotifier extends StateNotifier<bool> {
  /// Initializes with disabled state.
  SystemProxyNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final enabled = await StorageService.instance.loadSystemProxyEnabled();
    if (mounted) state = enabled;
  }

  /// Toggles the system proxy state.
  void toggle(bool enable) {
    state = enable;
    StorageService.instance.saveSystemProxyEnabled(enable);
    XrayProcessService.instance.setWindowsSystemProxy(enable);
  }
}

final isSystemProxyEnabledProvider = StateNotifierProvider<SystemProxyNotifier, bool>((ref) {
  return SystemProxyNotifier();
});

/// Controls enabling and disabling the VPN tunnel mode.
class TunNotifier extends StateNotifier<bool> {
  /// Initializes with default enabled state.
  TunNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final enabled = await StorageService.instance.loadTunEnabled();
    if (mounted) state = enabled;
  }

  /// Toggles the VPN tunnel mode state.
  void toggle(bool enable) {
    state = enable;
    StorageService.instance.saveTunEnabled(enable);
  }
}

final isTunEnabledProvider = StateNotifierProvider<TunNotifier, bool>((ref) {
  return TunNotifier();
});

/// Manages sharing proxy access across the local area network (LAN).
class AllowLanNotifier extends StateNotifier<bool> {
  /// Initializes with disabled state.
  AllowLanNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final enabled = await StorageService.instance.loadAllowLan();
    if (mounted) {
      state = enabled;
      XrayProcessService.instance.globalAllowLan = enabled;
    }
  }

  /// Toggles local network client access permissions for the proxy.
  void toggle(bool enable) {
    state = enable;
    XrayProcessService.instance.globalAllowLan = enable;
    StorageService.instance.saveAllowLan(enable);
  }
}

final allowLanProvider = StateNotifierProvider<AllowLanNotifier, bool>((ref) {
  return AllowLanNotifier();
});

/// Manages DNS configuration and nameserver settings.
class DnsNotifier extends StateNotifier<DnsSettings> {
  /// Loads initial DNS settings.
  DnsNotifier() : super(const DnsSettings()) {
    _load();
  }

  Future<void> _load() async {
    final saved = await StorageService.instance.loadDnsSettings();
    if (!mounted) return;
    state = saved;
    XrayProcessService.instance.dnsServers = saved.servers;
  }

  /// Selects a predefined DNS preset (Cloudflare, Google, etc.).
  Future<void> setPreset(String presetId) async {
    final preset = DnsSettings.presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => DnsSettings.presets.first,
    );
    final updated = state.copyWith(
      presetId: presetId,
      servers: preset.id == "custom" ? state.servers : preset.servers,
    );
    state = updated;
    XrayProcessService.instance.dnsServers = updated.servers;
    await StorageService.instance.saveDnsSettings(updated);
  }

  /// Configures custom DNS nameservers.
  Future<void> updateCustomServers(List<String> servers) async {
    final updated = state.copyWith(
      presetId: "custom",
      servers: servers,
    );
    state = updated;
    XrayProcessService.instance.dnsServers = updated.servers;
    await StorageService.instance.saveDnsSettings(updated);
  }
}

final dnsSettingsProvider = StateNotifierProvider<DnsNotifier, DnsSettings>((ref) {
  return DnsNotifier();
});

/// Controls the local core HTTP inbound port.
class HttpPortNotifier extends StateNotifier<int> {
  /// Initializes with default port 10888.
  HttpPortNotifier() : super(10888) {
    _init();
  }

  Future<void> _init() async {
    final p = await StorageService.instance.loadHttpPort();
    if (!mounted) return;
    state = p;
    XrayProcessService.instance.httpPort = p;
  }

  /// Sets the HTTP port number and updates the core.
  void setPort(int port) {
    state = port;
    XrayProcessService.instance.httpPort = port;
    StorageService.instance.saveHttpPort(port);
  }
}

final httpPortProvider = StateNotifierProvider<HttpPortNotifier, int>((ref) {
  return HttpPortNotifier();
});

/// Controls the local core SOCKS5 inbound port.
class SocksPortNotifier extends StateNotifier<int> {
  /// Initializes with default port 10999.
  SocksPortNotifier() : super(10999) {
    _init();
  }

  Future<void> _init() async {
    final p = await StorageService.instance.loadSocksPort();
    if (!mounted) return;
    state = p;
    XrayProcessService.instance.socksPort = p;
  }

  /// Sets the SOCKS port number and synchronizes with the core.
  void setPort(int port) {
    state = port;
    XrayProcessService.instance.socksPort = port;
    StorageService.instance.saveSocksPort(port);
  }
}

final socksPortProvider = StateNotifierProvider<SocksPortNotifier, int>((ref) {
  return SocksPortNotifier();
});

/// Controls global acceptance of invalid or self-signed TLS certificates.
class GlobalAllowInsecureNotifier extends StateNotifier<bool> {
  /// Initializes with disabled state by default.
  GlobalAllowInsecureNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final v = await StorageService.instance.loadGlobalAllowInsecure();
    if (!mounted) return;
    state = v;
    XrayProcessService.instance.globalAllowInsecure = v;
  }

  /// Toggles allowing insecure certificates.
  Future<void> toggle(bool val) async {
    state = val;
    XrayProcessService.instance.globalAllowInsecure = val;
    await StorageService.instance.saveGlobalAllowInsecure(val);
  }
}

final globalAllowInsecureProvider = StateNotifierProvider<GlobalAllowInsecureNotifier, bool>((ref) {
  return GlobalAllowInsecureNotifier();
});

/// Manages global multiplexing (Mux) activation across connections.
class GlobalEnableMuxNotifier extends StateNotifier<bool> {
  /// Initializes with disabled state.
  GlobalEnableMuxNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final v = await StorageService.instance.loadGlobalEnableMux();
    if (!mounted) return;
    state = v;
    XrayProcessService.instance.globalEnableMux = v;
  }

  /// Toggles the use of Mux in connections.
  Future<void> toggle(bool val) async {
    state = val;
    XrayProcessService.instance.globalEnableMux = val;
    await StorageService.instance.saveGlobalEnableMux(val);
  }
}

final globalEnableMuxProvider = StateNotifierProvider<GlobalEnableMuxNotifier, bool>((ref) {
  return GlobalEnableMuxNotifier();
});

/// Controls whether UDP packets are enabled in the tunnel.
class EnableUdpNotifier extends StateNotifier<bool> {
  EnableUdpNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.loadEnableUdp();
  }

  /// Toggles whether UDP protocol is enabled.
  Future<void> toggle(bool val) async {
    state = val;
    await StorageService.instance.saveEnableUdp(val);
  }
}

final enableUdpProvider = StateNotifierProvider<EnableUdpNotifier, bool>((ref) => EnableUdpNotifier());
