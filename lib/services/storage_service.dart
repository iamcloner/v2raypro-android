// =======================================================================
// [File Name]: storage_service.dart
// [Description]: Primary data and settings storage service on Android.
// Manages persistence of nodes, subscriptions, routes, proxy configuration,
// DNS settings, and UI appearance, with underlying disk backups.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "package:shared_preferences/shared_preferences.dart";
import "../models/dns_settings.dart";
import "../models/proxy_node.dart";
import "../models/routing_rule.dart";
import "../models/subscription_item.dart";
import "cdn_scanner_service.dart";
import "config_disk_storage.dart";
import "session_storage.dart";

export "config_disk_storage.dart";
export "session_storage.dart";

/// Service managing persistent storage and configuration loading on Android.
class StorageService {
  /// Singleton instance of StorageService.
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  static const _sysProxyKey = "v2raypro_sys_proxy";
  static const _tunKey = "v2raypro_tun_mode";
  static const _httpPortKey = "v2raypro_http_port";
  static const _socksPortKey = "v2raypro_socks_port";
  static const _allowInsecureKey = "v2raypro_global_allow_insecure";
  static const _enableMuxKey = "v2raypro_global_enable_mux";
  static const _allowLanKey = "v2raypro_allow_lan";
  static const _appRoutingModeKey = "v2raypro_app_routing_mode";

  /// Retrieves path to local JSON backup file on device storage.
  File _getBackupFile(String filename) => ConfigDiskStorage.instance.getBackupFile(filename);

  /// Saves user proxy node list with debouncing to prevent excessive disk writes.
  Future<void> saveNodes(List<ProxyNode> nodes, {bool immediate = false}) =>
      ConfigDiskStorage.instance.saveNodes(nodes, immediate: immediate);

  /// Loads saved proxy node list from disk and SharedPreferences.
  Future<List<ProxyNode>> loadNodes() => ConfigDiskStorage.instance.loadNodes();

  /// Saves user subscription links list.
  Future<void> saveSubscriptions(List<SubscriptionItem> subs, {bool immediate = false}) =>
      ConfigDiskStorage.instance.saveSubscriptions(subs, immediate: immediate);

  /// Loads saved subscription links list in the application.
  Future<List<SubscriptionItem>> loadSubscriptions() => ConfigDiskStorage.instance.loadSubscriptions();

  /// Saves free configs fetched from online repository.
  Future<void> saveFreeConfigs(List<ProxyNode> nodes) => ConfigDiskStorage.instance.saveFreeConfigs(nodes);

  /// Retrieves previously saved free configs.
  Future<List<ProxyNode>> loadFreeConfigs() => ConfigDiskStorage.instance.loadFreeConfigs();

  /// Saves list of traffic routing rules.
  Future<void> saveRoutingRules(List<RoutingRule> rules) => ConfigDiskStorage.instance.saveRoutingRules(rules);

  /// Loads list of traffic routing rules.
  Future<List<RoutingRule>> loadRoutingRules() => ConfigDiskStorage.instance.loadRoutingRules();

