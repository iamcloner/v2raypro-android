// File: lib/utils/generators/xray_stream_builder.dart
// Description: Xray stream settings builder.
// Constructs transport layer and security specifications (TCP, WS, gRPC, XHTTP, H2, TLS, Reality, ECH).
// Maps host headers, paths, ALPN protocols, and certificate pinning SHA256 hashes.

import "dart:convert";
import "../../models/proxy_node.dart";

/// Builds transport and stream settings (StreamSettings) for the Xray core.
/// Produces transport protocol configurations along with TLS, Reality, and ECH security settings.
class XrayStreamBuilder {
  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isNotEmpty ? t : null;
  }

  /// Default global Cloudflare ECHConfigList used across Cloudflare CDN/Worker edges.
  static const String defaultCloudflareEch =
      "AGX+DQBhAAAgACBd9OOTnwnmz9l85Hm5llY4JDyLkYEk6KJjW5Q+0QZqawAkAAEAAQABAAIAAQADAAIAAQACAAIAAgADAAMAAQADAAIAAwADABJjbG91ZGZsYXJlLWVjaC5jb20AAA==";

  /// Resolves raw ECH parameter into a valid Base64-encoded ECHConfigList string.
  static String? resolveEchConfig(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    if (lower == "1" || lower == "true" || lower == "yes" || lower == "enable" || lower == "cloudflare-ech.com" || lower == "cf") {
      return defaultCloudflareEch;
    }
    return t;
  }

  /// Extracts the outer public name (e.g. cloudflare-ech.com) from an ECHConfigList.
  static String extractEchPublicName(String echB64) {
    try {
      final bytes = base64Decode(echB64);
      final rawStr = String.fromCharCodes(bytes);
      final match = RegExp(r"([a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)").firstMatch(rawStr);
      if (match != null) {
        final domain = match.group(1);
        if (domain != null && domain.length >= 4 && !domain.startsWith(".") && !domain.endsWith(".")) {
          return domain;
        }
      }
    } catch (_) {}
    return "cloudflare-ech.com";
  }

  /// Generates the complete streamSettings map based on proxy node properties.
  static Map<String, dynamic> build(ProxyNode node) {
    final effectiveSni = _nonEmpty(node.sni) ?? _nonEmpty(node.host) ?? node.address;
    final effectiveHost = _nonEmpty(node.host) ?? _nonEmpty(node.sni) ?? node.address;
    final rawPath = _nonEmpty(node.path) ?? "/";
    final safePath = rawPath.startsWith("/") ? rawPath : "/$rawPath";

    final resolvedEch = resolveEchConfig(node.echConfigList);
    final isEchEnabled = resolvedEch != null && resolvedEch.isNotEmpty;
    final rawEchLower = node.echConfigList?.trim().toLowerCase();
    final isFlagEch = rawEchLower == "1" ||
        rawEchLower == "true" ||
        rawEchLower == "yes" ||
        rawEchLower == "enable" ||
        rawEchLower == "cloudflare-ech.com" ||
        rawEchLower == "cf";
    final echPublicName = isEchEnabled ? extractEchPublicName(resolvedEch) : null;

    final String netName;
    if (node.network == NetworkType.splithttp || node.network == NetworkType.xhttp) {
      netName = "xhttp";
    } else if (node.network == NetworkType.httpUpgrade) {
      netName = "httpupgrade";
    } else {
      netName = node.network.name;
    }

    final streamSettings = <String, dynamic>{
      "network": netName,
      "security": node.security.name,
    };

    if (node.security == SecurityType.tls) {
      // In ECH, outer SNI must be public name (e.g. cloudflare-ech.com) when SNI is flag-based or omitted
      final String outerSni;
      if (isEchEnabled && echPublicName != null && (isFlagEch || _nonEmpty(node.sni) == null)) {
        outerSni = echPublicName;
      } else {
        outerSni = effectiveSni;
      }
      final tls = <String, dynamic>{
        "serverName": outerSni,
      };

      // Xray requires uTLS (e.g. chrome) for Encrypted Client Hello
      if (node.fingerprint != null && node.fingerprint!.isNotEmpty) {
        tls["fingerprint"] = node.fingerprint;
      } else if (isEchEnabled) {
        tls["fingerprint"] = "chrome";
      }

      if (node.alpn != null && node.alpn!.isNotEmpty) {
        tls["alpn"] = node.alpn;
      } else if (node.network == NetworkType.ws || node.network == NetworkType.httpUpgrade) {
        tls["alpn"] = ["http/1.1"];
      } else if (isEchEnabled) {
        tls["alpn"] = ["h2", "http/1.1"];
      }

      if (isEchEnabled) {
        tls["echConfigList"] = resolvedEch;
      }

      if (node.verifyPeerCertByName != null && node.verifyPeerCertByName!.trim().isNotEmpty) {
        tls["verifyPeerCertByName"] = node.verifyPeerCertByName!.trim();
      }

      if (node.certificatePinning != null && node.certificatePinning!.trim().isNotEmpty) {
        tls["pinnedPeerCertificatePublicKeySha256"] = node.certificatePinning!.trim();
        tls["pinnedPeerCertSha256"] = node.certificatePinning!.trim();
      }
      streamSettings["tlsSettings"] = tls;
    } else if (node.security == SecurityType.reality) {
      if (node.publicKey != null && node.publicKey!.trim().isNotEmpty) {
        final reality = <String, dynamic>{
          "serverName": effectiveSni,
          "publicKey": node.publicKey!.trim(),
          "shortId": node.shortId ?? "",
          "spiderX": _nonEmpty(node.spiderX) ?? "/",
          "fingerprint": (node.fingerprint != null && node.fingerprint!.trim().isNotEmpty)
              ? node.fingerprint!.trim()
              : "chrome",
        };
        streamSettings["realitySettings"] = reality;
      } else {
        streamSettings["security"] = "none";
      }
    }

    if (node.network == NetworkType.xhttp || node.network == NetworkType.splithttp) {
      final xhttpMap = <String, dynamic>{
        "path": safePath,
        "host": effectiveHost,
      };
      if (node.mode != null && node.mode!.isNotEmpty) {
        xhttpMap["mode"] = node.mode;
      }
      if (node.extra != null && node.extra!.isNotEmpty) {
        try {
          xhttpMap["extra"] = jsonDecode(node.extra!);
        } catch (_) {
          xhttpMap["extra"] = node.extra;
        }
      }
      streamSettings["xhttpSettings"] = xhttpMap;
    } else if (node.network == NetworkType.ws) {
      final wsMap = <String, dynamic>{
        "path": safePath,
        "host": effectiveHost,
        "headers": {"Host": effectiveHost},
      };
      if (node.extra != null && node.extra!.contains("maxEarlyData")) {
        try {
          final extraMap = jsonDecode(node.extra!) as Map<String, dynamic>;
          if (extraMap.containsKey("maxEarlyData")) {
            wsMap["maxEarlyData"] = extraMap["maxEarlyData"];
            wsMap["earlyDataHeaderName"] = extraMap["earlyDataHeaderName"] ?? "Sec-WebSocket-Protocol";
          }
        } catch (_) {}
      }
      streamSettings["wsSettings"] = wsMap;
    } else if (node.network == NetworkType.grpc) {
      streamSettings["grpcSettings"] = {
        "serviceName": node.serviceName ?? "",
        "multiMode": true,
      };
    } else if (node.network == NetworkType.h2) {
      streamSettings["httpSettings"] = {
        "path": safePath,
        "host": [effectiveHost],
      };
    } else if (node.network == NetworkType.httpUpgrade) {
      streamSettings["httpupgradeSettings"] = {
        "path": safePath,
        "host": effectiveHost,
      };
    }

    streamSettings["sockopt"] = {"tcpNoDelay": true};
    return streamSettings;
  }
}
