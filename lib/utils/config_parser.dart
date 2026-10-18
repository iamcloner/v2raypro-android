// File: lib/utils/config_parser.dart
// Description: Universal proxy configuration parser.
// Parses proxy URI schemes, Base64 subscriptions, and Sing-box JSON configurations.
// Leverages background Dart isolates for responsive UI performance during batch imports.

import 'dart:convert';
import 'dart:isolate';
import '../models/proxy_node.dart';
import 'parsers/v2ray_parsers.dart';
import 'parsers/singbox_parser.dart' as sb;

export 'parsers/v2ray_parsers.dart';
export 'parsers/singbox_parser.dart';

/// Main parser and validator class for proxy configurations.
class ConfigParser {
  /// Batch-parses configurations in a background isolate to keep UI responsive.
  static Future<List<ProxyNode>> parseBatchAsync(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.length < 5000 && !trimmed.contains('\n') && !trimmed.contains('\r')) {
      return parseBatch(trimmed);
    }
    try {
      return await Isolate.run(() => parseBatch(content));
    } catch (_) {
      return parseBatch(content);
    }
  }

  /// Batch-parses lines, Base64 strings, and JSON structures.
  static List<ProxyNode> parseBatch(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final singBoxNodes = parseSingBoxConfig(trimmed);
      if (singBoxNodes.isNotEmpty) {
        return singBoxNodes;
      }
    }

    String decoded = trimmed;
    try {
      final normalized = normalizeBase64(trimmed);
      final bytes = base64Decode(normalized);
      decoded = utf8.decode(bytes);
    } catch (_) {
      decoded = trimmed;
    }

    if (decoded.trim().startsWith('{') || decoded.trim().startsWith('[')) {
      final singBoxNodes = parseSingBoxConfig(decoded.trim());
      if (singBoxNodes.isNotEmpty) {
        return singBoxNodes;
      }
    }

    final nodes = <ProxyNode>[];
    for (final rawLine in const LineSplitter().convert(decoded)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) continue;
      final node = parseSingle(line);
      if (node != null) {
        nodes.add(node);
      }
    }

    return nodes;
  }

  /// Parses an individual URL link or JSON object into a ProxyNode model.
  static ProxyNode? parseSingle(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('vless://')) {
      return parseVless(trimmed);
    } else if (trimmed.startsWith('vmess://')) {
      return parseVmess(trimmed);
    } else if (trimmed.startsWith('trojan://')) {
      return parseTrojan(trimmed);
    } else if (trimmed.startsWith('ss://')) {
      return parseShadowsocks(trimmed);
    } else if (trimmed.startsWith('sing-box://') || trimmed.startsWith('singbox://')) {
      return sb.parseSingBoxUrl(trimmed);
    } else if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('outbounds')) {
            final list = parseSingBoxConfig(trimmed);
            if (list.isNotEmpty) return list.first;
          }
          return sb.parseSingBoxOutbound(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Static helper to parse Sing-box outbound objects.
  static ProxyNode? parseSingBoxOutbound(Map<String, dynamic> map) => sb.parseSingBoxOutbound(map);

  /// Static helper to parse complete Sing-box configuration strings.
  static List<ProxyNode> parseSingBoxConfig(String jsonStr) => sb.parseSingBoxConfig(jsonStr);

  /// Converts a ProxyNode into a Sing-box outbound configuration map.
  static Map<String, dynamic> toSingBoxOutbound(ProxyNode node) => sb.toSingBoxOutbound(node);

  /// Generates a complete Sing-box configuration formatted as JSON.
  static String generateSingBoxConfig(
    ProxyNode node, {
    int inHttpPort = 10809,
    int inSocksPort = 10808,
    bool allowLan = false,
  }) =>
      sb.generateSingBoxConfig(
        node,
        inHttpPort: inHttpPort,
        inSocksPort: inSocksPort,
        allowLan: allowLan,
      );
}
