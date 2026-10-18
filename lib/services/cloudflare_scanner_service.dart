// Cloudflare Scanner Service
// Tests candidate Cloudflare edge IPs for TCP latency, TLS handshakes, and download speed.
// Identifies clean IP addresses for bypassing SNI filtering and CDN circumvention.
// Optimized for concurrency, timeout handling, and cancellation on Android.

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "../models/scan_result.dart";
import "cloudflare_cidr_util.dart";

export "cloudflare_cidr_util.dart";

/// Scanning and validation service for clean Cloudflare edge IPs on Android.
/// Evaluates TCP socket latency, TLS handshakes, and test download throughput.
class CloudflareScannerService {
  static final CloudflareScannerService instance = CloudflareScannerService._internal();
  CloudflareScannerService._internal();

  static const List<String> defaultCidrs = CloudflareCidrUtil.defaultCidrs;
  static const List<String> cfSubnets = CloudflareCidrUtil.cfSubnets;

  static String sampleIpFromCidr(String cidr, Random rng) => CloudflareCidrUtil.sampleIpFromCidr(cidr, rng);
  static bool isCloudflareIp(String ip, [List<String>? cidrs]) => CloudflareCidrUtil.isCloudflareIp(ip, cidrs);
  static bool isCloudflareHostSync(String host, [List<String>? cidrs]) => CloudflareCidrUtil.isCloudflareHostSync(host, cidrs);
  static Future<bool> resolveAndCheckCloudflare(String host, [List<String>? cidrs]) => CloudflareCidrUtil.resolveAndCheckCloudflare(host, cidrs);
  static List<String> generateCandidateIps({required int count, List<String>? cidrs, Random? rng}) =>
      CloudflareCidrUtil.generateCandidateIps(count: count, cidrs: cidrs, rng: rng);

  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }

  /// Perform a real network probe (TCP Socket connect + TLS handshake + live origin response)
  Future<ScanResult> testRealIp({
    required String ip,
    required int port,
    String? sni,
    String? host,
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: timeout);
      final tcpMs = sw.elapsedMilliseconds;

      int? tlsMs;
      bool tlsSuccess = false;
      Socket activeSocket = socket;

      if (port == 443 || sni != null) {
        final tlsSw = Stopwatch()..start();
        final secureSocket = await SecureSocket.secure(
          socket,
          host: sni ?? "cloudflare.com",
          onBadCertificate: (cert) => true,
        ).timeout(timeout);
        tlsMs = tlsSw.elapsedMilliseconds;
        tlsSuccess = true;
        activeSocket = secureSocket;
      }

      // Perform real HTTP / WebSocket upgrade probe to verify live origin reachability
      final targetHost = host ?? sni ?? "cloudflare.com";
      final httpRequest =
          'GET / HTTP/1.1\r\n'
          'Host: $targetHost\r\n'
          'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n'
          'Upgrade: websocket\r\n'
          'Connection: Upgrade\r\n'
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
          'Sec-WebSocket-Version: 13\r\n'
          '\r\n';

      activeSocket.add(utf8.encode(httpRequest));
      await activeSocket.flush();

      final completer = Completer<bool>();
      final sub = activeSocket.listen(
        (data) {
          if (!completer.isCompleted) {
            final res = utf8.decode(data, allowMalformed: true);
            final firstLine = res.split('\r\n').first;
            final isGood = firstLine.contains('101') ||
                firstLine.contains('400') ||
                firstLine.contains('200') ||
                firstLine.contains('204');
            final isBad = res.contains('502') ||
                res.contains('503') ||
                res.contains('504') ||
                res.contains('520') ||
                res.contains('521') ||
                res.contains('522') ||
                res.contains('523') ||
                res.contains('524') ||
                res.contains('525') ||
                res.contains('526') ||
                res.contains('530') ||
                res.contains('403') ||
                res.contains('Error 1000') ||
                res.contains('Error 1005');

            completer.complete(isGood && !isBad);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      final protocolOk = await completer.future.timeout(timeout, onTimeout: () => false);
      await sub.cancel();
      sw.stop();
      activeSocket.destroy();

      if (!protocolOk) {
        return ScanResult(
          ip: ip,
          port: port,
          tcpSuccess: true,
          tcpLatencyMs: tcpMs,
          tlsSuccess: tlsSuccess,
          tlsLatencyMs: tlsMs,
          protocolSuccess: false,
          error: "Origin unreachable (CDN 5xx / 403)",
          rankScore: 99999.0,
        );
      }

      final totalMs = sw.elapsedMilliseconds;
      return ScanResult(
        ip: ip,
        port: port,
        tcpSuccess: true,
        tcpLatencyMs: tcpMs,
        tlsSuccess: tlsSuccess,
        tlsLatencyMs: tlsMs,
        protocolSuccess: true,
        totalLatencyMs: totalMs,
        rankScore: totalMs.toDouble(),
      );
    } catch (e) {
      sw.stop();
      try {
        socket?.destroy();
      } catch (_) {}
      return ScanResult(
        ip: ip,
        port: port,
        tcpSuccess: false,
        tlsSuccess: false,
        protocolSuccess: false,
        error: e.toString().contains("timed out") ? "Timeout" : "Connection failed",
        rankScore: 99999.0,
      );
    }
  }

  Stream<Map<String, dynamic>> scanCandidates({
    required int candidateCount,
    required int workers,
    required int targetPort,
    String? targetSni,
    List<String>? customCidrs,
  }) async* {
    _isCancelled = false;
    final rng = Random();

    // 1. Generate real IP candidates across Cloudflare subnets or custom CIDRs
    final ranges = (customCidrs != null && customCidrs.isNotEmpty) ? customCidrs : defaultCidrs;
    final candidates = <String>[];
    for (int i = 0; i < candidateCount; i++) {
      final cidr = ranges[rng.nextInt(ranges.length)];
      final ip = sampleIpFromCidr(cidr, rng);
      candidates.add(ip);
    }

    yield {"type": "ScanStarted", "data": {"total": candidates.length}};

    int scanned = 0;
    int successCount = 0;
    ScanResult? best;

    // Process concurrently in chunks matching worker count
    for (int i = 0; i < candidates.length; i += workers) {
      if (_isCancelled) {
        yield {"type": "ScanCancelled", "data": {}};
        return;
      }

      final chunk = candidates.sublist(i, min(i + workers, candidates.length));
      final futures = chunk.map((ip) => testRealIp(
        ip: ip,
        port: targetPort,
        sni: targetSni,
      ));

      final results = await Future.wait(futures);

      for (final res in results) {
        scanned++;
        if (res.tcpSuccess && res.tlsSuccess) {
          successCount++;
          if (best == null || res.rankScore < best.rankScore) {
            best = res;
          }
        }

        yield {
          "type": "ScanProgress",
          "data": {"scanned": scanned, "total": candidates.length, "current_ip": res.ip}
        };

        yield {
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
        };
      }
    }

    yield {
      "type": "ScanFinished",
      "data": {
        "total_tested": scanned,
        "successful_count": successCount,
        "best_ip": best != null ? {
          "ip": best.ip,
          "port": best.port,
          "tcp_success": best.tcpSuccess,
          "tcp_latency_ms": best.tcpLatencyMs,
          "tls_success": best.tlsSuccess,
          "tls_latency_ms": best.tlsLatencyMs,
          "protocol_success": best.protocolSuccess,
          "total_latency_ms": best.totalLatencyMs,
          "error": best.error,
          "rank_score": best.rankScore,
        } : null,
      }
    };
  }
}
