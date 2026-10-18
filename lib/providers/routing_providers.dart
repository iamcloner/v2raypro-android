// Routing Rules and App Routing Mode Providers
// Manages traffic routing rules and per-app routing modes.
// Specifies whether targeted domains or applications route directly or through proxy.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routing_rule.dart';
import '../services/storage_service.dart';
import '../services/xray_process_service.dart';

export '../models/routing_rule.dart';

/// Manages the list of traffic routing rules (bypass, block, proxy).
/// Loads, persists, and applies routing rules to the core process.
class RoutingRulesNotifier extends StateNotifier<List<RoutingRule>> {
  /// Initializes the notifier and loads rules from local storage.
  RoutingRulesNotifier() : super([]) {
    _init();
  }

  /// Loads saved rules and propagates them to Xray Core.
  Future<void> _init() async {
    final saved = await StorageService.instance.loadRoutingRules();
    if (!mounted) return;
    state = saved;
    XrayProcessService.instance.routingRules = saved;
  }

  /// Adds a new routing rule and applies it to the core.
  Future<void> addRule(RoutingRule rule) async {
    state = [...state, rule];
    XrayProcessService.instance.routingRules = state;
    await StorageService.instance.saveRoutingRules(state);
  }

  /// Updates an existing routing rule by ID.
  Future<void> updateRule(RoutingRule updated) async {
    state = state.map((r) => r.id == updated.id ? updated : r).toList();
    XrayProcessService.instance.routingRules = state;
    await StorageService.instance.saveRoutingRules(state);
  }

  /// Deletes a routing rule from state and persistent storage.
  Future<void> deleteRule(String id) async {
    state = state.where((r) => r.id != id).toList();
    XrayProcessService.instance.routingRules = state;
    await StorageService.instance.saveRoutingRules(state);
  }

  /// Toggles the enabled state of a routing rule.
  Future<void> toggleRule(String id, bool enabled) async {
    state = state.map((r) => r.id == id ? r.copyWith(enabled: enabled) : r).toList();
    XrayProcessService.instance.routingRules = state;
    await StorageService.instance.saveRoutingRules(state);
  }
}

/// Riverpod provider for application traffic routing rules.
final routingRulesProvider = StateNotifierProvider<RoutingRulesNotifier, List<RoutingRule>>((ref) {
  return RoutingRulesNotifier();
});

/// Manages per-app split routing mode (inclusive vs exclusive).
/// Determines whether selected apps route through or bypass the VPN tunnel.
class AppRoutingModeNotifier extends StateNotifier<AppRoutingMode> {
  /// Initializes with the default exclusive mode.
  AppRoutingModeNotifier() : super(AppRoutingMode.exclusive) {
    _init();
  }

  /// Loads the saved routing mode from storage.
  Future<void> _init() async {
    final mode = await StorageService.instance.loadAppRoutingMode();
    if (mounted) {
      state = mode;
      XrayProcessService.instance.appRoutingMode = mode;
    }
  }

  /// Sets and persists the app routing mode.
  Future<void> setMode(AppRoutingMode mode) async {
    state = mode;
    XrayProcessService.instance.appRoutingMode = mode;
    await StorageService.instance.saveAppRoutingMode(mode);
  }
}

/// Riverpod provider for the app routing mode state.
final appRoutingModeProvider = StateNotifierProvider<AppRoutingModeNotifier, AppRoutingMode>((ref) {
  return AppRoutingModeNotifier();
});
