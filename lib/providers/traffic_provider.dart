// Traffic Statistics & Connection Timestamp Providers
// Manages traffic statistics (uplink and downlink) and connection timestamps.
// Traffic metrics are periodically updated via Xray Core streams and recorded in session storage.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/traffic_stats.dart';
import '../services/storage_service.dart';
import '../services/xray_process_service.dart';

/// Exact timestamp when proxy connection was established, used for session duration calculation.
final connectedAtProvider = StateProvider<DateTime?>((ref) => null);

/// Manages network traffic statistics.
/// Handles persistence, restoration, and real-time updates for uplink and downlink byte counts.
class TrafficStatsNotifier extends StateNotifier<TrafficStats> {
  StreamSubscription<TrafficStats>? _sub;
  DateTime? _lastSaveTime;
  int _baselineUplink = 0;
  int _baselineDownlink = 0;

  /// Initializes the traffic stats notifier and subscribes to live core traffic streams.
  TrafficStatsNotifier() : super(const TrafficStats()) {
    _sub = XrayProcessService.instance.trafficStream.listen((stats) {
      final totalUp = _baselineUplink + stats.uplinkBytes;
      final totalDown = _baselineDownlink + stats.downlinkBytes;
      state = TrafficStats(uplinkBytes: totalUp, downlinkBytes: totalDown);
      final now = DateTime.now();
      if (_lastSaveTime == null || now.difference(_lastSaveTime!).inSeconds >= 3) {
        _lastSaveTime = now;
        StorageService.instance.updateActiveSessionTraffic(totalUp, totalDown);
      }
    });
  }

  /// Restores baseline statistics from a previous session upon Android service restarts.
  void restoreBaseline(int up, int down) {
    _baselineUplink = up;
    _baselineDownlink = down;
    state = TrafficStats(uplinkBytes: up, downlinkBytes: down);
  }

  /// Manually updates traffic statistics.
  void update(TrafficStats stats) {
    state = stats;
  }

  /// Resets all traffic counters to zero upon disconnect.
  void reset() {
    _baselineUplink = 0;
    _baselineDownlink = 0;
    state = const TrafficStats();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for real-time application traffic statistics.
final trafficStatsProvider = StateNotifierProvider<TrafficStatsNotifier, TrafficStats>((ref) {
  return TrafficStatsNotifier();
});
