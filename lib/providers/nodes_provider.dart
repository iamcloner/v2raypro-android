// Proxy Nodes State Management Provider
// Manages stored proxy configuration lists, active node selection, and latency monitoring.
// All configuration mutations and test outcomes are persisted to local device storage.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import '../services/country_service.dart';
import '../services/storage_service.dart';
import 'nodes_helper.dart';

export 'nodes_helper.dart';

/// Manages the list of proxy nodes and servers.
/// Handles additions, removals, ping latency updates, and clean IP assignments.
class NodesNotifier extends StateNotifier<List<ProxyNode>> {
  /// Initializes the notifier and loads nodes from local database.
  NodesNotifier() : super([]) {
    _init();
  }

  /// Loads nodes and sanitizes legacy incorrect country codes caused by CDNs.
  Future<void> _init() async {
    final saved = await StorageService.instance.loadNodes();
    if (!mounted || saved.isEmpty) return;
    final fixed = sanitizeSavedNodes(saved);
    if (!mounted) return;
    state = fixed;
    _save();
  }

  void _save() {
    StorageService.instance.saveNodes(state);
  }

  /// Adds a new node to the list and persists changes.
  void addNode(ProxyNode node) {
    final isFirst = state.isEmpty;
    state = [...state, node.copyWith(isActive: isFirst ? true : node.isActive)];
    _save();
  }

  /// Adds a batch of nodes to the current list.
  void addNodes(List<ProxyNode> newNodes) {
    if (newNodes.isEmpty) return;
    final wasEmpty = state.isEmpty;
    final list = List<ProxyNode>.from(state);
    for (int i = 0; i < newNodes.length; i++) {
      final n = newNodes[i];
      list.add(n.copyWith(isActive: wasEmpty && i == 0 ? true : n.isActive));
    }
    state = list;
    _save();
  }

  /// Selects and marks a free node as active.
  void selectAndConnectFreeNode(ProxyNode freeNode) {
    final countryCode = freeNode.countryCode ?? CountryService.resolveSync(freeNode);
    final countryName = freeNode.country ?? (countryCode != null ? CountryService.getCountryName(countryCode) : null);
    final nodeWithMeta = freeNode.copyWith(
      countryCode: countryCode,
      country: countryName,
      isFree: true,
    );
    final existingIdx = state.indexWhere((n) => n.id == freeNode.id);
    if (existingIdx != -1) {
      state = state.map((n) => n.id == freeNode.id
          ? nodeWithMeta.copyWith(isActive: true)
          : n.copyWith(isActive: false)).toList();
    } else {
      final updated = state.map((n) => n.copyWith(isActive: false)).toList();
      state = [nodeWithMeta.copyWith(isActive: true), ...updated];
    }
    _save();
  }

  /// Updates ping latency and country metadata for a specified node.
  void updateLatency(String id, int? latencyMs, {String? countryCode, String? country}) {
    state = state.map((n) {
      if (n.id != id) return n;
      final bool isSuccess = latencyMs != null && latencyMs > 0;
      final String? fromName = CountryService.extractCountryCodeFromName(n.name);
      final String? intrinsicCountry = CountryService.resolveSync(n.copyWith(clearCountry: true));
      final bool clearCountry = !isSuccess && fromName == null && countryCode == null && intrinsicCountry == null;

      final String? verifiedCountryCode = clearCountry
          ? null
          : (isSuccess
              ? (countryCode ?? n.countryCode ?? intrinsicCountry)
              : (countryCode ?? intrinsicCountry ?? fromName));

      final String? verifiedCountry = clearCountry
          ? null
          : (isSuccess
              ? (country ?? (verifiedCountryCode != null ? CountryService.getCountryName(verifiedCountryCode) : n.country))
              : (country ?? (verifiedCountryCode != null ? CountryService.getCountryName(verifiedCountryCode) : null)));

      return n.copyWith(
        latencyMs: latencyMs,
        clearLatency: latencyMs == null,
        clearCountry: clearCountry,
        countryCode: verifiedCountryCode,
        country: verifiedCountry,
        lastTestedAt: DateTime.now(),
      );
    }).toList();
    _save();
  }

  /// Batch updates latency for multiple nodes simultaneously.
  void updateLatenciesBatch(Map<String, int?> latencies, {Map<String, String>? countryCodes}) {
    if (latencies.isEmpty) return;
    final now = DateTime.now();
    state = state.map((n) {
      if (!latencies.containsKey(n.id)) return n;
      final lat = latencies[n.id];
      final bool isSuccess = lat != null && lat > 0;
      final String? fromName = CountryService.extractCountryCodeFromName(n.name);
      final cCode = isSuccess ? (countryCodes?[n.id] ?? n.countryCode) : fromName;
      final bool clearCountry = !isSuccess && fromName == null;

      return n.copyWith(
        latencyMs: lat,
        clearLatency: lat == null,
        clearCountry: clearCountry,
        countryCode: cCode,
        country: cCode != null ? CountryService.getCountryName(cCode) : null,
        lastTestedAt: now,
      );
    }).toList();
    _save();
  }

  /// Removes a specific node by its unique identifier.
  void removeNode(String id) {
    state = state.where((n) => n.id != id).toList();
    if (state.isNotEmpty && !state.any((n) => n.isActive)) {
      state[0].isActive = true;
      state = [...state];
    }
    _save();
  }

  /// Completely clears all nodes from state and storage.
  void clearAllNodes() {
    state = [];
    _save();
  }

