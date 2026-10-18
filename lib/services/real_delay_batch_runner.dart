// =======================================================================
// [File Name]: real_delay_batch_runner.dart
// [Description]: Batch and parallel execution runner for proxy real delay tests on Android.
// Divides input configurations into chunks of 25 while optimizing processing load
// on Android devices and aggregating latency test results.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:math" as math;
import "../models/log_entry.dart";
import "../models/proxy_node.dart";
import "../models/real_delay_result.dart";
import "log_service.dart";

/// Batch evaluation runner for proxy node latency on Android.
class RealDelayBatchRunner {
  /// Records node latency test results to system logger with warning level for diagnostic tracking.
  static void logResult(ProxyNode? node, RealDelayResult res) {
    final header = node != null && node.name.isNotEmpty
        ? "[Real Delay Test] ${node.name}"
        : "[Real Delay Test]";
    final message = "$header:\n$res";
    LogService.instance.add(
      message,
      level: LogLevel.warning,
      source: "test",
    );
  }

  /// Executes parallel latency testing for a list of nodes using an async worker pool.
  /// As soon as a worker finishes testing one node, it immediately picks the next.
  static Future<Map<String, RealDelayResult>> runBatch({
    required List<ProxyNode> nodes,
    required Duration effectiveTimeout,
    required bool isTurbo,
    int? concurrency,
    required Future<RealDelayResult> Function(ProxyNode node, Duration timeout, bool isTurbo) testSingleNode,
  }) async {
    final results = <String, RealDelayResult>{};
    if (nodes.isEmpty) return results;

    final poolSize = (concurrency != null && concurrency > 0) ? concurrency : 25;
    final workerCount = math.min(poolSize, nodes.length);
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= nodes.length) break;
        final idx = nextIndex++;
        final n = nodes[idx];
        final singleRes = await testSingleNode(n, effectiveTimeout, isTurbo);
        logResult(n, singleRes);
        results[n.id] = singleRes;
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }
}
