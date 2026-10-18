// File: lib/models/real_delay_result.dart
// Description: Data model for real delay test results including IP and location details.
// Encapsulates latency, country code, country name, IPv4, and IPv6 exit addresses.

/// Real delay measurement result for a proxy node.
/// Supports map index access via [operator []] and JSON serialization.
class RealDelayResult {
  /// Round-trip latency in milliseconds.
  final int? ping;

  /// Two-letter country code of the node exit location (e.g. de, us, fr).
  final String? country;

  /// Public IPv4 address of the proxy exit endpoint.
  final String? ipv4;

  /// Public IPv6 address of the proxy exit endpoint.
  final String? ipv6;

  /// Full country name in English or localized format.
  final String? countryName;

  /// Creates a real delay result instance.
  const RealDelayResult({
    this.ping,
    this.country,
    this.ipv4,
    this.ipv6,
    this.countryName,
  });

  /// Uppercase ISO 3166-1 alpha-2 country code.
  String? get countryCode => country?.toUpperCase();

  /// Latency in milliseconds for cross-module compatibility.
  int? get latencyMs => ping;

  /// Public outbound exit IP (IPv4 or IPv6 fallback).
  String? get exitIp => ipv4 ?? ipv6;

  /// Indicates whether the ping test succeeded.
  bool get isSuccess => ping != null && ping! > 0;

  /// Serializes the result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    "ping": ping,
    "country": country,
    "ipv4": ipv4,
    "ipv6": ipv6,
  };

  /// Converts the result into a key-value map.
  Map<String, dynamic> toMap() => toJson();

  /// Accesses result fields via map index operator.
  dynamic operator [](String key) {
    switch (key.toLowerCase()) {
      case "ping":
        return ping;
      case "country":
        return country;
      case "ipv4":
        return ipv4;
      case "ipv6":
        return ipv6;
      case "countryname":
      case "country_name":
        return countryName;
      default:
        return null;
    }
  }

  @override
  String toString() {
    return 'ping = ${ping != null ? ping.toString() : "timeout"}\n'
        'country = ${country ?? "unknown"}\n'
        'ipv4 = ${ipv4 ?? "none"}\n'
        'ipv6 = ${ipv6 ?? "none"}';
  }
}