  /// Basic helper methods for reading and writing boolean values.
  Future<void> saveBool(String key, bool val) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(key, val);
    } catch (_) {}
  }

  Future<bool> loadBool(String key, {bool defaultValue = false}) async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> saveSystemProxyEnabled(bool val) => saveBool(_sysProxyKey, val);
  Future<bool> loadSystemProxyEnabled() => loadBool(_sysProxyKey, defaultValue: false);

  Future<void> saveTunEnabled(bool val) => saveBool(_tunKey, val);
  Future<bool> loadTunEnabled() => loadBool(_tunKey, defaultValue: true);

  Future<void> saveGlobalAllowInsecure(bool val) => saveBool(_allowInsecureKey, val);
  Future<bool> loadGlobalAllowInsecure() => loadBool(_allowInsecureKey, defaultValue: false);

  Future<void> saveGlobalEnableMux(bool val) => saveBool(_enableMuxKey, val);
  Future<bool> loadGlobalEnableMux() => loadBool(_enableMuxKey, defaultValue: false);

  Future<void> saveAllowLan(bool val) => saveBool(_allowLanKey, val);
  Future<bool> loadAllowLan() => loadBool(_allowLanKey, defaultValue: false);

  /// Saves per-app routing mode (bypass or allow list).
  Future<void> saveAppRoutingMode(AppRoutingMode mode) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_appRoutingModeKey, mode.name);
    } catch (_) {}
  }

  /// Loads per-app routing mode.
  Future<AppRoutingMode> loadAppRoutingMode() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final val = sp.getString(_appRoutingModeKey);
      if (val != null) {
        return AppRoutingMode.values.firstWhere(
          (m) => m.name == val,
          orElse: () => AppRoutingMode.exclusive,
        );
      }
    } catch (_) {}
    return AppRoutingMode.exclusive;
  }

  /// Saves dedicated CDN IP ranges.
  Future<void> saveCdnRanges(CdnProvider provider, List<String> ranges) async {
    try {
      final key = "v2raypro_${provider.id}_ranges";
      final str = jsonEncode(ranges);
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, str);

      final file = _getBackupFile("$key.json");
      await file.writeAsString(str);
    } catch (_) {}
  }

  /// Loads configured CDN IP ranges.
  Future<List<String>> loadCdnRanges(CdnProvider provider) async {
    try {
      final key = "v2raypro_${provider.id}_ranges";
      String? content;
      final sp = await SharedPreferences.getInstance();
      content = sp.getString(key);

      if (content == null || content.isEmpty) {
        final file = _getBackupFile("$key.json");
        if (await file.exists()) {
          content = await file.readAsString();
        }
      }

      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as List;
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return provider.defaultCidrs;
  }

  Future<void> saveCloudflareRanges(List<String> ranges) => saveCdnRanges(CdnProvider.cloudflare, ranges);
  Future<List<String>> loadCloudflareRanges() => loadCdnRanges(CdnProvider.cloudflare);

  /// Saves custom DNS settings.
  Future<void> saveDnsSettings(DnsSettings settings) async {
    try {
      final str = jsonEncode(settings.toJson());
      final sp = await SharedPreferences.getInstance();
      await sp.setString("v2raypro_dns_settings", str);

      final file = _getBackupFile("v2raypro_dns_settings.json");
      await file.writeAsString(str);
    } catch (_) {}
  }

  /// Retrieves custom DNS settings.
  Future<DnsSettings> loadDnsSettings() async {
    try {
      String? content;
      final sp = await SharedPreferences.getInstance();
      content = sp.getString("v2raypro_dns_settings");

      if (content == null || content.isEmpty) {
        final file = _getBackupFile("v2raypro_dns_settings.json");
        if (await file.exists()) {
          content = await file.readAsString();
        }
      }

      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        return DnsSettings.fromJson(decoded);
      }
    } catch (_) {}
    return const DnsSettings();
  }

  /// Helper methods for saving and loading integers and strings.
  Future<void> saveInt(String key, int val) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(key, val);
    } catch (_) {}
  }

  Future<int> loadInt(String key, {int defaultValue = 0}) async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getInt(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> saveString(String key, String val) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, val);
    } catch (_) {}
  }

  Future<String> loadString(String key, {String defaultValue = ""}) async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> saveHttpPort(int val) => saveInt(_httpPortKey, val);
  Future<int> loadHttpPort() => loadInt(_httpPortKey, defaultValue: 10888);

  Future<void> saveSocksPort(int val) => saveInt(_socksPortKey, val);
  Future<int> loadSocksPort() => loadInt(_socksPortKey, defaultValue: 10999);

  // Boot, theme, and localization setting keys
  static const _startOnBootKey = "v2raypro_start_on_boot";
  static const _autoConnectKey = "v2raypro_auto_connect";
  static const _autoSysProxyKey = "v2raypro_auto_sys_proxy";
  static const _autoTunKey = "v2raypro_auto_tun";
  static const _themeModeKey = "v2raypro_theme_mode";

  /// Windows startup setting method (no-op on Android).
  Future<void> setWindowsStartup(bool enable) async {}

  Future<void> saveStartOnBoot(bool val) => saveBool(_startOnBootKey, val);
  Future<bool> loadStartOnBoot() => loadBool(_startOnBootKey, defaultValue: false);

  Future<void> saveAutoConnect(bool val) => saveBool(_autoConnectKey, val);
  Future<bool> loadAutoConnect() => loadBool(_autoConnectKey, defaultValue: false);

  Future<void> saveAutoSysProxy(bool val) => saveBool(_autoSysProxyKey, val);
  Future<bool> loadAutoSysProxy() => loadBool(_autoSysProxyKey, defaultValue: false);

  Future<void> saveAutoTun(bool val) => saveBool(_autoTunKey, val);
  Future<bool> loadAutoTun() => loadBool(_autoTunKey, defaultValue: false);

  static const _enableUdpKey = "v2raypro_enable_udp";
  Future<void> saveEnableUdp(bool val) => saveBool(_enableUdpKey, val);
  Future<bool> loadEnableUdp() => loadBool(_enableUdpKey, defaultValue: true);

  Future<void> saveThemeMode(String mode) => saveString(_themeModeKey, mode);
  Future<String> loadThemeMode() => loadString(_themeModeKey, defaultValue: "system");

  static const _testModeKey = "v2raypro_test_mode";
  Future<void> saveTestMode(String mode) => saveString(_testModeKey, mode);
  Future<String> loadTestMode() => loadString(_testModeKey, defaultValue: "normal");

  static const _testConcurrencyKey = "v2raypro_test_concurrency";
  Future<void> saveTestConcurrency(int val) => saveInt(_testConcurrencyKey, val);
  Future<int> loadTestConcurrency() => loadInt(_testConcurrencyKey, defaultValue: 25);

  static const _localeKey = "v2raypro_current_locale";
  Future<void> saveLocale(String locale) => saveString(_localeKey, locale);
  Future<String?> loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_localeKey);
    } catch (_) {
      return null;
    }
  }

  /// Forwards active session methods to the specialized SessionStorage module.
  Future<void> saveActiveSession({
    required String nodeId,
    required DateTime connectedAt,
    String? exitIp,
    String? country,
    String? countryCode,
    int? uplinkBytes,
    int? downlinkBytes,
  }) => SessionStorage.instance.saveActiveSession(
    nodeId: nodeId,
    connectedAt: connectedAt,
    exitIp: exitIp,
    country: country,
    countryCode: countryCode,
    uplinkBytes: uplinkBytes,
    downlinkBytes: downlinkBytes,
  );

  Future<void> updateActiveSessionTraffic(int uplinkBytes, int downlinkBytes) =>
      SessionStorage.instance.updateActiveSessionTraffic(uplinkBytes, downlinkBytes);

  Future<void> updateActiveSessionOutbound({String? exitIp, String? country, String? countryCode}) =>
      SessionStorage.instance.updateActiveSessionOutbound(exitIp: exitIp, country: country, countryCode: countryCode);

  Future<Map<String, dynamic>?> loadActiveSession() => SessionStorage.instance.loadActiveSession();

  Future<void> clearActiveSession() => SessionStorage.instance.clearActiveSession();
}
