// CDN IP Scanner Management Provider
// Manages and monitors clean CDN IP scanning operations in radar and targeted modes.
// Discovered low-latency IPs can be automatically applied to active node with reconnection.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import '../services/cdn_scanner_service.dart';
import '../services/cloudflare_scanner_service.dart';
import '../services/log_service.dart';
import 'cdn_ranges_provider.dart';
import 'connection_provider.dart';
import 'nodes_provider.dart';
import 'scanner_state.dart';
import 'scanner_tasks.dart';

export 'scanner_state.dart';
export 'cdn_ranges_provider.dart';

/// Manages clean IP scanning operations.
/// Uses concurrent workers to measure latency across multiple IP addresses.
class ScannerNotifier extends StateNotifier<ScannerState> {
  final Ref ref;
  bool _isCancelled = false;
  bool _hasWarnedRadarTraffic = false;

  /// Checks whether the scan has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Indicates whether radar traffic warning was dispatched.
  bool get hasWarnedRadarTraffic => _hasWarnedRadarTraffic;

  /// Sets radar traffic warning state.
  void setWarnedRadarTraffic(bool v) => _hasWarnedRadarTraffic = v;

  /// Gets the current snapshot of scanner state.
  ScannerState get currentState => state;

  /// Updates state using a state transformation function.
  void updateState(ScannerState Function(ScannerState) updater) {
    state = updater(state);
  }

  /// Initializes the scanner notifier.
  ScannerNotifier(this.ref) : super(ScannerState());

  /// Updates the target CDN provider.
  void setSelectedCdn(CdnProvider cdn) {
    if (state.isScanning) return;
    state = state.copyWith(selectedCdn: cdn);
  }

  /// Changes scan strategy between radar and targeted.
  void setStrategy(ScannerStrategy strategy) {
    if (state.isScanning) return;
    state = state.copyWith(strategy: strategy);
  }

  /// Sets concurrent worker/thread count for scanning.
  void setWorkers(int workers) {
    if (state.isScanning) return;
    state = state.copyWith(workers: workers.clamp(5, 100));
  }

  void setThreshold(int threshold) => setWorkers(threshold);

  /// Sets target total candidate count in targeted scanning.
  void setTargetTotalCandidates(int total) {
    if (state.isScanning) return;
    state = state.copyWith(targetTotalCandidates: total.clamp(200, 10000));
  }

  /// Halts and cancels the running scan process.
  void cancelScan() {
    _isCancelled = true;
    CloudflareScannerService.instance.cancel();
    state = state.copyWith(
      isScanning: false,
      statusMessage: "Stopped",
      showRadarTrafficWarning: false,
    );
  }

  /// Dismisses the radar mode traffic warning.
  void dismissRadarWarning() {
    state = state.copyWith(showRadarTrafficWarning: false);
  }

  /// Resets all scanner results and state variables.
  void resetScan() {
    _hasWarnedRadarTraffic = false;
    if (state.isScanning) {
      cancelScan();
    }
    state = ScannerState(
      strategy: state.strategy,
      selectedCdn: state.selectedCdn,
      workers: state.workers,
      targetTotalCandidates: state.targetTotalCandidates,
      isScanning: false,
      total: 0,
      scanned: 0,
      currentIp: "",
      results: [],
      bestIp: null,
      connectedIp: null,
      currentBestLatency: null,
      radarLogs: [],
      statusMessage: null,
      radarHealthyCount: 0,
      showRadarTrafficWarning: false,
    );
  }

  /// Starts clean IP scan based on selected strategy (radar or target).
  Future<void> startScan() async {
    if (state.isScanning) return;
    final nodes = ref.read(nodesProvider);
    if (nodes.isEmpty) return;
    final activeNode = nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);

    final cdn = state.selectedCdn;
    final allRanges = ref.read(cdnRangesProvider);
    final customCidrs = allRanges[cdn] ?? cdn.defaultCidrs;

    final origAddress = activeNode.originalAddress ?? activeNode.address;
    final isDomain = !origAddress.contains(RegExp(r'^\d+\.\d+\.\d+\.\d+$'));

    _isCancelled = false;
    _hasWarnedRadarTraffic = false;
    final strategy = state.strategy;
    final workers = state.workers;

    if (strategy == ScannerStrategy.radar) {
      await RadarScannerTask(ref: ref, notifier: this).run(
        activeNode: activeNode,
        cdn: cdn,
        customCidrs: customCidrs,
        origAddress: origAddress,
        isDomain: isDomain,
        workers: workers,
      );
    } else {
      await TargetScannerTask(ref: ref, notifier: this).run(
        activeNode: activeNode,
        cdn: cdn,
        customCidrs: customCidrs,
        origAddress: origAddress,
        isDomain: isDomain,
        workers: workers,
      );
    }
  }

  /// Applies selected IP to active proxy node and reconnects.
  Future<void> connectToCandidateIp(String ip, int latencyMs) async {
    final nodes = ref.read(nodesProvider);
    if (nodes.isEmpty) return;
    final activeNode = nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);

    LogService.instance.add(
      "[Scanner] Connecting to selected IP: $ip (${latencyMs}ms)...",
      level: LogLevel.info,
      source: "scanner",
    );
    final scanMatch = state.results.where((r) => r.ip == ip).firstOrNull;
    final countryCode = scanMatch?.countryCode;
    final countryName = scanMatch?.country;

    ref.read(nodesProvider.notifier).applyIp(
      activeNode.id,
      ip,
      latencyMs: latencyMs,
      countryCode: countryCode,
      country: countryName,
    );
    state = state.copyWith(connectedIp: ip);
    await ref.read(connectionStatusProvider.notifier).reconnect();
  }

  Future<void> connectToTargetIp(String ip, int latencyMs) =>
      connectToCandidateIp(ip, latencyMs);
}

/// Riverpod provider for Cloudflare/CDN IP scanner state.
final scannerProvider = StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  return ScannerNotifier(ref);
});
