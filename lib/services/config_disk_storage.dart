// Configuration Disk Storage
// Manages local disk backup files and SharedPreferences caching for nodes, subscriptions, free configs, and routing rules.
// Implements debounced file-writing to reduce flash write cycles on mobile hardware.
// Provides transparent fallback between JSON disk files and Android shared preferences.

import "dart:async";
import "dart:convert";
import "dart:io";
import "package:shared_preferences/shared_preferences.dart";
import "../models/proxy_node.dart";
import "../models/routing_rule.dart";
import "../models/subscription_item.dart";

/// Manages persistent storage of core node data, subscriptions, and routing rules on local storage.
class ConfigDiskStorage {
  static final ConfigDiskStorage instance = ConfigDiskStorage._internal();
  ConfigDiskStorage._internal();

  Timer? _nodesDebounceTimer;
  Timer? _subsDebounceTimer;

  static const _nodesKey = "v2raypro_saved_nodes";
  static const _subsKey = "v2raypro_saved_subs";
  static const _freeConfigsKey = "v2raypro_saved_free_configs";
  static const _routingRulesKey = "v2raypro_routing_rules";

  /// Resolves the local JSON backup file path on device storage.
  File getBackupFile(String filename) {
    try {
      final tmp = Directory.systemTemp.path;
      final configDir = Directory("$tmp/v2raypro_config");
      if (!configDir.existsSync()) {
        configDir.createSync(recursive: true);
      }
      return File("${configDir.path}/$filename");
    } catch (_) {
      return File("${Directory.systemTemp.path}/$filename");
    }
  }

  /// Saves user proxy node list with debouncing to prevent excessive disk writes.
  Future<void> saveNodes(List<ProxyNode> nodes, {bool immediate = false}) async {
    _nodesDebounceTimer?.cancel();
    if (immediate) {
      await _writeNodesToDisk(nodes);
    } else {
      _nodesDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        _writeNodesToDisk(nodes);
      });
    }
  }

  Future<void> _writeNodesToDisk(List<ProxyNode> nodes) async {
    try {
      final jsonList = nodes.map((n) => n.toJson()).toList();
      final str = jsonEncode(jsonList);

      final file = getBackupFile("v2raypro_nodes.json");
      await file.writeAsString(str);

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_nodesKey, str);
    } catch (_) {}
  }

  /// Loads saved proxy node list from disk and SharedPreferences.
  Future<List<ProxyNode>> loadNodes() async {
    try {
      String? content;
      final file = getBackupFile("v2raypro_nodes.json");
      if (await file.exists()) {
        content = await file.readAsString();
      }

      if (content == null || content.isEmpty) {
        final sp = await SharedPreferences.getInstance();
        content = sp.getString(_nodesKey);
      }

      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as List;
        return decoded.map((e) => ProxyNode.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Saves user subscription links list.
  Future<void> saveSubscriptions(List<SubscriptionItem> subs, {bool immediate = false}) async {
    _subsDebounceTimer?.cancel();
    if (immediate) {
      await _writeSubscriptionsToDisk(subs);
    } else {
      _subsDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        _writeSubscriptionsToDisk(subs);
      });
    }
  }

  Future<void> _writeSubscriptionsToDisk(List<SubscriptionItem> subs) async {
    try {
      final jsonList = subs.map((s) => s.toJson()).toList();
      final str = jsonEncode(jsonList);

      final file = getBackupFile("v2raypro_subs.json");
      await file.writeAsString(str);

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_subsKey, str);
    } catch (_) {}
  }

  /// Loads saved subscription links list in the application.
  Future<List<SubscriptionItem>> loadSubscriptions() async {
    try {
      String? content;
      final file = getBackupFile("v2raypro_subs.json");
      if (await file.exists()) {
        content = await file.readAsString();
      }

      if (content == null || content.isEmpty) {
        final sp = await SharedPreferences.getInstance();
        content = sp.getString(_subsKey);
      }

      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as List;
        return decoded.map((e) => SubscriptionItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Saves free configs fetched from online repository.
  Future<void> saveFreeConfigs(List<ProxyNode> nodes) async {
    try {
      final jsonList = nodes.map((n) => n.toJson()).toList();
      final str = jsonEncode(jsonList);

      final file = getBackupFile("v2raypro_free_configs.json");
      await file.writeAsString(str);

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_freeConfigsKey, str);
    } catch (_) {}
  }

  /// Retrieves previously saved free configs.
  Future<List<ProxyNode>> loadFreeConfigs() async {
    try {
      String? content;
      final file = getBackupFile("v2raypro_free_configs.json");
      if (await file.exists()) {
        content = await file.readAsString();
      }

      if (content == null || content.isEmpty) {
        final sp = await SharedPreferences.getInstance();
        content = sp.getString(_freeConfigsKey);
      }

      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as List;
        return decoded.map((e) => ProxyNode.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Saves list of traffic routing rules.
  Future<void> saveRoutingRules(List<RoutingRule> rules) async {
    try {
      final jsonList = rules.map((r) => r.toJson()).toList();
      final str = jsonEncode(jsonList);
      final file = getBackupFile("v2raypro_routing_rules.json");
      await file.writeAsString(str);

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_routingRulesKey, str);
    } catch (_) {}
  }

  /// Loads list of traffic routing rules.
  Future<List<RoutingRule>> loadRoutingRules() async {
    try {
      String? content;
      final file = getBackupFile("v2raypro_routing_rules.json");
      if (await file.exists()) {
        content = await file.readAsString();
      }

      if (content == null || content.isEmpty) {
        final sp = await SharedPreferences.getInstance();
        content = sp.getString(_routingRulesKey);
      }

      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content) as List;
        return decoded.map((e) => RoutingRule.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}
