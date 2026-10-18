// File: lib/utils/config_generator.dart
// Description: Unified configuration generator for Xray and Sing-box proxy cores.
// Generates runnable JSON config maps with inbounds, outbounds, DNS, and routing rules.

import "dart:io";
import "../models/proxy_node.dart";
import "../models/routing_rule.dart";
import "generators/singbox_config_generator.dart";
import "generators/xray_stream_builder.dart";

export "generators/singbox_config_generator.dart";
export "generators/xray_stream_builder.dart";

/// Unified configuration generator for Xray and Sing-box cores on Android.
class ConfigGenerator {
  static const List<String> defaultDns = ["1.1.1.1", "8.8.8.8", "https://1.1.1.1/dns-query"];

  /// Generates a complete Xray configuration file as a structured JSON map.
  static Map<String, dynamic> generateXrayConfig(
    ProxyNode node, {
    int socksPort = 10808,
    int httpPort = 10809,
    int apiPort = 10085,
    bool enableTun = false,
    bool enableUdp = true,
    bool enableMux = false,
    bool allowInsecure = false,
    bool allowLan = false,
    List<String> dnsServers = defaultDns,
    List<RoutingRule> routingRules = const [],
    AppRoutingMode appRoutingMode = AppRoutingMode.exclusive,
  }) {
    final streamSettings = XrayStreamBuilder.build(node);

    Map<String, dynamic> outbound;
    if (node.protocol == ProtocolType.vless) {
      final user = <String, dynamic>{
        "id": node.uuidOrPassword,
        "encryption": "none",
        "level": 0,
        "packetEncoding": "xudp",
      };
      if (node.flow != null &&
          node.flow!.trim().isNotEmpty &&
          node.network == NetworkType.tcp) {
        user["flow"] = node.flow!.trim();
      }
      outbound = {
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": node.address,
              "port": node.port,
              "users": [user]
            }
          ]
        },
        "streamSettings": streamSettings,
      };
    } else if (node.protocol == ProtocolType.trojan) {
      outbound = {
        "tag": "proxy",
        "protocol": "trojan",
        "settings": {
          "servers": [
            {
              "address": node.address,
              "port": node.port,
              "password": node.uuidOrPassword,
              "level": 0
            }
          ]
        },
        "streamSettings": streamSettings,
      };
    } else if (node.protocol == ProtocolType.vmess) {
      outbound = {
        "tag": "proxy",
        "protocol": "vmess",
        "settings": {
          "vnext": [
            {
              "address": node.address,
              "port": node.port,
              "users": [
                {
                  "id": node.uuidOrPassword,
                  "alterId": node.alterId,
                  "security": node.cipher ?? "auto",
                  "level": 0
                }
              ]
            }
          ]
        },
        "streamSettings": streamSettings,
      };
    } else {
      outbound = {
        "tag": "proxy",
        "protocol": "shadowsocks",
        "settings": {
          "servers": [
            {
              "address": node.address,
              "port": node.port,
              "method": (node.cipher ?? 'aes-256-gcm').toLowerCase().trim(),
              "password": node.uuidOrPassword,
              "level": 0
            }
          ]
        }
      };
    }

    if (node.enableMux || enableMux) {
      outbound["mux"] = {
        "enabled": true,
        "concurrency": 8,
      };
    }

    final listenAddr = allowLan ? "0.0.0.0" : "127.0.0.1";
    final inbounds = <Map<String, dynamic>>[
      {
        "tag": "socks-in",
        "port": socksPort,
        "listen": listenAddr,
        "protocol": "socks",
        "settings": {"auth": "noauth", "udp": enableUdp},
        "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
      },
      {
        "tag": "http-in",
        "port": httpPort,
        "listen": listenAddr,
        "protocol": "http",
        "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
      },
      {
        "tag": "api",
        "port": apiPort,
        "listen": "127.0.0.1",
        "protocol": "dokodemo-door",
        "settings": {"address": "127.0.0.1"}
      }
    ];

    if (enableTun) {
      inbounds.add({
        "tag": "tun-in",
        "protocol": "tun",
        "settings": {
          "name": "v2raypro-tun",
          "mtu": 1500,
          "gateway": ["172.19.0.1/30"],
          "dns": (() {
            final tunIps = dnsServers
                .where((s) => !s.startsWith("https://") && s.toLowerCase() != "localhost" && s.trim().isNotEmpty)
                .toList();
            return tunIps.isNotEmpty ? tunIps : ["1.1.1.1", "8.8.8.8"];
          })(),
          "autoSystemRoutingTable": ["0.0.0.0/0", "0.0.0.0/1", "128.0.0.0/1"],
          "autoOutboundsInterface": "auto"
        },
        "sniffing": {
          "enabled": true,
          "destOverride": ["http", "tls", "quic"],
          "metadataOnly": false
        }
      });
    }

    final effectiveDns = dnsServers.isNotEmpty
        ? [...dnsServers, if (!dnsServers.contains("localhost")) "localhost"]
        : ["8.8.8.8", "1.1.1.1", "https://1.1.1.1/dns-query", "localhost"];

    return {
      "log": {"loglevel": Platform.isAndroid ? "none" : "warning"},
      "api": {"tag": "api", "services": ["StatsService"]},
      "stats": {},
      "policy": {
        "levels": {
          "0": {
            "statsUserUplink": true,
            "statsUserDownlink": true,
            "uplinkOnly": 2,
            "downlinkOnly": 5
          }
        },
        "system": {
          "statsInboundUplink": true,
          "statsInboundDownlink": true,
          "statsOutboundUplink": true,
          "statsOutboundDownlink": true
        }
      },
      "dns": {"servers": effectiveDns},
      "inbounds": inbounds,
      "outbounds": [
        outbound,
        {"tag": "dns-out", "protocol": "dns"},
        {"tag": "direct", "protocol": "freedom"},
        {"tag": "block", "protocol": "blackhole"}
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {"type": "field", "inboundTag": ["api"], "outboundTag": "api"},
          if (enableTun)
            {"type": "field", "inboundTag": ["tun-in"], "port": 53, "outboundTag": "dns-out"},
          {"type": "field", "outboundTag": "direct", "ip": ["geoip:private"]},
          ...(() {
            final custom = <Map<String, dynamic>>[];
            for (final r in routingRules.where((rule) => rule.enabled)) {
              if (r.values.isEmpty) continue;
              if (r.type == RoutingRuleType.address) {
                final expandedDomains = <String>[];
                for (final val in r.values) {
                  final trimmed = val.trim();
                  if (trimmed.toLowerCase() == "geosite:ir") {
                    expandedDomains.add("geosite:category-ir");
                    expandedDomains.add(r"regexp:.*\.ir$");
                  } else {
                    expandedDomains.add(trimmed);
                  }
                }
                custom.add({
                  "type": "field",
                  "outboundTag": r.action.name,
                  "domain": expandedDomains,
                });
              } else if (r.type == RoutingRuleType.ip) {
                custom.add({
                  "type": "field",
                  "outboundTag": r.action.name,
                  "ip": r.values,
                });
              } else if (r.type == RoutingRuleType.app && enableTun) {
                custom.add({
                  "type": "field",
                  "outboundTag": r.action.name,
                  "process": r.values,
                });
              }
            }
            return custom;
          })(),
        ]
      }
    };
  }

  /// Generates configuration compatible with the Sing-box core.
  static Map<String, dynamic> generateSingboxConfig(
    ProxyNode node, {
    int socksPort = 10808,
    int httpPort = 10809,
    bool enableTun = false,
  }) {
    return SingboxConfigGenerator.generate(
      node,
      socksPort: socksPort,
      httpPort: httpPort,
      enableTun: enableTun,
    );
  }
}
