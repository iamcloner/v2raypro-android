// Scanner State Models and Strategy Definitions
// Defines state models and radar log entries for the Cloudflare/CDN clean IP scanner.
// Covers radar (continuous monitoring) and target (fixed range scanning) strategies.

import '../models/scan_result.dart';
import '../services/cdn_scanner_service.dart';

/// Clean IP scanning strategy for CDN providers.
enum ScannerStrategy {
  /// Real-time continuous monitoring and auto-switching to lowest latency IP.
  radar,
  /// Scans a fixed number of candidate IPs and sorts by responsiveness.
  target,
}

/// Log entry structure for newly discovered IPs in radar scanner mode.
class RadarLogEntry {
  /// Discovered IP address.
  final String ip;
  /// Round-trip latency in milliseconds.
  final int latencyMs;
  /// Timestamp when the IP was discovered.
  final DateTime timestamp;
  /// Latency improvement compared to previous best IP in milliseconds.
  final int? improvementMs;

  /// Creates a new radar log entry.
  RadarLogEntry({
    required this.ip,
    required this.latencyMs,
    required this.timestamp,
    this.improvementMs,
  });
}

/// Comprehensive state model for clean IP scanner.
class ScannerState {
  /// Indicates whether a scan is currently active.
  final bool isScanning;
  /// Selected scan strategy (radar or target).
  final ScannerStrategy strategy;
  /// Target CDN provider (e.g. Cloudflare).
  final CdnProvider selectedCdn;
  /// Number of concurrent scan workers/threads (between 5 and 100).
  final int workers;
  /// Target candidate count for target scan mode.
  final int targetTotalCandidates;
  /// Total IP count designated for the current scan.
  final int total;
  /// Number of candidate IPs scanned so far.
  final int scanned;
  /// Latest IP currently undergoing testing.
  final String currentIp;
  /// Successful scan results.
  final List<ScanResult> results;
  /// Best discovered IP with the lowest latency.
  final ScanResult? bestIp;
  /// IP currently utilized as active proxy address.
  final String? connectedIp;
  /// Best recorded latency so far.
  final int? currentBestLatency;
  /// History of improved IPs recorded in radar mode.
  final List<RadarLogEntry> radarLogs;
  /// Current status message for UI presentation.
  final String? statusMessage;
  /// Total count of healthy IPs discovered in radar mode.
  final int radarHealthyCount;
  /// Displays data usage warning if radar runs continuously.
  final bool showRadarTrafficWarning;
  /// Estimated remaining time until scan completion.
  final String? estimatedRemainingTime;

  /// Backward compatibility alias mapping threshold to workers.
  int get threshold => workers;

  /// Initializes scanner state with default values.
  ScannerState({
    this.isScanning = false,
    this.strategy = ScannerStrategy.radar,
    this.selectedCdn = CdnProvider.cloudflare,
    int? workers,
    int? threshold,
    this.targetTotalCandidates = 500,
    this.total = 0,
    this.scanned = 0,
    this.currentIp = "",
    this.results = const [],
    this.bestIp,
    this.connectedIp,
    this.currentBestLatency,
    this.radarLogs = const [],
    this.statusMessage,
    this.radarHealthyCount = 0,
    this.showRadarTrafficWarning = false,
    this.estimatedRemainingTime,
  }) : workers = (workers ?? threshold ?? 25).clamp(5, 100);

  /// Creates a copy of scanner state with updated fields.
  ScannerState copyWith({
    bool? isScanning,
    ScannerStrategy? strategy,
    CdnProvider? selectedCdn,
    int? workers,
    int? threshold,
    int? targetTotalCandidates,
    int? total,
    int? scanned,
    String? currentIp,
    List<ScanResult>? results,
    ScanResult? bestIp,
    String? connectedIp,
    int? currentBestLatency,
    List<RadarLogEntry>? radarLogs,
    String? statusMessage,
    int? radarHealthyCount,
    bool? showRadarTrafficWarning,
    String? estimatedRemainingTime,
  }) {
    return ScannerState(
      isScanning: isScanning ?? this.isScanning,
      strategy: strategy ?? this.strategy,
      selectedCdn: selectedCdn ?? this.selectedCdn,
      workers: workers ?? threshold ?? this.workers,
      targetTotalCandidates: targetTotalCandidates ?? this.targetTotalCandidates,
      total: total ?? this.total,
      scanned: scanned ?? this.scanned,
      currentIp: currentIp ?? this.currentIp,
      results: results ?? this.results,
      bestIp: bestIp ?? this.bestIp,
      connectedIp: connectedIp ?? this.connectedIp,
      currentBestLatency: currentBestLatency ?? this.currentBestLatency,
      radarLogs: radarLogs ?? this.radarLogs,
      statusMessage: statusMessage ?? this.statusMessage,
      radarHealthyCount: radarHealthyCount ?? this.radarHealthyCount,
      showRadarTrafficWarning: showRadarTrafficWarning ?? this.showRadarTrafficWarning,
      estimatedRemainingTime: estimatedRemainingTime ?? this.estimatedRemainingTime,
    );
  }
}
