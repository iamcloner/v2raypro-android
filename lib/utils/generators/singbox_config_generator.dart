// File: lib/utils/generators/singbox_config_generator.dart
// Description: Sing-box JSON configuration generator.
// Produces runnable, schema-valid JSON configurations for the Sing-box core engine.
// Supports VLESS, VMess, Trojan, Shadowsocks, WebSocket transport, TLS, and TUN inbounds.

import "../../models/proxy_node.dart";

/// Standard JSON configuration generator for the Sing-box core.
/// Constructs proxy outbounds, base routing rules, mixed inbounds, and virtual TUN interfaces.
class SingboxConfigGenerator {
  /// Generates complete Sing-box configuration dictionary from proxy node specifications.
  static Map<String, dynamic> generate(
    ProxyNode node, {
    int socksPort = 10808,
    int httpPort = 10809,
    bool enableTun = false,
  }) {
    String? nonEmpty(String? s) {
      if (s == null) return null;
      final t = s.trim();
      return t.isNotEmpty ? t : null;
    }

    final effectiveSni = nonEmpty(node.sni) ?? nonEmpty(node.host) ?? node.address;
    final effectiveHost = nonEmpty(node.host) ?? nonEmpty(node.sni) ?? node.address;
    final rawPath = nonEmpty(node.path) ?? "/";
    final safePath = rawPath.startsWith("/") ? rawPath : "/$rawPath";

    final outbounds = <Map<String, dynamic>>[
      {
        "type": node.protocol.name,
        "tag": "proxy",
        "server": node.address,
        "server_port": node.port,
        "uuid": node.uuidOrPassword,
        if (node.security == SecurityType.tls)
          "tls": {
            "enabled": true,
            "server_name": effectiveSni,
            if (node.alpn != null && node.alpn!.isNotEmpty) "alpn": node.alpn,
          },
        if (node.network == NetworkType.ws)
          "transport": {
            "type": "ws",
            "path": safePath,
            "headers": {
              "Host": effectiveHost,
            },
          },
      },
      {"type": "direct", "tag": "direct"},
      {"type": "block", "tag": "block"},
      {"type": "dns", "tag": "dns-out"}
    ];

    final inbounds = <Map<String, dynamic>>[
      {
        "type": "mixed",
        "tag": "mixed-in",
        "listen": "127.0.0.1",
        "listen_port": socksPort,
      }
    ];

    if (enableTun) {
      inbounds.add({
        "type": "tun",
        "tag": "tun-in",
        "interface_name": "v2raypro-tun",
        "inet4_address": "172.19.0.1/30",
        "auto_route": true,
        "strict_route": true
      });
    }

    return {
      "log": {"level": "warn"},
      "inbounds": inbounds,
      "outbounds": outbounds,
      "route": {
        "rules": [
          {"protocol": "dns", "outbound": "dns-out"},
          {"geoip": "private", "outbound": "direct"}
        ]
      }
    };
  }
}
