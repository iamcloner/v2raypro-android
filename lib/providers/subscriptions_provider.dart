// Subscription Links Management Provider
// Manages loading, adding, editing, and automated updates of subscription links.
// Fetches and parses configs from subscription URLs, syncing them with active node state.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import '../models/subscription_item.dart';
import '../services/storage_service.dart';
import '../utils/config_parser.dart';
import 'nodes_provider.dart';

/// Manages user subscription links and their scheduled updates.
/// Responsible for fetching configs and extracting quota and expiration metadata.
class SubscriptionsNotifier extends StateNotifier<List<SubscriptionItem>> {
  final Ref ref;
  Timer? _autoUpdateTimer;

  /// Initializes state and starts the periodic auto-update timer.
  SubscriptionsNotifier(this.ref) : super([]) {
    _init();
    _startAutoUpdateTimer();
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  /// Periodic check every 10 minutes for subscriptions updated more than an hour ago.
  void _startAutoUpdateTimer() {
    _autoUpdateTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _checkHourlyAutoUpdate();
    });
  }

  Future<void> _checkHourlyAutoUpdate() async {
    final now = DateTime.now();
    for (final s in state) {
      if (s.autoUpdate) {
        if (s.lastUpdated == null || now.difference(s.lastUpdated!).inMinutes >= 60) {
          await updateSubscription(s.id);
        }
      }
    }
  }

  Future<void> _init() async {
    final saved = await StorageService.instance.loadSubscriptions();
    if (!mounted) return;
    state = saved;
    _checkHourlyAutoUpdate();
  }

  void _save() {
    StorageService.instance.saveSubscriptions(state);
  }

  /// Enables or disables periodic auto-updates for a subscription.
  void toggleAutoUpdate(String id, bool val) {
    state = state.map((s) => s.id == id ? s.copyWith(autoUpdate: val) : s).toList();
    _save();
    if (val) {
      _checkHourlyAutoUpdate();
    }
  }

  /// Adds a new subscription link and immediately fetches its configurations.
  Future<int> addSubscription(String name, String url) async {
    final subId = "sub-${DateTime.now().millisecondsSinceEpoch}";
    final item = SubscriptionItem(
      id: subId,
      name: name.trim().isEmpty ? "Subscription ${state.length + 1}" : name.trim(),
      url: url.trim(),
    );
    state = [...state, item];
    _save();
    return await updateSubscription(subId);
  }

  /// Removes a subscription and all associated nodes.
  void removeSubscription(String id) {
    state = state.where((s) => s.id != id).toList();
    _save();
    ref.read(nodesProvider.notifier).removeNodesBySubscription(id);
  }

  /// Updates the name or URL of an existing subscription.
  void editSubscription(String id, String newName, String newUrl) {
    final cleanUrl = newUrl.trim();
    final cleanName = newName.trim();
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(
          name: cleanName.isNotEmpty ? cleanName : s.name,
          url: cleanUrl.isNotEmpty ? cleanUrl : s.url,
        );
      }
      return s;
    }).toList();
    _save();
    updateSubscription(id);
  }

  /// Downloads and parses subscription configurations and traffic usage headers.
  Future<int> updateSubscription(String id) async {
    final idx = state.indexWhere((s) => s.id == id);
    if (idx == -1) return 0;
    final sub = state[idx];

    try {
      final uri = Uri.parse(sub.url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      request.headers.set("User-Agent", "v2rayN/6.42");
      final response = await request.close();

      int? uploadBytes;
      int? downloadBytes;
      int? totalBytes;
      DateTime? expireDate;

      final userInfo = response.headers.value("subscription-userinfo") ??
          response.headers.value("Subscription-Userinfo");
      if (userInfo != null && userInfo.isNotEmpty) {
        final pairs = userInfo.split(";");
        for (final pair in pairs) {
          final kv = pair.trim().split("=");
          if (kv.length == 2) {
            final key = kv[0].trim().toLowerCase();
            final val = int.tryParse(kv[1].trim());
            if (val != null) {
              if (key == "upload") uploadBytes = val;
              if (key == "download") downloadBytes = val;
              if (key == "total") totalBytes = val;
              if (key == "expire") {
                expireDate = DateTime.fromMillisecondsSinceEpoch(val * 1000);
              }
            }
          }
        }
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final parsed = await ConfigParser.parseBatchAsync(body);

      // Fallback: extract quota and expiry metadata from config names if HTTP headers are absent
      if (totalBytes == null || expireDate == null) {
        for (final node in parsed) {
          final name = node.name;
          if (totalBytes == null) {
            final totalMatch = RegExp(r'(\d+)\s*(?:G|GB)', caseSensitive: false).firstMatch(name);
            final remMatch = RegExp(r'📊?\s*([\d\.]+)\s*GB', caseSensitive: false).firstMatch(name);
            if (remMatch != null) {
              final gb = double.tryParse(remMatch.group(1) ?? "");
              if (gb != null) {
                final remBytes = (gb * 1024 * 1024 * 1024).toInt();
                if (totalMatch != null) {
                  final totGb = double.tryParse(totalMatch.group(1) ?? "");
                  if (totGb != null) {
                    totalBytes = (totGb * 1024 * 1024 * 1024).toInt();
                    downloadBytes = totalBytes - remBytes;
                    uploadBytes = 0;
                  }
                } else {
                  totalBytes = remBytes;
                  uploadBytes = 0;
                  downloadBytes = 0;
                }
              }
            }
          }
          if (expireDate == null) {
            final dayMatch = RegExp(r'⏳\s*(\d+)\s*D', caseSensitive: false).firstMatch(name);
            if (dayMatch != null) {
              final days = int.tryParse(dayMatch.group(1) ?? "");
              if (days != null) {
                expireDate = DateTime.now().add(Duration(days: days));
              }
            }
          }
        }
      }

      if (parsed.isNotEmpty) {
        final tagged = parsed.map((n) => n.copyWith(subscriptionId: sub.id)).toList();
        ref.read(nodesProvider.notifier).replaceSubscriptionNodes(sub.id, tagged);
        state[idx] = sub.copyWith(
          lastUpdated: DateTime.now(),
          nodeCount: tagged.length,
          uploadBytes: uploadBytes ?? sub.uploadBytes,
          downloadBytes: downloadBytes ?? sub.downloadBytes,
          totalBytes: totalBytes ?? sub.totalBytes,
          expireDate: expireDate ?? sub.expireDate,
        );
        state = [...state];
        _save();
        return tagged.length;
      }
    } catch (_) {}
    return 0;
  }

  /// Sequentially updates all active subscriptions.
  Future<void> updateAll() async {
    for (final s in state) {
      await updateSubscription(s.id);
    }
  }

  /// Updates the recorded node count for a subscription.
  void updateNodeCount(String subId, int newCount) {
    final idx = state.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      state[idx] = state[idx].copyWith(nodeCount: newCount);
      state = [...state];
      _save();
    }
  }
}

/// Riverpod provider for subscription link state.
final subscriptionsProvider = StateNotifierProvider<SubscriptionsNotifier, List<SubscriptionItem>>((ref) {
  return SubscriptionsNotifier(ref);
});