  /// Clears custom manual nodes while preserving subscription nodes.
  void clearCustomNodes() {
    state = state.where((n) => n.subscriptionId != null || n.isFree).toList();
    if (state.isNotEmpty && !state.any((n) => n.isActive)) {
      state[0].isActive = true;
      state = [...state];
    }
    _save();
  }

  /// Removes all nodes associated with a specific subscription ID.
  void removeNodesBySubscription(String subId) {
    state = state.where((n) => n.subscriptionId != subId).toList();
    if (state.isNotEmpty && !state.any((n) => n.isActive)) {
      state[0].isActive = true;
      state = [...state];
    }
    _save();
  }

  /// Removes dead or unresponsive configurations.
  int removeDeadNodes({String? subscriptionId, bool onlyCustom = false, bool includeUntested = false}) {
    final toRemove = <String>{};
    for (final n in state) {
      if (onlyCustom && (n.subscriptionId != null || n.isFree)) continue;
      if (subscriptionId != null && n.subscriptionId != subscriptionId) continue;
      final isDead = includeUntested ? !n.hasValidPing : n.hasTimedOut;
      if (isDead) toRemove.add(n.id);
    }
    if (toRemove.isEmpty) return 0;

    state = state.where((n) => !toRemove.contains(n.id)).toList();
    if (state.isNotEmpty && !state.any((n) => n.isActive)) {
      state[0].isActive = true;
      state = [...state];
    }
    _save();
    return toRemove.length;
  }

  /// Replaces subscription nodes while preserving ping and IDs of unchanged configs.
  void replaceSubscriptionNodes(String subId, List<ProxyNode> newNodes) {
    final oldSubNodes = state.where((n) => n.subscriptionId == subId).toList();
    final nonSubNodes = state.where((n) => n.subscriptionId != subId).toList();

    final oldMap = <String, List<ProxyNode>>{};
    for (final old in oldSubNodes) {
      final k = makeConfigKey(old);
      (oldMap[k] ??= []).add(old);
    }

    final updatedSubNodes = <ProxyNode>[];
    for (final newNode in newNodes) {
      final k = makeConfigKey(newNode);
      final candidateList = oldMap[k];
      ProxyNode? match;
      if (candidateList != null && candidateList.isNotEmpty) {
        match = candidateList.removeAt(0);
      }

      if (match != null) {
        updatedSubNodes.add(newNode.copyWith(
          id: match.id,
          latencyMs: match.latencyMs,
          lastTestedAt: match.lastTestedAt,
          isActive: match.isActive,
          originalAddress: match.originalAddress,
          subscriptionId: subId,
        ));
      } else {
        updatedSubNodes.add(newNode.copyWith(
          subscriptionId: subId,
          isActive: false,
        ));
      }
    }

    final combined = [...nonSubNodes, ...updatedSubNodes];
    bool hasActive = false;
    for (int i = 0; i < combined.length; i++) {
      if (combined[i].isActive) {
        if (hasActive) {
          combined[i] = combined[i].copyWith(isActive: false);
        } else {
          hasActive = true;
        }
      }
    }
    if (combined.isNotEmpty && !hasActive) {
      combined[0] = combined[0].copyWith(isActive: true);
    }

    state = combined;
    _save();
  }

  /// Sets the active node used for establishing proxy connection.
  void setActive(String id) {
    state = state.map((n) => n.copyWith(isActive: n.id == id)).toList();
    _save();
  }

  /// Updates configuration details for an edited node.
  void updateNode(ProxyNode updated) {
    state = state.map((n) => n.id == updated.id ? updated : n).toList();
    _save();
  }

  /// Applies clean IP while preserving original domain in host header and SNI.
  void applyIp(String nodeId, String newIp, {int? latencyMs, String? countryCode, String? country}) {
    state = state.map((n) {
      if (n.id != nodeId) return n;
      final orig = n.originalAddress ?? n.address;
      final isDomain = !orig.contains(RegExp(r'^\d+\.\d+\.\d+\.\d+$'));
      return n.copyWith(
        originalAddress: orig,
        address: newIp,
        host: (n.host != null && n.host!.isNotEmpty) ? n.host : (isDomain ? orig : null),
        sni: (n.sni != null && n.sni!.isNotEmpty) ? n.sni : (isDomain ? orig : null),
        latencyMs: latencyMs ?? n.latencyMs,
        countryCode: countryCode ?? n.countryCode,
        country: country ?? n.country,
        lastTestedAt: latencyMs != null ? DateTime.now() : n.lastTestedAt,
      );
    }).toList();
    _save();
  }

  /// Clears latency measurements and country statuses for nodes.
  void clearLatencies({String? subscriptionId, bool onlyCustom = false}) {
    state = state.map((n) {
      if (onlyCustom && n.subscriptionId != null) return n;
      if (subscriptionId != null && n.subscriptionId != subscriptionId) return n;
      final fromName = CountryService.extractCountryCodeFromName(n.name);
      return n.copyWith(
        clearLatency: true,
        clearCountry: fromName == null,
        countryCode: fromName,
        country: fromName != null ? CountryService.getCountryName(fromName) : null,
      );
    }).toList();
    _save();
  }

  /// Restores original address of the config and removes scanned clean IP.
  void restoreAddress(String nodeId) {
    state = state.map((n) {
      if (n.id == nodeId && n.originalAddress != null) {
        return n.copyWith(
          address: n.originalAddress!,
          clearOriginalAddress: true,
        );
      }
      return n;
    }).toList();
    _save();
  }
}

/// Riverpod provider for accessing the proxy node list.
final nodesProvider = StateNotifierProvider<NodesNotifier, List<ProxyNode>>((ref) {
  return NodesNotifier();
});
