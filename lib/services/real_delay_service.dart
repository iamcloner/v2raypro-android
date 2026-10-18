// =======================================================================
// [File Name]: real_delay_service.dart
// [Description]: Real connection latency calculation service via proxy and protocol probing on Android.
// Supports parsing various configuration types (JSON maps, sing-box formats, subscription links)
// and measures round-trip latency to verified destinations individually or in batches.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "../models/proxy_node.dart";
import "../models/real_delay_result.dart";
import "../utils/config_parser.dart";
import "country_service.dart";
import "local_geoip.dart";
import "protocol_probe.dart";
import "xray_process_service.dart";
import "real_delay_batch_runner.dart";
import "storage_service.dart";

export "../models/real_delay_result.dart";
export "real_delay_batch_runner.dart";

/// Parses various configuration inputs (JSON map, string, sing-box or Xray output) into a unified ProxyNode model.
ProxyNode? parseConfigToProxyNode(dynamic config) {
  if (config == null) return null;
  if (config is ProxyNode) return config;

  dynamic decoded = config;
  if (config is String) {
    final str = config.trim();
    if (str.startsWith("{") || str.startsWith("[")) {
      try {
        decoded = jsonDecode(str);
      } catch (_) {
        return null;
      }
    } else {
      return ConfigParser.parseSingle(str);
    }
  }

  if (decoded is Map<String, dynamic>) {
    if (decoded.containsKey("address") && decoded.containsKey("port")) {
      try {
        return ProxyNode.fromJson(decoded);
      } catch (_) {}
    }

    if (decoded.containsKey("outbounds") && decoded["outbounds"] is List) {
      final outbounds = decoded["outbounds"] as List;
      for (final ob in outbounds) {
        if (ob is Map<String, dynamic>) {
          final tag = (ob["tag"] ?? "").toString().toLowerCase();
          final protocol = (ob["protocol"] ?? ob["type"] ?? "").toString().toLowerCase();
          if (tag != "direct" && tag != "block" && tag != "dns-out" && protocol.isNotEmpty) {
            final parsed = _parseSingleOutboundMap(ob);
            if (parsed != null) return parsed;
          }
        }
      }
    }

    return _parseSingleOutboundMap(decoded);
  }

  return null;
}

