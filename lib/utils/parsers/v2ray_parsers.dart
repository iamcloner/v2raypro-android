// File: lib/utils/parsers/v2ray_parsers.dart
// Description: V2Ray protocol URL parsers (VLESS, VMess, Trojan, Shadowsocks).
// Parses and converts proxy link schemas into ProxyNode models,
// extracting transport parameters, security layers (TLS/Reality), and custom headers.

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/proxy_node.dart';

/// Normalizes Base64-encoded strings and applies padding as needed.
String normalizeBase64(String input) {
  var str = input.replaceAll('\r', '').replaceAll('\n', '').trim();
  while (str.length % 4 != 0) {
    str += '=';
  }
  return str;
}

/// Parses a VLESS protocol URL into a ProxyNode model.
ProxyNode? parseVless(String url) {
  try {
    final uri = Uri.parse(url);
    final uuid = uri.userInfo;
    if (uuid.isEmpty) return null;
    final address = uri.host;
    if (address.isEmpty) return null;
    final port = uri.port > 0 ? uri.port : 443;
    final params = uri.queryParameters;
    final fragment = uri.fragment;
    final name = fragment.isNotEmpty ? Uri.decodeComponent(fragment) : '$address:$port';

    final typeStr = (params['type'] ?? 'tcp').toLowerCase();
    NetworkType network;
    switch (typeStr) {
      case 'xhttp': network = NetworkType.xhttp; break;
      case 'splithttp': network = NetworkType.splithttp; break;
      case 'ws': network = NetworkType.ws; break;
      case 'grpc': network = NetworkType.grpc; break;
      case 'h2': network = NetworkType.h2; break;
      case 'httpupgrade': network = NetworkType.httpUpgrade; break;
      default: network = NetworkType.tcp;
    }

    final echRaw = params['ech'] ?? params['echconfig'] ?? params['echConfig'] ?? params['echConfigList'] ?? params['ech_config_list'];
    final ech = (echRaw != null && echRaw.trim().isNotEmpty) ? echRaw.trim() : null;

    final secStr = (params['security'] ?? '').toLowerCase();
    SecurityType security;
    if (secStr == 'reality') {
      security = SecurityType.reality;
    } else if (secStr == 'tls' || (secStr.isEmpty && ech != null)) {
      security = SecurityType.tls;
    } else {
      security = SecurityType.none;
    }

    List<String>? alpnList;
    if (params.containsKey('alpn') && params['alpn']!.isNotEmpty) {
      alpnList = params['alpn']!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final certPin = params['pin'] ?? params['certPin'] ?? params['pinnedPeerCertificatePublicKeySha256'] ?? params['pinnedPeerCertSha256'];
    final verifyPeer = params['verifyPeerCertByName'] ?? params['verify_peer_cert_by_name'];
    final packetEnc = params['packetEncoding'] ?? params['packet_encoding'];
    final sniVal = params['sni'] ?? params['host'] ?? params['peer'] ?? params['serverName'];
    final fp = params['fp'] ?? params['fingerprint'] ?? (ech != null ? 'chrome' : null);

    return ProxyNode(
      id: const Uuid().v4(),
      name: name,
      protocol: ProtocolType.vless,
      address: address,
      port: port,
      uuidOrPassword: uuid,
      network: network,
      path: params['path'],
      host: params['host'],
      serviceName: params['serviceName'],
      security: security,
      sni: sniVal,
      alpn: alpnList,
      allowInsecure: params['allowInsecure'] == '1' || params['allowInsecure'] == 'true' || params['insecure'] == '1' || params['insecure'] == 'true',
      fingerprint: fp,
      publicKey: params['pbk'],
      shortId: params['sid'],
      spiderX: params['spx'],
      mode: params['mode'],
      extra: params['extra'],
      flow: params['flow'],
      headerType: params['headerType'],
      echConfigList: ech,
      verifyPeerCertByName: verifyPeer,
      certificatePinning: certPin,
      packetEncoding: packetEnc,
    );
  } catch (_) {
    return null;
  }
}

/// Parses and decodes a Base64-encoded VMess JSON URL into a ProxyNode model.
ProxyNode? parseVmess(String url) {
  try {
    final payload = url.substring('vmess://'.length).trim();
    final decodedJson = utf8.decode(base64Decode(normalizeBase64(payload)));
    final map = jsonDecode(decodedJson) as Map<String, dynamic>;

    final address = (map['add'] ?? '').toString();
    final port = int.tryParse(map['port']?.toString() ?? '443') ?? 443;
    final uuid = (map['id'] ?? '').toString();
    final name = (map['ps'] ?? '').toString().isNotEmpty ? map['ps'].toString() : '$address:$port';
    final alterId = int.tryParse(map['aid']?.toString() ?? '0') ?? 0;

    final netStr = (map['net'] ?? 'tcp').toString().toLowerCase();
    NetworkType network;
    switch (netStr) {
      case 'xhttp': network = NetworkType.xhttp; break;
      case 'splithttp': network = NetworkType.splithttp; break;
      case 'ws': network = NetworkType.ws; break;
      case 'grpc': network = NetworkType.grpc; break;
      case 'h2': network = NetworkType.h2; break;
      default: network = NetworkType.tcp;
    }

    final tlsStr = (map['tls'] ?? '').toString().toLowerCase();
    final security = tlsStr == 'tls' ? SecurityType.tls : SecurityType.none;

    List<String>? alpnList;
    if (map['alpn'] != null) {
      if (map['alpn'] is List) {
        alpnList = (map['alpn'] as List).map((e) => e.toString()).toList();
      } else if (map['alpn'] is String && (map['alpn'] as String).isNotEmpty) {
        alpnList = (map['alpn'] as String).split(',').map((e) => e.trim()).toList();
      }
    }

    final allowInsecure = map['insecure'] == '1' || map['insecure'] == true || map['allowInsecure'] == '1' || map['allowInsecure'] == true;
    final echRaw = (map['ech'] ?? map['echconfig'] ?? map['echConfig'] ?? map['echConfigList'] ?? map['ech_config_list'])?.toString();
    final ech = (echRaw != null && echRaw.trim().isNotEmpty) ? echRaw.trim() : null;
    final certPin = (map['pin'] ?? map['certPin'] ?? map['pinnedPeerCertificatePublicKeySha256'] ?? map['pinnedPeerCertSha256'])?.toString();
    final verifyPeer = (map['verifyPeerCertByName'] ?? map['verify_peer_cert_by_name'])?.toString();
    final packetEnc = (map['packetEncoding'] ?? map['packet_encoding'])?.toString();
    final sniVal = (map['sni'] ?? map['host'] ?? map['peer'] ?? map['serverName'])?.toString();
    final fp = map['fp']?.toString() ?? (ech != null ? 'chrome' : null);

    return ProxyNode(
      id: const Uuid().v4(),
      name: name,
      protocol: ProtocolType.vmess,
      address: address,
      port: port,
      uuidOrPassword: uuid,
      alterId: alterId,
      cipher: (map['scy'] ?? 'auto').toString(),
      network: network,
      path: map['path']?.toString(),
      host: map['host']?.toString(),
      security: (ech != null && security == SecurityType.none) ? SecurityType.tls : security,
      sni: sniVal,
      alpn: alpnList,
      allowInsecure: allowInsecure,
      fingerprint: fp,
      headerType: map['type']?.toString(),
      echConfigList: ech,
      verifyPeerCertByName: verifyPeer,
      certificatePinning: certPin,
      packetEncoding: packetEnc,
    );
  } catch (_) {
    return null;
  }
}

/// Parses a Trojan protocol URL into a ProxyNode model.
ProxyNode? parseTrojan(String url) {
  try {
    final uri = Uri.parse(url);
    final password = uri.userInfo;
    if (password.isEmpty) return null;

    final address = uri.host;
    if (address.isEmpty) return null;
    final port = uri.port > 0 ? uri.port : 443;
    final params = uri.queryParameters;
    final fragment = uri.fragment;
    final name = fragment.isNotEmpty ? Uri.decodeComponent(fragment) : '$address:$port';

    final typeStr = (params['type'] ?? 'tcp').toLowerCase();
    NetworkType network;
    switch (typeStr) {
      case 'ws': network = NetworkType.ws; break;
      case 'grpc': network = NetworkType.grpc; break;
      case 'xhttp': network = NetworkType.xhttp; break;
      default: network = NetworkType.tcp;
    }

    final secStr = (params['security'] ?? 'tls').toLowerCase();
    final security = secStr == 'none' ? SecurityType.none : SecurityType.tls;

    List<String>? alpnList;
    if (params.containsKey('alpn') && params['alpn']!.isNotEmpty) {
      alpnList = params['alpn']!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final echRaw = params['ech'] ?? params['echconfig'] ?? params['echConfig'] ?? params['echConfigList'] ?? params['ech_config_list'];
    final ech = (echRaw != null && echRaw.trim().isNotEmpty) ? echRaw.trim() : null;
    final certPin = params['pin'] ?? params['certPin'] ?? params['pinnedPeerCertificatePublicKeySha256'] ?? params['pinnedPeerCertSha256'];
    final verifyPeer = params['verifyPeerCertByName'] ?? params['verify_peer_cert_by_name'];
    final packetEnc = params['packetEncoding'] ?? params['packet_encoding'];
    final sniVal = params['sni'] ?? params['host'] ?? params['peer'] ?? params['serverName'];
    final fp = params['fp'] ?? params['fingerprint'] ?? (ech != null ? 'chrome' : null);

    return ProxyNode(
      id: const Uuid().v4(),
      name: name,
      protocol: ProtocolType.trojan,
      address: address,
      port: port,
      uuidOrPassword: password,
      network: network,
      path: params['path'],
      host: params['host'],
      serviceName: params['serviceName'],
      security: (ech != null && security == SecurityType.none) ? SecurityType.tls : security,
      sni: sniVal,
      alpn: alpnList,
      allowInsecure: params['allowInsecure'] == '1' || params['allowInsecure'] == 'true' || params['insecure'] == '1' || params['insecure'] == 'true',
      fingerprint: fp,
      flow: params['flow'],
      headerType: params['headerType'],
      echConfigList: ech,
      verifyPeerCertByName: verifyPeer,
      certificatePinning: certPin,
      packetEncoding: packetEnc,
    );
  } catch (_) {
    return null;
  }
}

/// Parses a Shadowsocks protocol URL into a ProxyNode model.
ProxyNode? parseShadowsocks(String url) {
  try {
    final uri = Uri.parse(url);
    final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : 'SS Node';

    String address = uri.host;
    int port = uri.port > 0 ? uri.port : 8388;
    String cipher = 'aes-256-gcm';
    String password = '';

    final userinfo = uri.userInfo;
    if (userinfo.contains(':')) {
      final parts = userinfo.split(':');
      cipher = parts[0];
      password = parts[1];
    } else if (userinfo.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64Decode(normalizeBase64(userinfo)));
        final parts = decoded.split(':');
        if (parts.length >= 2) {
          cipher = parts[0];
          password = parts.sublist(1).join(':');
        } else {
          password = userinfo;
        }
      } catch (_) {
        password = userinfo;
      }
    }

    if (address.isEmpty && uri.path.isNotEmpty) {
      try {
        final decoded = utf8.decode(base64Decode(normalizeBase64(uri.path)));
        final atIdx = decoded.indexOf('@');
        if (atIdx > 0) {
          final creds = decoded.substring(0, atIdx).split(':');
          final server = decoded.substring(atIdx + 1).split(':');
          cipher = creds[0];
          password = creds[1];
          address = server[0];
          port = int.parse(server[1]);
        }
      } catch (_) {}
    }

    if (address.isEmpty) return null;

    return ProxyNode(
      id: const Uuid().v4(),
      name: name,
      protocol: ProtocolType.shadowsocks,
      address: address,
      port: port,
      uuidOrPassword: password,
      cipher: cipher,
    );
  } catch (_) {
    return null;
  }
}
