// File: lib/utils/parsers/singbox_parser.dart
// Description: Sing-box configuration parser and serializer.
// Converts Sing-box configurations to ProxyNode models and vice versa.
// Generates complete Sing-box configurations and maps outbound and inbound sections.

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/proxy_node.dart';
import 'v2ray_parsers.dart';

/// Parses a sing-box:// URL and extracts its JSON configuration.
ProxyNode? parseSingBoxUrl(String url) {
  try {
    final payload = url.replaceFirst(RegExp(r'^sing-?box://', caseSensitive: false), '').trim();
    if (payload.isEmpty) return null;

    if (payload.startsWith('{')) {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return parseSingBoxOutbound(decoded);
      }
    }

    try {
      final decodedBytes = base64Decode(normalizeBase64(payload));
      final jsonStr = utf8.decode(decodedBytes);
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return parseSingBoxOutbound(decoded);
      }
    } catch (_) {}

    final uriDecoded = Uri.decodeComponent(payload);
    if (uriDecoded.startsWith('{')) {
      final decoded = jsonDecode(uriDecoded);
      if (decoded is Map<String, dynamic>) {
        return parseSingBoxOutbound(decoded);
      }
    }
  } catch (_) {}
  return null;
}

/// Converts a Sing-box outbound map into a ProxyNode model.
ProxyNode? parseSingBoxOutbound(Map<String, dynamic> map) {
  try {
    final type = (map['type'] as String?)?.toLowerCase();
    if (type == null) return null;

    ProtocolType protocol;
    switch (type) {
      case 'vless':
        protocol = ProtocolType.vless;
        break;
      case 'vmess':
        protocol = ProtocolType.vmess;
        break;
      case 'trojan':
        protocol = ProtocolType.trojan;
        break;
      case 'shadowsocks':
        protocol = ProtocolType.shadowsocks;
        break;
      default:
        return null;
    }

    final address = (map['server'] as String?)?.trim() ?? '';
    if (address.isEmpty) return null;
    final port = (map['server_port'] as num?)?.toInt() ?? 443;
    final name = (map['tag'] as String?)?.trim() ?? '$address:$port';

    final uuidOrPassword = (map['uuid'] ?? map['password'] ?? '') as String;
    final flow = map['flow'] as String?;
    final cipher = map['method'] as String?;
    final alterId = (map['alter_id'] as num?)?.toInt() ?? 0;

    SecurityType security = SecurityType.none;
    String? sni;
    List<String>? alpn;
    bool allowInsecure = false;
    String? fingerprint;
    String? publicKey;
    String? shortId;
    String? echConfigList;

    if (map['tls'] is Map) {
      final tls = map['tls'] as Map<String, dynamic>;
      if (tls['enabled'] == true) {
        security = SecurityType.tls;
        sni = tls['server_name'] as String?;
        if (tls['alpn'] is List) {
          alpn = (tls['alpn'] as List).map((e) => e.toString()).toList();
        }
        allowInsecure = tls['insecure'] == true;
        if (tls['utls'] is Map) {
          fingerprint = (tls['utls'] as Map)['fingerprint'] as String?;
        }
        if (tls['ech'] is Map) {
          final ech = tls['ech'] as Map<String, dynamic>;
          if (ech['config'] is List) {
            echConfigList = (ech['config'] as List).map((e) => e.toString()).join(',');
          } else if (ech['config'] != null) {
            echConfigList = ech['config'].toString();
          }
        }
        if (tls['reality'] is Map) {
          final reality = tls['reality'] as Map<String, dynamic>;
          if (reality['enabled'] == true) {
            security = SecurityType.reality;
            publicKey = reality['public_key'] as String?;
            shortId = reality['short_id'] as String?;
          }
        }
      }
    }

    final packetEncoding = (map['packet_encoding'] ?? map['packetEncoding'])?.toString();

    NetworkType network = NetworkType.tcp;
    String? path;
    String? host;
    String? serviceName;

    if (map['transport'] is Map) {
      final trans = map['transport'] as Map<String, dynamic>;
      final transType = (trans['type'] as String?)?.toLowerCase();
      switch (transType) {
        case 'ws':
          network = NetworkType.ws;
          path = trans['path'] as String?;
          if (trans['headers'] is Map) {
            host = (trans['headers'] as Map)['Host'] as String?;
          }
          break;
        case 'grpc':
          network = NetworkType.grpc;
          serviceName = trans['service_name'] as String?;
          break;
        case 'http':
          network = NetworkType.h2;
          path = trans['path'] as String?;
          host = trans['host'] is List ? (trans['host'] as List).firstOrNull?.toString() : trans['host'] as String?;
          break;
        case 'httpupgrade':
          network = NetworkType.httpUpgrade;
          path = trans['path'] as String?;
          host = trans['host'] as String?;
          break;
      }
    }

    return ProxyNode(
      id: const Uuid().v4(),
      name: name,
      protocol: protocol,
      address: address,
      port: port,
      uuidOrPassword: uuidOrPassword,
      alterId: alterId,
      cipher: cipher,
      network: network,
      path: path,
      host: host,
      serviceName: serviceName,
      security: security,
      sni: sni,
      alpn: alpn,
      allowInsecure: allowInsecure,
      fingerprint: fingerprint,
      publicKey: publicKey,
      shortId: shortId,
      flow: flow,
      echConfigList: echConfigList,
      packetEncoding: packetEncoding,
    );
  } catch (_) {
    return null;
  }
}

