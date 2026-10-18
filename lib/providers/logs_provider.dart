// Logging State Provider
// Connects the UI layer to system and core logging services.
// Subscribes to live log streams and exposes them as a displayable list.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';

/// Manages application log state.
/// Collects and manages logs from Xray Core and internal services.
class LogsNotifier extends StateNotifier<List<LogEntry>> {
  StreamSubscription<LogEntry>? _sub;

  /// Initializes state and subscribes to incoming log events.
  LogsNotifier() : super(LogService.instance.logs) {
    _sub = LogService.instance.onNewLog.listen((_) {
      state = LogService.instance.logs;
    });
  }

  /// Appends a new log entry with the specified log level and source.
  void add(String message, {LogLevel level = LogLevel.info, String source = "system"}) {
    LogService.instance.add(message, level: level, source: source);
  }

  /// Clears the entire log history.
  void clear() {
    LogService.instance.clear();
    state = [];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for accessing application logs across UI components.
final logsProvider = StateNotifierProvider<LogsNotifier, List<LogEntry>>((ref) {
  return LogsNotifier();
});
