// =======================================================================
// [File Name]: country_service.dart
// [Description]: Comprehensive country location and flag resolution service on Android.
// Identifies node country via composite analysis of name (flag emoji/embedded code),
// domain/SNI, datacenter IP address, or completely offline local GeoIP lookups.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:io";
import "../models/proxy_node.dart";
import "cdn_scanner_service.dart";
import "cloudflare_scanner_service.dart";
import "local_geoip.dart";
import "country_names_data.dart";

export "local_geoip.dart";
export "country_names_data.dart";

/// Service identifying node location and server addresses based on static and geo data on Android.
class CountryService {
  /// Singleton instance of country resolution service.
  static final CountryService instance = CountryService();

  static final Map<String, String> _cache = {};

  /// Initializes the service and loads the local geoip database into memory.
  static void init() {
    LocalGeoIp.instance.ensureLoaded();
  }

  /// Extracts two-letter country code from flag emojis in text (e.g. 🇩🇪 to DE).
  static String? extractFlagEmoji(String text) {
    for (int i = 0; i < text.length - 1; i++) {
      final code1 = text.codeUnitAt(i);
      final code2 = text.codeUnitAt(i + 1);
      if (code1 == 0xD83C && code2 >= 0xDDE6 && code2 <= 0xDDFF && i + 3 < text.length) {
        final c1 = String.fromCharCode(65 + (text.codeUnitAt(i + 1) - 0xDDE6));
        final c2 = String.fromCharCode(65 + (text.codeUnitAt(i + 3) - 0xDDE6));
        return "$c1$c2".toUpperCase();
      }
    }
    return null;
  }

