// Nodes Sanitization & Matching Utility
// Utility module for ID sanitization, country code validation, and smart config matching.
// Helps reduce node provider size and isolates algorithmic computation tasks.

import 'package:uuid/uuid.dart';
import '../models/proxy_node.dart';
import '../services/country_service.dart';

/// Validates unique IDs and cleans up legacy false country flags caused by Cloudflare ranges.
List<ProxyNode> sanitizeSavedNodes(List<ProxyNode> saved) {
  final seenIds = <String>{};
  bool hasActive = false;
  final fixed = <ProxyNode>[];

  for (final n in saved) {
    String uniqueId = n.id;
    if (seenIds.contains(uniqueId) || uniqueId.isEmpty) {
      uniqueId = const Uuid().v4();
    }
    seenIds.add(uniqueId);

    bool active = n.isActive;
    if (active) {
      if (hasActive) {
        active = false;
      } else {
        hasActive = true;
      }
    }

    String? cCode = n.countryCode;
    String? cName = n.country;
    if (cCode == 'US' && CountryService.extractCountryCodeFromName(n.name) != 'US') {
      final addr = n.address.trim().toLowerCase();
      final isCdnOrCloudflare = addr.startsWith('104.') ||
          addr.startsWith('172.6') ||
          addr.startsWith('188.114.') ||
          addr.startsWith('162.159.') ||
          addr.startsWith('8.6.') ||
          addr.contains('fastly') ||
          addr.contains('cloudflare') ||
          CountryService.isCdnOrCloudflare(addr);
      if (isCdnOrCloudflare || n.subscriptionId == 'free_configs') {
        cCode = null;
        cName = null;
      }
    }

    fixed.add(n.copyWith(
      id: uniqueId,
      isActive: active,
      countryCode: cCode,
      country: cName,
    ));
  }

  if (fixed.isNotEmpty && !hasActive) {
    fixed[0] = fixed[0].copyWith(isActive: true);
  }
  return fixed;
}

/// Generates a unique comparison key for each node for O(1) matching in subscriptions.
String makeConfigKey(ProxyNode n) =>
    "${n.protocol.name}|${n.address.trim().toLowerCase()}|${n.port}|${n.uuidOrPassword.trim()}|${n.network.name}|${(n.path ?? '').trim()}";
