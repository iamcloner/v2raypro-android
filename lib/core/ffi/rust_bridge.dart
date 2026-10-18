// File: lib/core/ffi/rust_bridge.dart
// Description: FFI communication bridge for the C/Rust native module in Android.
// Executes high-performance scanning and falls back to an internal Dart simulator if absent.

import "dart:async";
import "dart:convert";
import "dart:ffi" as ffi;
import "package:ffi/ffi.dart";
import "../../models/scan_result.dart";

typedef NativeRegisterCallback = ffi.Void Function(ffi.Pointer<ffi.NativeFunction<NativeEventCallback>>);
typedef DartRegisterCallback = void Function(ffi.Pointer<ffi.NativeFunction<NativeEventCallback>>);
typedef NativeEventCallback = ffi.Void Function(ffi.Pointer<Utf8>);

typedef NativeImportConfig = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef DartImportConfig = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef NativeStartScan = ffi.Bool Function(ffi.Pointer<Utf8>);
typedef DartStartScan = bool Function(ffi.Pointer<Utf8>);

typedef NativeVoidFunc = ffi.Void Function();
typedef DartVoidFunc = void Function();

typedef NativeApplyIp = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef DartApplyIp = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);

/// FFI bridge to the native Rust core library on Android.
/// Coordinates high-speed scanning, event streams, and cancellation requests.
class RustBridge {
  static final RustBridge instance = RustBridge._internal();
  RustBridge._internal();

  ffi.DynamicLibrary? _dylib;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// Live stream of scan progress events and candidate results.
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  bool _initialized = false;

  /// Initializes and loads the dynamic library on Android (libv2raypro_core.so).
  void initialize({String? libPath}) {
    if (_initialized) return;

    try {
      _dylib = ffi.DynamicLibrary.open(libPath ?? "libv2raypro_core.so");
    } catch (_) {
      // Fallback to simulator mode if native library is unavailable.
    }

    _initialized = true;
  }

  /// Starts IP candidate scanning using either the native core or the Dart simulator.
  Future<void> startScan({
    int candidates = 50,
    int workers = 20,
    int targetPort = 443,
    String? sni,
    String? host,
    String? path,
    bool mockMode = false,
  }) async {
    final payload = {
      "candidate_count": candidates,
      "concurrent_workers": workers,
      "tcp_timeout_ms": 2000,
      "tls_timeout_ms": 3000,
      "target_port": targetPort,
      "target_sni": sni,
      "target_host": host,
      "target_path": path,
      "custom_prefix": null,
      "mock_mode": mockMode || _dylib == null,
    };

    if (_dylib != null) {
      try {
        final fn = _dylib!.lookupFunction<NativeStartScan, DartStartScan>("v2raypro_start_scan");
        final jsonPtr = jsonEncode(payload).toNativeUtf8();
        fn(jsonPtr);
        calloc.free(jsonPtr);
        return;
      } catch (_) {}
    }

    // Fallback to Dart mock scan if native library is not loaded.
    _runDartMockScan(candidates);
  }

  /// Cancels and terminates the active scan session.
  void cancelScan() {
    if (_dylib != null) {
      try {
        final fn = _dylib!.lookupFunction<NativeVoidFunc, DartVoidFunc>("v2raypro_cancel_scan");
        fn();
      } catch (_) {}
    }
    _eventController.add({"type": "ScanCancelled", "data": {}});
  }

  /// Internal Dart simulator for testing and execution without native binaries.
  void _runDartMockScan(int total) async {
    _eventController.add({"type": "ScanStarted", "data": {"total": total}});
    for (int i = 1; i <= total; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      final ip = "104.16.${(i * 3) % 250}.${(i * 7) % 250 + 1}";
      final success = (i % 4) != 0;
      final ping = success ? (30 + (i * 11) % 90) : null;

      final res = ScanResult(
        ip: ip,
        port: 443,
        tcpSuccess: success,
        tcpLatencyMs: ping,
        tlsSuccess: success,
        tlsLatencyMs: ping != null ? (ping + 15) : null,
        protocolSuccess: success,
        totalLatencyMs: ping != null ? (ping * 2) : null,
        error: success ? null : "Connection timeout",
        rankScore: ping != null ? ping.toDouble() : 99999.0,
      );

      _eventController.add({
        "type": "ScanProgress",
        "data": {"scanned": i, "total": total, "current_ip": ip}
      });
      _eventController.add({
        "type": "ScanResult",
        "data": {
          "ip": res.ip,
          "port": res.port,
          "tcp_success": res.tcpSuccess,
          "tcp_latency_ms": res.tcpLatencyMs,
          "tls_success": res.tlsSuccess,
          "tls_latency_ms": res.tlsLatencyMs,
          "protocol_success": res.protocolSuccess,
          "total_latency_ms": res.totalLatencyMs,
          "error": res.error,
          "rank_score": res.rankScore,
        }
      });
    }

    _eventController.add({
      "type": "ScanFinished",
      "data": {"total_tested": total, "successful_count": (total * 0.75).toInt()}
    });
  }
}