  /// Extracts two-letter country code from config name by inspecting flags, brackets ([DE], (US)), or country names.
  static String? extractCountryCodeFromName(String name) {
    if (name.isEmpty) return null;

    final flag = extractFlagEmoji(name);
    if (flag != null) return flag;

    final upper = name.toUpperCase();
    final codeRegex = RegExp(r"(?:\[|\(|\b)([A-Z]{2})(?:\]|\)|\s*[-_:])");
    final match = codeRegex.firstMatch(upper);
    if (match != null) {
      final code = match.group(1);
      if (code != null && CountryNamesData.knownCountryCodes.contains(code)) {
        return code;
      }
    }

    for (final entry in CountryNamesData.countryNameToCode.entries) {
      if (upper.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Extracts country code from host domain TLD (e.g. server.de -> DE).
  static String? extractCountryFromHost(String host) {
    final lower = host.trim().toLowerCase();
    final parts = lower.split(".");
    if (parts.length >= 2) {
      final tld = parts.last.toUpperCase();
      if (tld.length == 2 && CountryNamesData.knownCountryCodes.contains(tld) && tld != "CO" && tld != "IO" && tld != "ME" && tld != "TV") {
        return tld;
      }
    }
    return null;
  }

  /// Checks whether an address belongs to Cloudflare Anycast or known CDN networks.
  static bool isCdnOrCloudflare(String address) {
    final clean = address.trim().toLowerCase();
    if (CloudflareScannerService.isCloudflareHostSync(clean)) return true;
    if (CdnScannerService.detectCdnHostSync(clean) != null) return true;
    if (clean.startsWith("104.") ||
        clean.startsWith("172.6") ||
        clean.startsWith("188.114.") ||
        clean.startsWith("162.159.") ||
        clean.startsWith("8.6.")) {
      return true;
    }
    return false;
  }

  /// Synchronously and immediately resolves node country code based on remark, SNI, or local cache without network delay.
  static String? resolveSync(ProxyNode node) {
    if (node.countryCode != null && node.countryCode!.trim().length == 2) {
      return node.countryCode!.trim().toUpperCase();
    }
    final fromName = extractCountryCodeFromName(node.name);
    if (fromName != null) return fromName;

    final addr = node.address.trim().toLowerCase();
    if (_cache.containsKey(addr)) return _cache[addr];

    if (isCdnOrCloudflare(addr)) {
      if (node.host != null && node.host!.isNotEmpty) {
        final fromHost = extractCountryFromHost(node.host!) ?? extractCountryCodeFromName(node.host!);
        if (fromHost != null) return fromHost;
      }
      if (node.sni != null && node.sni!.isNotEmpty) {
        final fromSni = extractCountryFromHost(node.sni!) ?? extractCountryCodeFromName(node.sni!);
        if (fromSni != null) return fromSni;
      }
      return null;
    }

    final fromHost = extractCountryFromHost(addr);
    if (fromHost != null) return fromHost;

    if (node.host != null && node.host!.isNotEmpty) {
      final fromH = extractCountryFromHost(node.host!) ?? extractCountryCodeFromName(node.host!);
      if (fromH != null) return fromH;
    }
    if (node.sni != null && node.sni!.isNotEmpty) {
      final fromS = extractCountryFromHost(node.sni!) ?? extractCountryCodeFromName(node.sni!);
      if (fromS != null) return fromS;
    }

    final localCode = LocalGeoIp.instance.lookup(addr);
    if (localCode != null) {
      if (localCode == "IR") {
        final fromMeta = (node.host != null ? extractCountryFromHost(node.host!) : null) ??
                         (node.sni != null ? extractCountryFromHost(node.sni!) : null) ??
                         extractCountryCodeFromName(node.name);
        return fromMeta;
      }
      _cache[addr] = localCode;
      return localCode;
    }

    return null;
  }

  /// Asynchronously and decisively resolves node country code via offline Android GeoIP database lookup.
  Future<String?> resolveCountryCode(ProxyNode node) async {
    if (node.countryCode != null && node.countryCode!.trim().length == 2) {
      return node.countryCode!.trim().toUpperCase();
    }

    final fromName = extractCountryCodeFromName(node.name);
    if (fromName != null) {
      _cache[node.address.trim().toLowerCase()] = fromName;
      return fromName;
    }

    final addr = node.address.trim().toLowerCase();
    if (_cache.containsKey(addr)) {
      return _cache[addr];
    }

    if (isCdnOrCloudflare(addr)) {
      if (node.host != null && node.host!.isNotEmpty) {
        final fromH = extractCountryFromHost(node.host!) ?? extractCountryCodeFromName(node.host!);
        if (fromH != null) {
          _cache[addr] = fromH;
          return fromH;
        }
      }
      if (node.sni != null && node.sni!.isNotEmpty) {
        final fromS = extractCountryFromHost(node.sni!) ?? extractCountryCodeFromName(node.sni!);
        if (fromS != null) {
          _cache[addr] = fromS;
          return fromS;
        }
      }
      return null;
    }

    final fromHost = extractCountryFromHost(addr);
    if (fromHost != null) {
      _cache[addr] = fromHost;
      return fromHost;
    }

    await LocalGeoIp.instance.ensureLoaded();

    String ip = addr;
    if (!RegExp(r"^\d+\.\d+\.\d+\.\d+$").hasMatch(addr)) {
      try {
        final lookup = await InternetAddress.lookup(addr).timeout(const Duration(seconds: 1));
        if (lookup.isNotEmpty) {
          ip = lookup.first.address;
          if (isCdnOrCloudflare(ip)) {
            return null;
          }
        }
      } catch (_) {}
    }

    final localCode = LocalGeoIp.instance.lookup(ip);
    if (localCode != null && localCode.length == 2) {
      if (localCode == "IR") {
        final fromMeta = (node.host != null ? extractCountryFromHost(node.host!) : null) ??
                         (node.sni != null ? extractCountryFromHost(node.sni!) : null) ??
                         extractCountryCodeFromName(node.name);
        if (fromMeta != null) {
          _cache[addr] = fromMeta;
          return fromMeta;
        }
        return null;
      }
      _cache[addr] = localCode;
      return localCode;
    }

    return null;
  }

  /// Retrieves standard English country name from a two-letter code.
  static String? getCountryName(String? code) => CountryNamesData.getCountryName(code);
}
