// File: lib/models/node_test_result.dart
// Description: Data model holding latency test results, exit IP, and country info for nodes.
// Includes helper methods for parsing Cloudflare trace endpoints and converting ping results.

import "service_models.dart";

/// Latency test and real delay measurement model for proxy nodes.
/// Holds round-trip delay, country code, country name, and outbound exit IP.
class NodeTestResult {
  /// Round-trip time latency in milliseconds.
  final int? latencyMs;

  /// Two-letter ISO 3166-1 alpha-2 country code of the node exit location.
  final String? countryCode;

  /// Country name in English or localized format.
  final String? country;

  /// Public outbound exit IP address of the server.
  final String? exitIp;

  /// Creates a node test result instance.
  const NodeTestResult({
    this.latencyMs,
    this.countryCode,
    this.country,
    this.exitIp,
  });

  /// Checks whether the latency test completed successfully.
  bool get isSuccess => latencyMs != null && latencyMs! > 0;

  /// Converts a PingResult object into a NodeTestResult instance.
  factory NodeTestResult.fromPingResult(PingResult res) {
    return NodeTestResult(
      latencyMs: res.latencyMs,
      countryCode: res.countryCode,
      country: res.countryName,
      exitIp: res.exitIp,
    );
  }

  /// Efficiently parses a Cloudflare trace endpoint response to extract exit IP and country code.
  static ({String? ip, String? loc}) parseCloudflareTrace(String body) {
    String? ip;
    String? loc;
    for (final line in body.split("\n")) {
      final trimmed = line.trim();
      if (trimmed.startsWith("ip=")) {
        ip = trimmed.substring(3).trim();
      } else if (trimmed.startsWith("loc=")) {
        final val = trimmed.substring(4).trim().toUpperCase();
        if (val.isNotEmpty && val != "XX") {
          loc = val;
        }
      }
    }
    return (ip: ip, loc: loc);
  }
}
