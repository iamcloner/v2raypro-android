// =======================================================================
// [File Name]: core_config_builder.dart
// [Description]: Specialized module for building and validating Xray proxy core runtime configuration.
// Assembles network settings including SOCKS and HTTP inbounds, traffic stats policies,
// routing rules, and Mux parameters into standard core JSON format.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:io";
import "../models/service_models.dart";

/// Builder and converter module transforming app configurations into valid Xray core configs.
/// Handles local ports, connection protocols, and traffic routing.
class CoreConfigBuilder {
  /// Builds the final Xray core configuration map to be written to a temporary runtime file.
  /// 
  /// [config]: Core configuration object containing node details and extracted outbounds.
  /// [socksPort]: Local listening port for SOCKS5 inbound.
  /// [httpPort]: Local listening port for HTTP inbound.
  /// [apiPort]: Internal port for the Xray core API used for traffic stats collection.
  /// [enableUdp]: Enables UDP protocol on inbounds.
  /// [enableMux]: Enables connection multiplexing to reduce latency.
  /// [allowLan]: Allows incoming proxy connections from other LAN devices.
  /// [dnsServers]: List of DNS servers utilized by the core.
  static Map<String, dynamic> buildRuntimeConfig({
    required CoreConfig config,
    required int socksPort,
    required int httpPort,
    required int apiPort,
    required bool enableUdp,
    required bool enableMux,
    required bool allowInsecure,
    required bool allowLan,
    List<String> dnsServers = const [],
  }) {
    final raw = Map<String, dynamic>.from(config.rawJson);
    final listenAddr = allowLan ? "0.0.0.0" : "127.0.0.1";

    // Build base inbounds required on Android
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

    // Extract outbounds
    final outbounds = (raw["outbounds"] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    // Configure Mux if enabled
    if (enableMux && outbounds.isNotEmpty) {
      outbounds[0]["mux"] = {"enabled": true, "concurrency": 8};
    }

    // Configure routing rules and route stats requests to api tag
    final routing = Map<String, dynamic>.from(raw["routing"] ?? {
      "domainStrategy": "IPIfNonMatch",
      "rules": [
        {"type": "field", "inboundTag": ["api"], "outboundTag": "api"},
        {"type": "field", "outboundTag": "direct", "ip": ["geoip:private"]}
      ]
    });
    final rules = (routing["rules"] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    if (!rules.any((r) => (r["inboundTag"] as List?)?.contains("api") == true)) {
      rules.insert(0, {"type": "field", "inboundTag": ["api"], "outboundTag": "api"});
    }
    routing["rules"] = rules;

    return {
      "log": {"loglevel": Platform.isAndroid ? "none" : "warning"},
      "api": {"tag": "api", "services": ["StatsService"]},
      "stats": {},
      "policy": {
        "levels": {"0": {"statsUserUplink": true, "statsUserDownlink": true}},
        "system": {
          "statsInboundUplink": true,
          "statsInboundDownlink": true,
          "statsOutboundUplink": true,
          "statsOutboundDownlink": true
        }
      },
      "dns": {
        "servers": dnsServers.isNotEmpty ? dnsServers : ["1.1.1.1", "8.8.8.8", "localhost"]
      },
      "inbounds": inbounds,
      "outbounds": outbounds.isNotEmpty
          ? outbounds
          : [
              {"tag": "proxy", "protocol": "freedom"},
              {"tag": "direct", "protocol": "freedom"},
              {"tag": "block", "protocol": "blackhole"}
            ],
      "routing": routing
    };
  }
}
