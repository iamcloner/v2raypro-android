// Outbound Network & IP Geolocation Info Provider
// Responsible for querying public network info, outbound IP (IPv4 and IPv6), country, city, and ISP via proxy.
// This information is displayed in the home status card and persisted in active session state.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/node_test_result.dart';
import '../models/outbound_info.dart';
import '../services/country_service.dart';
import '../services/local_geoip.dart';
import '../services/storage_service.dart';
import 'nodes_provider.dart';
import 'settings_providers.dart';

/// Controls whether outbound IP is fully visible or partially masked for privacy.
final showFullIpProvider = StateProvider<bool>((ref) => false);

/// Manages outbound IP and geographical metadata for proxy traffic.
/// Extracts outbound server characteristics via lightweight requests routed through the local proxy port.
class OutboundInfoNotifier extends StateNotifier<OutboundInfo> {
  final Ref ref;

  /// Initializes with empty state.
  OutboundInfoNotifier(this.ref) : super(const OutboundInfo());

  /// Fetches outbound IP and location details using multiple fallback mechanisms.
  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    final httpPort = ref.read(httpPortProvider);

    String? ipv4;
    String? country;
    String? countryCode;
    String? city;
    String? isp;
    String? ipv6;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    client.findProxy = (uri) => "PROXY 127.0.0.1:$httpPort;";

    void assignIp(String? ip) {
      if (ip == null || ip.isEmpty) return;
      if (ip.contains(".")) {
        ipv4 ??= ip;
      } else if (ip.contains(":")) {
        ipv6 ??= ip;
      }
    }

    // Strategy 1: High-speed Cloudflare trace service via HTTPS
    final traceEndpoints = <Uri>[
      Uri.parse("https://cp.cloudflare.com/cdn-cgi/trace"),
      Uri.parse("https://1.1.1.1/cdn-cgi/trace"),
      Uri.parse("http://cp.cloudflare.com/cdn-cgi/trace"),
    ];

    for (final traceUri in traceEndpoints) {
      try {
        final req = await client.getUrl(traceUri);
        final resp = await req.close().timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final trace = NodeTestResult.parseCloudflareTrace(body);
          assignIp(trace.ip);
          if (trace.loc != null && trace.loc!.isNotEmpty && trace.loc != 'XX') {
            countryCode = trace.loc;
            country ??= CountryService.getCountryName(countryCode);
          } else if (trace.ip != null) {
            final geo = LocalGeoIp.instance.lookup(trace.ip!);
            if (geo != null) {
              countryCode = geo;
              country ??= CountryService.getCountryName(countryCode);
            }
          }
          if (ipv4 != null || ipv6 != null) break;
        }
      } catch (_) {}
    }

    // Strategy 2: ip-api.com fallback to extract city and ISP
    try {
      final req = await client.getUrl(Uri.parse("http://ip-api.com/json/"));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data["status"] == "success") {
          assignIp(data["query"]?.toString());
          country ??= data["country"]?.toString();
          countryCode ??= data["countryCode"]?.toString();
          city ??= data["city"]?.toString();
          isp ??= data["isp"]?.toString();
        }
      }
    } catch (_) {}

    // Strategy 3: ipwho.is fallback
    if (countryCode == null || countryCode.isEmpty || city == null || ipv4 == null) {
      try {
        final req = await client.getUrl(Uri.parse("https://ipwho.is/"));
        final resp = await req.close().timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          if (data["success"] == true) {
            assignIp(data["ip"]?.toString());
            country ??= data["country"]?.toString();
            countryCode ??= data["country_code"]?.toString();
            city ??= data["city"]?.toString();
            isp ??= data["connection"]?["isp"]?.toString();
          }
        }
      } catch (_) {}
    }

    // Strategy 4: api4.ipify.org dedicated IPv4 service
    if (ipv4 == null) {
      try {
        final req = await client.getUrl(Uri.parse("https://api4.ipify.org?format=json"));
        final resp = await req.close().timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          final ip = data["ip"]?.toString();
          if (ip != null && ip.contains(".")) ipv4 = ip;
        }
      } catch (_) {}
    }

    // Strategy 5: api6.ipify.org dedicated IPv6 service
    try {
      final req6 = await client.getUrl(Uri.parse("https://api6.ipify.org?format=json"));
      final resp6 = await req6.close().timeout(const Duration(seconds: 3));
      if (resp6.statusCode == 200) {
        final body = await resp6.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final ip = data["ip"]?.toString();
        if (ip != null && ip.contains(":")) ipv6 = ip;
      }
    } catch (_) {
    } finally {
      client.close();
    }

    state = OutboundInfo(
      ipv4: ipv4,
      ipv6: ipv6,
      country: country,
      countryCode: countryCode,
      city: city,
      isp: isp,
      isLoading: false,
    );

    StorageService.instance.updateActiveSessionOutbound(
      exitIp: ipv4 ?? ipv6,
      country: country,
      countryCode: countryCode,
    );

    if (countryCode != null && countryCode.isNotEmpty) {
      final active = ref.read(nodesProvider).where((n) => n.isActive).firstOrNull;
      if (active != null) {
        ref.read(nodesProvider.notifier).updateLatency(
          active.id,
          active.latencyMs,
          countryCode: countryCode,
          country: country ?? CountryService.getCountryName(countryCode),
        );
      }
    }
  }

  /// Restores cached outbound IP metadata from a previous active session.
  void setRestored({String? ipv4, String? ipv6, String? country, String? countryCode}) {
    state = OutboundInfo(
      ipv4: ipv4,
      ipv6: ipv6,
      country: country,
      countryCode: countryCode,
      isLoading: false,
    );
  }

  /// Resets outbound information when the proxy disconnects.
  void reset() {
    state = const OutboundInfo();
  }
}

/// Riverpod provider for outbound IP information displayed on dashboard.
final outboundInfoProvider = StateNotifierProvider<OutboundInfoNotifier, OutboundInfo>((ref) {
  return OutboundInfoNotifier(ref);
});
