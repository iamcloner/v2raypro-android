import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "../models/log_entry.dart";

export "../models/log_entry.dart";

class LogService {
  static final LogService instance = LogService._();
  LogService._();

  static const int maxCapacity = 1000;
  final List<LogEntry> _entries = [];
  final StreamController<LogEntry> _controller = StreamController<LogEntry>.broadcast();
  Timer? _saveDebounceTimer;
  File? _logFile;
  bool _initialized = false;

  Stream<LogEntry> get onNewLog => _controller.stream;
  List<LogEntry> get logs => List<LogEntry>.from(_entries);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File("${dir.path}/v2raypro_logs.json");
      if (await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        if (content.isNotEmpty) {
          final list = jsonDecode(content) as List;
          final loaded = list
              .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          _entries.clear();
          _entries.addAll(loaded);
        }
      }
    } catch (_) {}
  }

  void add(String message, {LogLevel level = LogLevel.info, String source = "system"}) {
    if (message.trim().isEmpty) return;
    final entry = LogEntry(
      message: message.trim(),
      level: level,
      source: source,
      timestamp: DateTime.now(),
    );
    _append(entry);
  }

  void addFromRawLine(String rawLine, {String source = "xray"}) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) return;
    final level = LogEntry.parseLevel(trimmed);
    final entry = LogEntry(
      message: trimmed,
      level: level,
      source: source,
      timestamp: DateTime.now(),
    );
    _append(entry);
  }

  void _append(LogEntry entry) {
    if (_entries.length >= maxCapacity) {
      _entries.removeRange(0, _entries.length - maxCapacity + 1);
    }
    _entries.add(entry);
    _controller.add(entry);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      try {
        if (_logFile == null) {
          final dir = await getApplicationSupportDirectory();
          _logFile = File("${dir.path}/v2raypro_logs.json");
        }
        final toSave = _entries.length > 500
            ? _entries.sublist(_entries.length - 500)
            : _entries;
        final jsonList = toSave.map((e) => e.toJson()).toList();
        await _logFile!.writeAsString(jsonEncode(jsonList));
      } catch (_) {}
    });
  }

  Future<void> clear() async {
    _entries.clear();
    _saveDebounceTimer?.cancel();
    if (Platform.isAndroid) {
      try {
        const MethodChannel('com.v2raypro.app/native').invokeMethod('clearVpnLogs');
      } catch (_) {}
    }
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
      }
    } catch (_) {}
  }
}
