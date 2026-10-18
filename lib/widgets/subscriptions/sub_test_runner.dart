// Subscriptions Latency & Node Maintenance Runner
// Encapsulates batch latency testing for subscription proxy nodes,
// individual ping measurements, and cleanup of dead or unresponsive configurations.
// Optimized for concurrency and battery efficiency on Android.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../models/proxy_node.dart';
import '../../models/subscription_item.dart';
import '../../providers/app_providers.dart';
import '../../services/country_service.dart';
import '../../services/real_delay_service.dart';
import '../../services/storage_service.dart';
import '../../services/xray_process_service.dart';

/// Test runner class for measuring latency and maintaining subscription proxy nodes.
/// Handles individual testing, batch parallel testing, and removal of timed-out nodes.
class SubTestRunner {
  /// Measures real latency for a node via the Xray core and updates the provider state.
  static Future<void> testNodeLatency({
    required WidgetRef ref,
    required ProxyNode node,
  }) async {
    if (XrayProcessService.instance.core.androidBinaryPath == null) {
      await XrayProcessService.instance.initAndroid();
    }
    final testMode = ref.read(testModeProvider);
    final res = await testRealDelay(
      mode: testMode == TestMode.turbo ? 'turbo' : 'normal',
      type: 'xray',
      config: node.toJson(),
    );
    ref.read(nodesProvider.notifier).updateLatency(
      node.id,
      res.ping,
      countryCode: res.country?.toUpperCase() ?? node.countryCode ?? CountryService.resolveSync(node),
      country: res.countryName ?? (res.country != null ? CountryService.getCountryName(res.country!.toUpperCase()) : node.country),
    );
  }

  /// Batch tests all configurations of a subscription concurrently.
  /// Reports testing progress and estimated time remaining (ETA) via callback.
  static Future<void> testAllSubNodes({
    required WidgetRef ref,
    required SubscriptionItem sub,
    required List<ProxyNode> subNodes,
    required bool Function() isCancelled,
    required void Function(int tested, String? eta) onProgress,
    required void Function(String nodeId) onNodeTestingDone,
  }) async {
    final subId = sub.id;
    if (subNodes.isEmpty) return;

    if (XrayProcessService.instance.core.androidBinaryPath == null) {
      await XrayProcessService.instance.initAndroid();
    }

    ref.read(nodesProvider.notifier).clearLatencies(subscriptionId: subId);

    final concurrency = ref.read(testConcurrencyProvider).clamp(1, 100);
    final testStartTime = DateTime.now();
    final testMode = ref.read(testModeProvider);
    final modeStr = testMode == TestMode.turbo ? 'turbo' : 'normal';

    int nextIndex = 0;
    int testedCount = 0;

    Future<void> worker() async {
      while (true) {
        if (isCancelled()) break;
        int idx;
        if (nextIndex >= subNodes.length) break;
        idx = nextIndex++;

        final n = subNodes[idx];
        final res = await testRealDelay(
          mode: modeStr,
          type: 'xray',
          config: n.toJson(),
        );

        if (isCancelled()) break;

        final lat = res.isSuccess ? res.ping : -1;
        final cCode = res.country?.toUpperCase() ?? n.countryCode ?? CountryService.resolveSync(n);
        final cName = res.countryName ?? (cCode != null ? CountryService.getCountryName(cCode) : n.country);

        ref.read(nodesProvider.notifier).updateLatency(
          n.id,
          lat,
          countryCode: cCode,
          country: cName,
        );
        onNodeTestingDone(n.id);

        testedCount++;
        String? eta;
        if (subNodes.length > 10 && testedCount > 0 && testedCount < subNodes.length) {
          final elapsed = DateTime.now().difference(testStartTime);
          final avgPerNode = elapsed.inMilliseconds / testedCount;
          final remainingMs = (avgPerNode * (subNodes.length - testedCount)).round();
          final remSeconds = (remainingMs / 1000).round();
          final minutes = remSeconds ~/ 60;
          final seconds = remSeconds % 60;
          eta = '~${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }

        onProgress(testedCount, eta);
      }
    }

    final workerCount = math.min(concurrency, subNodes.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    // Immediately persist test results and resolved countries to disk storage
    final updatedNodes = ref.read(nodesProvider);
    StorageService.instance.saveNodes(updatedNodes, immediate: true);
  }

  /// Identifies and removes timed-out configurations within a subscription upon confirmation.
  static Future<void> deleteDeadSubNodes({
    required BuildContext context,
    required WidgetRef ref,
    required SubscriptionItem sub,
    required List<ProxyNode> subNodes,
    required String locale,
  }) async {
    final deadNodes = subNodes.where((n) => n.hasTimedOut).toList();
    if (deadNodes.isEmpty) {
      final untestedCount = subNodes.where((n) => n.isUntested).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            untestedCount > 0
                ? (locale == 'fa'
                    ? 'ابتدا با دکمه «تست پینگ همه» کانفیگ‌های این ساب را بررسی کنید تا بی‌پاسخ‌ها مشخص شوند.'
                    : 'Run "Test All Ping" first to check and mark timed-out configs in this subscription.')
                : AppStrings.get('delete_dead_none', locale: locale),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text("${sub.name}: ${AppStrings.get('confirm_delete_dead_title', locale: locale)}")),
          ],
        ),
        content: Text(
          AppStrings.get('confirm_delete_dead_msg', locale: locale)
              .replaceAll('{count}', deadNodes.length.toString()),
        ),
        actions: [
          TextButton(
            child: Text(AppStrings.get('cancel_scan', locale: locale)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppStrings.get('delete_dead_configs', locale: locale)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final removed = ref.read(nodesProvider.notifier).removeDeadNodes(subscriptionId: sub.id);
      final remaining = subNodes.length - removed;
      ref.read(subscriptionsProvider.notifier).updateNodeCount(sub.id, remaining >= 0 ? remaining : 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${sub.name}: ${AppStrings.get('delete_dead_success', locale: locale).replaceAll('{count}', removed.toString())}",
          ),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    }
  }
}