/// Parses a single outbound dictionary from sing-box or Xray formats into a ProxyNode.
ProxyNode? _parseSingleOutboundMap(Map<String, dynamic> map) {
  try {
    if (map.containsKey("server") && map.containsKey("server_port")) {
      final protoStr = (map["type"] ?? "vless").toString().toLowerCase();
      final proto = ProtocolType.values.firstWhere(
        (p) => p.name.toLowerCase() == protoStr,
        orElse: () => ProtocolType.vless,
      );
      final server = map["server"].toString();
      final port = int.tryParse(map["server_port"].toString()) ?? 443;
      final uuid = (map["uuid"] ?? map["password"] ?? "").toString();

      SecurityType sec = SecurityType.none;
      String? sni;
      String? pbk;
      String? sid;
      String? fp;

      if (map["tls"] is Map<String, dynamic>) {
        final tls = map["tls"] as Map<String, dynamic>;
        if (tls["enabled"] == true) {
          sec = SecurityType.tls;
          sni = tls["server_name"]?.toString();
          if (tls["reality"] is Map<String, dynamic>) {
            final reality = tls["reality"] as Map<String, dynamic>;
            if (reality["enabled"] == true) {
              sec = SecurityType.reality;
              pbk = reality["public_key"]?.toString();
              sid = reality["short_id"]?.toString();
            }
          }
          if (tls["utls"] is Map<String, dynamic>) {
            fp = (tls["utls"] as Map<String, dynamic>)["fingerprint"]?.toString();
          }
        }
      }

      NetworkType net = NetworkType.tcp;
      String? path;
      String? host;
      if (map["transport"] is Map<String, dynamic>) {
        final transport = map["transport"] as Map<String, dynamic>;
        final typeStr = (transport["type"] ?? "").toString().toLowerCase();
        if (typeStr == "ws") net = NetworkType.ws;
        else if (typeStr == "grpc") net = NetworkType.grpc;
        else if (typeStr == "httpupgrade") net = NetworkType.httpUpgrade;
        else if (typeStr == "xhttp") net = NetworkType.xhttp;
        else if (typeStr == "splithttp") net = NetworkType.splithttp;
        path = transport["path"]?.toString();
        if (transport["headers"] is Map<String, dynamic>) {
          host = (transport["headers"] as Map<String, dynamic>)["Host"]?.toString();
        }
      }

      return ProxyNode(
        id: map["tag"]?.toString() ?? "singbox_node_${DateTime.now().millisecondsSinceEpoch}",
        name: map["tag"]?.toString() ?? "Sing-Box Node",
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

    if (map.containsKey("protocol") && map.containsKey("settings")) {
      final protoStr = map["protocol"].toString().toLowerCase();
      final proto = ProtocolType.values.firstWhere(
        (p) => p.name.toLowerCase() == protoStr,
        orElse: () => ProtocolType.vless,
      );
      final settings = map["settings"] as Map<String, dynamic>? ?? {};
      final vnext = settings["vnext"] as List?;
      if (vnext != null && vnext.isNotEmpty) {
        final first = vnext[0] as Map<String, dynamic>;
        final server = first["address"]?.toString() ?? "127.0.0.1";
        final port = int.tryParse(first["port"]?.toString() ?? "") ?? 443;
        final users = first["users"] as List?;
        final uuid = (users != null && users.isNotEmpty) ? (users[0]["id"]?.toString() ?? "") : "";

        return ProxyNode(
          id: map["tag"]?.toString() ?? "xray_node_${DateTime.now().millisecondsSinceEpoch}",
          name: map["tag"]?.toString() ?? "Xray Node",
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

/// Asynchronously tests real delay of an arbitrary configuration with standard and turbo modes.
Future<RealDelayResult> testRealDelay({
  String mode = "normal",
  String type = "xray",
  required dynamic config,
  Duration? timeout,
}) async {
  if (XrayProcessService.instance.core.androidBinaryPath == null) {
    await XrayProcessService.instance.initAndroid();
  }
  final isTurbo = mode.toLowerCase() == "turbo";
  final effectiveTimeout = timeout ?? (isTurbo ? const Duration(milliseconds: 2200) : const Duration(milliseconds: 3500));

  final node = parseConfigToProxyNode(config);
  if (node == null) {
    const res = RealDelayResult(ping: null, country: null, ipv4: null, ipv6: null);
    RealDelayBatchRunner.logResult(null, res);
    return res;
  }

  // In turbo mode, probe the config's IP first before running the full real delay test
  if (isTurbo) {
    final pingTimeout = effectiveTimeout < const Duration(milliseconds: 1500)
        ? effectiveTimeout
        : const Duration(milliseconds: 1500);
    final ipPing = await ProtocolProbe.instance.tcpPing(
      node.address,
      node.port,
      timeout: pingTimeout,
    );
    if (ipPing == null) {
      const res = RealDelayResult(ping: null, country: null, ipv4: null, ipv6: null);
      RealDelayBatchRunner.logResult(node, res);
      return res;
    }
  }

  final res = await _executeRealDelay(node, effectiveTimeout, isTurbo);
  RealDelayBatchRunner.logResult(node, res);
  return res;
}

/// Core measurement flow testing node latency via temporary proxy or strict protocol probing.
Future<RealDelayResult> _executeRealDelay(
  ProxyNode node,
  Duration effectiveTimeout,
  bool isTurbo, {
  bool skipBatchProxy = false,
}) async {
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
          if (exitIp.contains(".")) ipv4 = exitIp;
          if (exitIp.contains(":")) ipv6 = exitIp;
        }

        final geoFromExit = (exitIp != null && exitIp.isNotEmpty) ? LocalGeoIp.instance.lookup(exitIp) : null;
        final cCode = (res.countryCode ?? geoFromExit ?? node.countryCode ?? await CountryService.instance.resolveCountryCode(node))?.toLowerCase();
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

  // When Xray core is available, do not substitute failed proxy tests with TCP pings
  if (XrayProcessService.instance.findXrayBinarySync() != null) {
    return const RealDelayResult(ping: null, country: null, ipv4: null, ipv6: null);
  }

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
      ipv4: null,
      ipv6: null,
      countryName: cName,
    );
  }

  return const RealDelayResult(ping: null, country: null, ipv4: null, ipv6: null);
}

/// Alias for config real delay testing to maintain complete naming parity with client code.
Future<RealDelayResult> testConfigRealDelay({
  String mode = "normal",
  String type = "xray",
  required dynamic config,
  Duration? timeout,
}) => testRealDelay(mode: mode, type: type, config: config, timeout: timeout);

/// Executes batch latency evaluation for a list of configurations on Android.
Future<Map<String, RealDelayResult>> testRealDelayBatch({
  String mode = "normal",
  String type = "xray",
  required List<dynamic> configs,
  Duration? timeout,
  int? concurrency,
}) async {
  if (XrayProcessService.instance.core.androidBinaryPath == null) {
    await XrayProcessService.instance.initAndroid();
  }
  final List<ProxyNode> nodes = [];
  for (final c in configs) {
    final n = parseConfigToProxyNode(c);
    if (n != null) nodes.add(n);
  }
  if (nodes.isEmpty) return {};

  final isTurbo = mode.toLowerCase() == "turbo";
  final effectiveTimeout = timeout ?? (isTurbo ? const Duration(milliseconds: 2200) : const Duration(milliseconds: 3500));
  final poolSize = concurrency ?? await StorageService.instance.loadTestConcurrency();

  return await RealDelayBatchRunner.runBatch(
    nodes: nodes,
    effectiveTimeout: effectiveTimeout,
    isTurbo: isTurbo,
    concurrency: poolSize,
    testSingleNode: (node, t, turbo) => testRealDelay(
      mode: mode,
      type: type,
      config: node,
      timeout: t,
    ),
  );
}

/// Facade service for configuration real delay testing (Singleton).
class RealDelayService {
  /// Singleton instance of the service.
  static final RealDelayService instance = RealDelayService._internal();
  RealDelayService._internal();

  /// Executes latency test for a single configuration.
  Future<RealDelayResult> test({
    String mode = "normal",
    String type = "xray",
    required dynamic config,
    Duration? timeout,
  }) => testRealDelay(mode: mode, type: type, config: config, timeout: timeout);

  /// Executes latency test for a batch of configurations.
  Future<Map<String, RealDelayResult>> testBatch({
    String mode = "normal",
    String type = "xray",
    required List<dynamic> configs,
    Duration? timeout,
    int? concurrency,
  }) => testRealDelayBatch(mode: mode, type: type, configs: configs, timeout: timeout, concurrency: concurrency);
}
