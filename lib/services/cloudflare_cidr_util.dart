// Cloudflare CIDR & IP Sampling Utility
// Provides mathematical subnet parsing, random IP sampling, and range verification for Cloudflare networks.
// Supports custom CIDR overrides, hostname resolution caching, and known edge suffix detection.
// Formatted with optimized bitwise operations for high-performance scanning on Android.

import "dart:async";
import "dart:io";
import "dart:math";

/// Utility for processing and validating Cloudflare network IP ranges (CIDRs).
/// Handles random subnet sampling and Cloudflare IP membership verification.
abstract class CloudflareCidrUtil {
  static const List<String> defaultCidrs = [
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "162.158.0.0/15",
    "198.41.128.0/17",
    "173.245.48.0/20",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "141.101.64.0/18",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "131.0.72.0/22",
    "162.159.0.0/16",
    "1.0.0.0/24",
    "1.1.1.0/24",
    "8.6.112.0/24",
  ];

  static const List<String> cfSubnets = [
    "104.16.",
    "104.17.",
    "104.18.",
    "104.19.",
    "104.20.",
    "104.21.",
    "172.64.",
    "172.65.",
    "172.66.",
    "172.67.",
    "162.158.",
    "162.159.",
    "108.162.",
    "198.41.",
    "173.245.",
    "8.6.112.",
  ];

  static final Map<String, bool> _domainCfCache = {};

  /// Mathematically samples a random usable IP address from a CIDR range.
  static String sampleIpFromCidr(String cidr, Random rng) {
    try {
      final parts = cidr.trim().split('/');
      final ipParts = parts[0].split('.').map(int.parse).toList();
      if (ipParts.length != 4) throw const FormatException();

      final prefixLength = parts.length > 1 ? int.parse(parts[1]) : 32;
      if (prefixLength < 0 || prefixLength > 32) throw const FormatException();

      int baseIp = (ipParts[0] << 24) | (ipParts[1] << 16) | (ipParts[2] << 8) | ipParts[3];
      final hostBits = 32 - prefixLength;

      if (hostBits <= 1) {
        return parts[0];
      }

      final hostCount = 1 << hostBits;
      final offset = (hostBits > 2) ? (rng.nextInt(hostCount - 2) + 1) : rng.nextInt(hostCount);
      final sampledIp = (baseIp & (~((1 << hostBits) - 1))) | offset;

      final o1 = (sampledIp >> 24) & 0xFF;
      final o2 = (sampledIp >> 16) & 0xFF;
      final o3 = (sampledIp >> 8) & 0xFF;
      final o4 = sampledIp & 0xFF;

      return "$o1.$o2.$o3.$o4";
    } catch (_) {
      if (cidr.contains('.')) {
        final raw = cidr.split('/')[0].trim();
        final segs = raw.split('.');
        if (segs.length >= 2) {
          return "${segs[0]}.${segs[1]}.${rng.nextInt(250) + 1}.${rng.nextInt(254) + 1}";
        }
      }
      return "104.18.${rng.nextInt(250) + 1}.${rng.nextInt(254) + 1}";
    }
  }

  /// Verifies whether an IP address belongs to default or custom Cloudflare CIDR ranges.
  static bool isCloudflareIp(String ip, [List<String>? cidrs]) {
    final targetIp = ip.trim();
    final parts = targetIp.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    final int ipInt = (parts[0]! << 24) | (parts[1]! << 16) | (parts[2]! << 8) | parts[3]!;
    final ranges = (cidrs != null && cidrs.isNotEmpty) ? cidrs : defaultCidrs;

    for (final cidr in ranges) {
      try {
        final cidrParts = cidr.trim().split('/');
        final baseParts = cidrParts[0].split('.').map(int.tryParse).toList();
        if (baseParts.length != 4 || baseParts.any((p) => p == null)) continue;

        final prefixLen = cidrParts.length > 1 ? int.parse(cidrParts[1]) : 32;
        if (prefixLen < 0 || prefixLen > 32) continue;

        final int baseInt = (baseParts[0]! << 24) | (baseParts[1]! << 16) | (baseParts[2]! << 8) | baseParts[3]!;
        final int mask = prefixLen == 0 ? 0 : (~0 << (32 - prefixLen));

        if ((ipInt & mask) == (baseInt & mask)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Synchronously checks if a host or domain belongs to Cloudflare via known suffixes or cache.
  static bool isCloudflareHostSync(String host, [List<String>? cidrs]) {
    final clean = host.trim().toLowerCase();
    if (_domainCfCache.containsKey(clean)) {
      return _domainCfCache[clean]!;
    }
    if (isCloudflareIp(clean, cidrs)) {
      _domainCfCache[clean] = true;
      return true;
    }
    if (clean == 'cloudflare.com' ||
        clean.endsWith('.cloudflare.com') ||
        clean == 'workers.dev' ||
        clean.endsWith('.workers.dev') ||
        clean == 'pages.dev' ||
        clean.endsWith('.pages.dev') ||
        clean.endsWith('.cfargotunnel.com')) {
      _domainCfCache[clean] = true;
      return true;
    }
    return false;
  }

  /// Asynchronously resolves and verifies domain membership in Cloudflare servers via DNS.
  static Future<bool> resolveAndCheckCloudflare(String host, [List<String>? cidrs]) async {
    final clean = host.trim().toLowerCase();
    if (_domainCfCache.containsKey(clean)) {
      return _domainCfCache[clean]!;
    }
    if (isCloudflareHostSync(clean, cidrs)) {
      _domainCfCache[clean] = true;
      return true;
    }

    try {
      final addresses = await InternetAddress.lookup(clean).timeout(const Duration(seconds: 3));
      for (final addr in addresses) {
        if (isCloudflareIp(addr.address, cidrs)) {
          _domainCfCache[clean] = true;
          return true;
        }
      }
    } catch (_) {}

    _domainCfCache[clean] = false;
    return false;
  }

  /// Generates a randomized, shuffled list of candidate IPs from Cloudflare CIDR ranges.
  static List<String> generateCandidateIps({
    required int count,
    List<String>? cidrs,
    Random? rng,
  }) {
    final rand = rng ?? Random();
    final ranges = (cidrs != null && cidrs.isNotEmpty) ? cidrs : defaultCidrs;
    final Set<String> candidates = {};

    int attempts = 0;
    while (candidates.length < count && attempts < count * 80) {
      attempts++;
      final cidr = ranges[rand.nextInt(ranges.length)];
      final ip = sampleIpFromCidr(cidr, rand);
      candidates.add(ip);
    }

    final list = candidates.toList();
    list.shuffle(rand);
    return list;
  }
}
