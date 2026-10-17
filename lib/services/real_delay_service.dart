import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../models/log_entry.dart';
import '../models/proxy_node.dart';
import '../utils/config_parser.dart';
import 'country_service.dart';
import 'log_service.dart';
import 'xray_process_service.dart';

/// Result object for Real Delay testing.
/// Provides direct properties, Map index access [key], and a formatted string output:
/// ping = 320
/// country = us
/// ipv4 = x.x.x.x
/// ipv6 = x:x:x:x
class RealDelayResult {
  final int? ping;
  final String? country;
  final String? ipv4;
  final String? ipv6;
  final String? countryName;

  const RealDelayResult({
    this.ping,
    this.country,
    this.ipv4,
    this.ipv6,
    this.countryName,
  });

  String? get countryCode => country?.toUpperCase();
  int? get latencyMs => ping;
  String? get exitIp => ipv4 ?? ipv6;

  bool get isSuccess => ping != null && ping! > 0;

  Map<String, dynamic> toJson() => {
    'ping': ping,
    'country': country,
    'ipv4': ipv4,
    'ipv6': ipv6,
  };

  Map<String, dynamic> toMap() => toJson();

  dynamic operator [](String key) {
    switch (key.toLowerCase()) {
      case 'ping':
        return ping;
      case 'country':
        return country;
      case 'ipv4':
        return ipv4;
      case 'ipv6':
        return ipv6;
      case 'countryname':
      case 'country_name':
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

/// Helper to parse any config format (JSON Map, JSON String, Sing-box outbound, Xray outbound, or ProxyNode)
/// into a standard ProxyNode.
ProxyNode? parseConfigToProxyNode(dynamic config) {
  if (config == null) return null;
  if (config is ProxyNode) return config;

  dynamic decoded = config;
  if (config is String) {
    final str = config.trim();
    if (str.startsWith('{') || str.startsWith('[')) {
      try {
        decoded = jsonDecode(str);
      } catch (_) {
        return null;
      }
    } else {
      // Could be share link (vless://, vmess://, etc.)
      return ConfigParser.parseSingle(str);
    }
  }

  if (decoded is Map<String, dynamic>) {
    // 1. Direct ProxyNode JSON
    if (decoded.containsKey('address') && decoded.containsKey('port')) {
      try {
        return ProxyNode.fromJson(decoded);
      } catch (_) {}
    }

    // 2. Full Xray config with 'outbounds'
    if (decoded.containsKey('outbounds') && decoded['outbounds'] is List) {
      final outbounds = decoded['outbounds'] as List;
      for (final ob in outbounds) {
        if (ob is Map<String, dynamic>) {
          final tag = (ob['tag'] ?? '').toString().toLowerCase();
          final protocol = (ob['protocol'] ?? ob['type'] ?? '').toString().toLowerCase();
          if (tag != 'direct' && tag != 'block' && tag != 'dns-out' && protocol.isNotEmpty) {
            final parsed = _parseSingleOutboundMap(ob);
            if (parsed != null) return parsed;
          }
        }
      }
    }

    // 3. Single outbound map (Sing-box or Xray)
    return _parseSingleOutboundMap(decoded);
  }

  return null;
}

ProxyNode? _parseSingleOutboundMap(Map<String, dynamic> map) {
  try {
    // Sing-box format: {"type": "vless", "server": "1.2.3.4", "server_port": 443, ...}
    if (map.containsKey('server') && map.containsKey('server_port')) {
      final protoStr = (map['type'] ?? 'vless').toString().toLowerCase();
      final proto = ProtocolType.values.firstWhere(
        (p) => p.name.toLowerCase() == protoStr,
        orElse: () => ProtocolType.vless,
      );
      final server = map['server'].toString();
      final port = int.tryParse(map['server_port'].toString()) ?? 443;
      final uuid = (map['uuid'] ?? map['password'] ?? '').toString();

      SecurityType sec = SecurityType.none;
      String? sni;
      String? pbk;
      String? sid;
      String? fp;

      if (map['tls'] is Map<String, dynamic>) {
        final tls = map['tls'] as Map<String, dynamic>;
        if (tls['enabled'] == true) {
          sec = SecurityType.tls;
          sni = tls['server_name']?.toString();
          if (tls['reality'] is Map<String, dynamic>) {
            final reality = tls['reality'] as Map<String, dynamic>;
            if (reality['enabled'] == true) {
              sec = SecurityType.reality;
              pbk = reality['public_key']?.toString();
              sid = reality['short_id']?.toString();
            }
          }
          if (tls['utls'] is Map<String, dynamic>) {
            fp = (tls['utls'] as Map<String, dynamic>)['fingerprint']?.toString();
          }
        }
      }

      NetworkType net = NetworkType.tcp;
      String? path;
      String? host;
      if (map['transport'] is Map<String, dynamic>) {
        final transport = map['transport'] as Map<String, dynamic>;
        final typeStr = (transport['type'] ?? '').toString().toLowerCase();
        if (typeStr == 'ws') net = NetworkType.ws;
        else if (typeStr == 'grpc') net = NetworkType.grpc;
        else if (typeStr == 'httpupgrade') net = NetworkType.httpUpgrade;
        else if (typeStr == 'xhttp') net = NetworkType.xhttp;
        else if (typeStr == 'splithttp') net = NetworkType.splithttp;
        path = transport['path']?.toString();
        if (transport['headers'] is Map<String, dynamic>) {
          host = (transport['headers'] as Map<String, dynamic>)['Host']?.toString();
        }
      }

      return ProxyNode(
        id: map['tag']?.toString() ?? 'singbox_node_${DateTime.now().millisecondsSinceEpoch}',
        name: map['tag']?.toString() ?? 'Sing-Box Node',
        protocol: proto,
        address: server,
        port: port,
        uuidOrPassword: uuid,
        security: sec,
        network: net,
        sni: sni,
        host: host,
        path: path,
        publicKey: pbk,
        shortId: sid,
        fingerprint: fp,
      );
    }

    // Xray format: {"protocol": "vless", "settings": {"vnext": [{"address": "...", "port": 443, "users": [...]}]}}
    if (map.containsKey('protocol') && map.containsKey('settings')) {
      final protoStr = map['protocol'].toString().toLowerCase();
      final proto = ProtocolType.values.firstWhere(
        (p) => p.name.toLowerCase() == protoStr,
        orElse: () => ProtocolType.vless,
      );
      final settings = map['settings'] as Map<String, dynamic>? ?? {};
      final vnext = settings['vnext'] as List?;
      if (vnext != null && vnext.isNotEmpty) {
        final first = vnext[0] as Map<String, dynamic>;
        final server = first['address']?.toString() ?? '127.0.0.1';
        final port = int.tryParse(first['port']?.toString() ?? '') ?? 443;
        final users = first['users'] as List?;
        final uuid = (users != null && users.isNotEmpty) ? (users[0]['id']?.toString() ?? '') : '';

        return ProxyNode(
          id: map['tag']?.toString() ?? 'xray_node_${DateTime.now().millisecondsSinceEpoch}',
          name: map['tag']?.toString() ?? 'Xray Node',
          protocol: proto,
          address: server,
          port: port,
          uuidOrPassword: uuid,
        );
      }
    }
  } catch (_) {}
  return null;
}

/// Logs the test result to the application log as a warning
void _logRealDelayResult(ProxyNode? node, RealDelayResult res) {
  final header = node != null && node.name.isNotEmpty
      ? '[Real Delay Test] ${node.name}'
      : '[Real Delay Test]';
  final message = '$header:\n$res';
  LogService.instance.add(
    message,
    level: LogLevel.warning,
    source: 'test',
  );
}

/// Public Async Function for testing real delay of a config.
/// Parameters:
/// - [mode]: 'normal' | 'turbo'
/// - [type]: 'xray' | 'singbox'
/// - [config]: {json_config_data} (Map<String, dynamic>, JSON String, or ProxyNode)
///
/// Output sample:
/// ping = 320
/// country = us
/// ipv4 = x.x.x.x
/// ipv6 = x:x:x:x
Future<RealDelayResult> testRealDelay({
  String mode = 'normal',
  String type = 'xray',
  required dynamic config,
  Duration? timeout,
}) async {
  final isTurbo = mode.toLowerCase() == 'turbo';
  final effectiveTimeout = timeout ?? (isTurbo ? const Duration(milliseconds: 2200) : const Duration(milliseconds: 3500));

  final node = parseConfigToProxyNode(config);
  if (node == null) {
    const res = RealDelayResult(
      ping: null,
      country: null,
      ipv4: null,
      ipv6: null,
    );
    _logRealDelayResult(null, res);
    return res;
  }

  final res = await _executeRealDelay(node, effectiveTimeout, isTurbo);
  _logRealDelayResult(node, res);
  return res;
}

Future<RealDelayResult> _executeRealDelay(
  ProxyNode node,
  Duration effectiveTimeout,
  bool isTurbo, {
  bool skipBatchProxy = false,
}) async {
  // Direct probe: Ping must test node directly and NOT pass through running VPN/proxy

  // Pre-connection Real Delay via Ephemeral Proxy
  if (!skipBatchProxy && XrayProcessService.instance.isNodeConfigSupported(node)) {
    try {
      final batchMap = await XrayProcessService.instance.testNodesBatchRealProxy(
        [node],
        timeout: effectiveTimeout,
      );
      final res = batchMap[node.id];
      if (res != null && res.isSuccess) {
        String? ipv4;
        String? ipv6;
        final exitIp = res.exitIp;
        if (exitIp != null && exitIp.isNotEmpty) {
          if (exitIp.contains('.')) ipv4 = exitIp;
          if (exitIp.contains(':')) ipv6 = exitIp;
        }

        final cCode = (res.countryCode ?? node.countryCode ?? await CountryService.instance.resolveCountryCode(node))?.toLowerCase();
        final cName = res.country ?? (cCode != null ? CountryService.getCountryName(cCode.toUpperCase()) : node.country);

        return RealDelayResult(
          ping: res.latencyMs,
          country: cCode,
          ipv4: ipv4,
          ipv6: ipv6,
          countryName: cName,
        );
      }
    } catch (_) {}
  }

  // Direct authentic protocol probe (TCP/TLS handshake + transport verification)
  final handshakeLat = await XrayProcessService.instance.testNodeProtocolDelay(
    node,
    timeout: effectiveTimeout,
    count: isTurbo ? 1 : 2,
  );
  if (handshakeLat != null && handshakeLat > 0) {
    final cCode = (node.countryCode ?? await CountryService.instance.resolveCountryCode(node))?.toLowerCase();
    final cName = cCode != null ? CountryService.getCountryName(cCode.toUpperCase()) : node.country;
    return RealDelayResult(
      ping: handshakeLat,
      country: cCode,
      ipv4: RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(node.address) ? node.address : null,
      ipv6: node.address.contains(':') ? node.address : null,
      countryName: cName,
    );
  }

  return const RealDelayResult(
    ping: null,
    country: null,
    ipv4: null,
    ipv6: null,
  );
}

/// Helper that directly queries Cloudflare trace & ping endpoints through an established HTTP proxy port
Future<RealDelayResult> _probeProxyEndpoint({
  required String proxyHost,
  required int proxyPort,
  required Duration timeout,
  required bool isTurbo,
  ProxyNode? nodeFallback,
}) async {
  HttpClient? client;
  try {
    client = HttpClient();
    client.findProxy = (uri) => 'PROXY $proxyHost:$proxyPort';
    client.connectionTimeout = timeout;

    int? ping;
    String? country;
    String? ipv4;
    String? ipv6;

    // 1. Cloudflare cdn-cgi/trace probe: returns 200, authentic latency, exit IP and country code in 1 roundtrip
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse('http://cp.cloudflare.com/cdn-cgi/trace')).timeout(timeout);
      final resp = await req.close().timeout(timeout);
      sw.stop();
      if (resp.statusCode == 200) {
        ping = sw.elapsedMilliseconds;
        final body = await resp.transform(utf8.decoder).join().timeout(const Duration(milliseconds: 600));
        final trace = NodeTestResult.parseCloudflareTrace(body);
        if (trace.loc != null && trace.loc!.isNotEmpty && trace.loc != 'XX') {
          country = trace.loc!.toLowerCase();
        }
        final ip = trace.ip;
        if (ip != null && ip.isNotEmpty) {
          if (ip.contains('.')) ipv4 = ip;
          if (ip.contains(':')) ipv6 = ip;
        }
      }
    } catch (_) {}

    // 2. Normal mode: probe generate_204 to get lowest ping
    if (!isTurbo || ping == null) {
      final genPing = await XrayProcessService.instance.pingGoogleViaProxy(client, count: 2, timeout: timeout);
      if (genPing != null && genPing > 0) {
        ping = ping == null ? genPing : math.min(ping, genPing);
      }
    }

    // 3. Fallback country from local GeoIP if trace didn't provide it
    if (country == null && ipv4 != null) {
      final localCode = LocalGeoIp.instance.lookup(ipv4);
      if (localCode != null) country = localCode.toLowerCase();
    }
    if (country == null && nodeFallback != null) {
      final fallbackCode = await CountryService.instance.resolveCountryCode(nodeFallback);
      if (fallbackCode != null) country = fallbackCode.toLowerCase();
    }

    final cName = country != null ? CountryService.getCountryName(country.toUpperCase()) : null;

    return RealDelayResult(
      ping: ping,
      country: country,
      ipv4: ipv4,
      ipv6: ipv6,
      countryName: cName,
    );
  } catch (_) {
    return const RealDelayResult(ping: null, country: null, ipv4: null, ipv6: null);
  } finally {
    try {
      client?.close(force: true);
    } catch (_) {}
  }
}

/// Convenience alias matching user naming
Future<RealDelayResult> testConfigRealDelay({
  String mode = 'normal',
  String type = 'xray',
  required dynamic config,
  Duration? timeout,
}) => testRealDelay(mode: mode, type: type, config: config, timeout: timeout);

/// Batch testing for multiple configs
Future<Map<String, RealDelayResult>> testRealDelayBatch({
  String mode = 'normal',
  String type = 'xray',
  required List<dynamic> configs,
  Duration? timeout,
}) async {
  final List<ProxyNode> nodes = [];
  final Map<String, dynamic> rawMap = {};
  for (final c in configs) {
    final n = parseConfigToProxyNode(c);
    if (n != null) {
      nodes.add(n);
      rawMap[n.id] = c;
    }
  }
  if (nodes.isEmpty) return {};

  final isTurbo = mode.toLowerCase() == 'turbo';
  final effectiveTimeout = timeout ?? (isTurbo ? const Duration(milliseconds: 2200) : const Duration(milliseconds: 3500));
  final results = <String, RealDelayResult>{};

  // On desktop, attempt batch proxy test once
  Map<String, NodeTestResult> resMap = {};
  if (!Platform.isAndroid) {
    try {
      resMap = await XrayProcessService.instance.testNodesBatchRealProxy(nodes, timeout: effectiveTimeout);
    } catch (_) {}
  }

  // Identify nodes that need direct protocol testing
  final unresolvedNodes = <ProxyNode>[];
  for (final n in nodes) {
    final r = resMap[n.id];
    if (r != null && r.isSuccess) {
      String? ipv4;
      String? ipv6;
      final exitIp = r.exitIp;
      if (exitIp != null && exitIp.isNotEmpty) {
        if (exitIp.contains('.')) ipv4 = exitIp;
        if (exitIp.contains(':')) ipv6 = exitIp;
      }
      final cCode = (r.countryCode ?? n.countryCode)?.toLowerCase();
      final singleRes = RealDelayResult(
        ping: r.latencyMs,
        country: cCode,
        ipv4: ipv4,
        ipv6: ipv6,
        countryName: r.country ?? (cCode != null ? CountryService.getCountryName(cCode.toUpperCase()) : n.country),
      );
      _logRealDelayResult(n, singleRes);
      results[n.id] = singleRes;
    } else {
      unresolvedNodes.add(n);
    }
  }

  // Test unresolved nodes concurrently in parallel chunks of 25
  if (unresolvedNodes.isNotEmpty) {
    const int chunkSize = 25;
    for (int i = 0; i < unresolvedNodes.length; i += chunkSize) {
      final end = math.min(i + chunkSize, unresolvedNodes.length);
      final chunk = unresolvedNodes.sublist(i, end);
      final chunkResults = await Future.wait(chunk.map((n) async {
        final singleRes = await _executeRealDelay(n, effectiveTimeout, isTurbo, skipBatchProxy: true);
        _logRealDelayResult(n, singleRes);
        return MapEntry(n.id, singleRes);
      }));
      for (final entry in chunkResults) {
        results[entry.key] = entry.value;
      }
    }
  }

  return results;
}

class RealDelayService {
  static final RealDelayService instance = RealDelayService._internal();
  RealDelayService._internal();

  Future<RealDelayResult> test({
    String mode = 'normal',
    String type = 'xray',
    required dynamic config,
    Duration? timeout,
  }) => testRealDelay(mode: mode, type: type, config: config, timeout: timeout);

  Future<Map<String, RealDelayResult>> testBatch({
    String mode = 'normal',
    String type = 'xray',
    required List<dynamic> configs,
    Duration? timeout,
  }) => testRealDelayBatch(mode: mode, type: type, configs: configs, timeout: timeout);
}

