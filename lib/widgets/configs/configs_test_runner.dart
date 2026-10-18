// File: lib/widgets/configs/configs_test_runner.dart
// Description: Batch and single ping latency test execution runner for configs on Android.
// Supports parallel testing, remaining time estimation, database updating, and cancellation.
// Extracted to reduce widget code size and improve application stability and readability.

import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../services/country_service.dart';
import '../../services/real_delay_service.dart';
import '../../services/storage_service.dart';
import '../../services/xray_process_service.dart';

/// Runner class for real delay ping testing of custom proxy configurations.
///
/// Executes batch real-delay requests, intelligently estimates
/// completion ETA, and records final latency results in the app state.
class ConfigsTestRunner {
  /// Executes real delay test for a single node and updates app state.
  static Future<void> testSingleNode(WidgetRef ref, ProxyNode node) async {
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

  /// Executes batch ping tests in chunks of 10 with cancellation support.
  static Future<void> testAllNodes({
    required WidgetRef ref,
    required List<ProxyNode> nodes,
    required bool Function() isCancelled,
    required void Function(int tested, String? eta) onProgress,
  }) async {
    if (nodes.isEmpty) return;

    if (XrayProcessService.instance.core.androidBinaryPath == null) {
      await XrayProcessService.instance.initAndroid();
    }

    ref.read(nodesProvider.notifier).clearLatencies(onlyCustom: true);

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
        if (nextIndex >= nodes.length) break;
        idx = nextIndex++;

        final n = nodes[idx];
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

        testedCount++;
        String? eta;
        if (nodes.length > 10 && testedCount > 0 && testedCount < nodes.length) {
          final elapsed = DateTime.now().difference(testStartTime);
          final avgPerNode = elapsed.inMilliseconds / testedCount;
          final remainingMs = (avgPerNode * (nodes.length - testedCount)).round();
          final remSeconds = (remainingMs / 1000).round();
          final minutes = remSeconds ~/ 60;
          final seconds = remSeconds % 60;
          eta = '~${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }

        onProgress(testedCount, eta);
      }
    }

    final workerCount = math.min(concurrency, nodes.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    final currentNodes = ref.read(nodesProvider);
    StorageService.instance.saveNodes(currentNodes, immediate: true);
  }
}