/// Parses a complete Sing-box JSON configuration string and extracts outbound nodes.
List<ProxyNode> parseSingBoxConfig(String jsonStr) {
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      if (decoded['outbounds'] is List) {
        final nodes = <ProxyNode>[];
        for (final ob in (decoded['outbounds'] as List)) {
          if (ob is Map<String, dynamic>) {
            final node = parseSingBoxOutbound(ob);
            if (node != null) nodes.add(node);
          }
        }
        return nodes;
      } else {
        final node = parseSingBoxOutbound(decoded);
        if (node != null) return [node];
      }
    } else if (decoded is List) {
      final nodes = <ProxyNode>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final node = parseSingBoxOutbound(item);
          if (node != null) nodes.add(node);
        }
      }
      return nodes;
    }
  } catch (_) {}
  return [];
}

/// Converts a ProxyNode into a Sing-box outbound configuration map.
Map<String, dynamic> toSingBoxOutbound(ProxyNode node) {
  final map = <String, dynamic>{
    'type': node.protocol.name,
    'tag': node.name,
    'server': node.address,
    'server_port': node.port,
  };

  if (node.protocol == ProtocolType.vless || node.protocol == ProtocolType.vmess) {
    map['uuid'] = node.uuidOrPassword;
    if (node.protocol == ProtocolType.vmess && node.alterId > 0) {
      map['alter_id'] = node.alterId;
    }
    if (node.flow != null && node.flow!.isNotEmpty) {
      map['flow'] = node.flow;
    }
  } else if (node.protocol == ProtocolType.trojan) {
    map['password'] = node.uuidOrPassword;
  } else if (node.protocol == ProtocolType.shadowsocks) {
    map['password'] = node.uuidOrPassword;
    map['method'] = node.cipher ?? 'aes-128-gcm';
  }

  if (node.security == SecurityType.tls || node.security == SecurityType.reality) {
    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': node.sni ?? node.host ?? node.address,
    };
    if (node.allowInsecure) {
      tls['insecure'] = true;
    }
    if (node.alpn != null && node.alpn!.isNotEmpty) {
      tls['alpn'] = node.alpn;
    }
    if (node.fingerprint != null && node.fingerprint!.isNotEmpty) {
      tls['utls'] = {
        'enabled': true,
        'fingerprint': node.fingerprint,
      };
    }
    if (node.security == SecurityType.reality) {
      tls['reality'] = {
        'enabled': true,
        'public_key': node.publicKey ?? '',
        'short_id': node.shortId ?? '',
      };
    }
    map['tls'] = tls;
  }

  if (node.network == NetworkType.ws) {
    final ws = <String, dynamic>{
      'type': 'ws',
      'path': node.path ?? '/',
    };
    if (node.host != null && node.host!.isNotEmpty) {
      ws['headers'] = {'Host': node.host};
    }
    map['transport'] = ws;
  } else if (node.network == NetworkType.grpc) {
    map['transport'] = {
      'type': 'grpc',
      'service_name': node.serviceName ?? '',
    };
  } else if (node.network == NetworkType.httpUpgrade) {
    map['transport'] = {
      'type': 'httpupgrade',
      'path': node.path ?? '/',
      if (node.host != null && node.host!.isNotEmpty) 'host': node.host,
    };
  }

  return map;
}

/// Generates a runnable Sing-box JSON configuration string from a ProxyNode.
String generateSingBoxConfig(
  ProxyNode node, {
  int inHttpPort = 10809,
  int inSocksPort = 10808,
  bool allowLan = false,
}) {
  final bindAddr = allowLan ? '0.0.0.0' : '127.0.0.1';
  final proxyOutbound = toSingBoxOutbound(node);
  final config = {
    'log': {
      'level': 'info',
      'timestamp': true,
    },
    'inbounds': [
      {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': bindAddr,
        'listen_port': inHttpPort,
        'sniff': true,
      },
      {
        'type': 'socks',
        'tag': 'socks-in',
        'listen': bindAddr,
        'listen_port': inSocksPort,
        'sniff': true,
      },
    ],
    'outbounds': [
      proxyOutbound,
      {
        'type': 'direct',
        'tag': 'direct',
      },
      {
        'type': 'block',
        'tag': 'block',
      },
    ],
    'route': {
      'rules': [
        {
          'protocol': 'dns',
          'outbound': 'direct',
        },
        {
          'ip_is_private': true,
          'outbound': 'direct',
        },
      ],
      'auto_detect_interface': true,
    },
  };
  return const JsonEncoder.withIndent('  ').convert(config);
}
