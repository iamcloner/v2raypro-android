// =======================================================================
// [File Name]: local_geoip.dart
// [Description]: Offline GeoIP database evaluation service using geoip.dat on Android.
// Reads binary database bytes, sorts numerical IP ranges, and extracts
// the country code for any IP address using a fast binary search algorithm.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:io";
import "dart:typed_data";
import "xray_process_service.dart";

/// Numerical range of IP addresses mapped to a country index.
class _GeoRange {
  final int start;
  final int end;
  final int prefix;
  final int countryIndex;
  _GeoRange(this.start, this.end, this.prefix, this.countryIndex);
}

/// Local, completely offline geolocation analysis service based on the GeoIP database on Android.
class LocalGeoIp {
  /// Singleton instance of LocalGeoIp.
  static final LocalGeoIp instance = LocalGeoIp._internal();
  LocalGeoIp._internal();

  bool _loaded = false;
  bool _loading = false;
  Uint32List? _startArr;
  Uint32List? _endArr;
  Uint16List? _cIdxArr;
  final List<String> _countryCodes = [];

  /// Locates the geoip.dat database file within Android internal storage and app assets.
  static String? findGeoIpDatPath() {
    try {
      final androidDir = XrayProcessService.instance.androidAssetDir;
      if (androidDir != null) {
        final candidate = "${androidDir.path}/geoip.dat";
        if (File(candidate).existsSync()) return candidate;
      }
      final candidates = [
        "assets/bin/geoip.dat",
        "flutter/assets/bin/geoip.dat",
        "geoip.dat",
        "xray/geoip.dat",
      ];
      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
    } catch (_) {}
    return null;
  }

  /// Loads and parses geoip binary records into memory using an optimized array structure.
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final path = findGeoIpDatPath();
      if (path == null) {
        _loading = false;
        return;
      }
      final file = File(path);
      if (!file.existsSync()) {
        _loading = false;
        return;
      }

      final bytes = await file.readAsBytes();
      int offset = 0;

      final ranges = <_GeoRange>[];
      final cMap = <String, int>{};

      while (offset < bytes.length) {
        final tag = bytes[offset++];
        final fieldNum = tag >> 3;
        final wireType = tag & 0x07;
        if (fieldNum == 1 && wireType == 2) {
          int len = 0, shift = 0;
          while (true) {
            final b = bytes[offset++];
            len |= (b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
          }
          final end = offset + len;
          String countryCode = "";
          int cIndex = -1;
          while (offset < end) {
            final entryTag = bytes[offset++];
            final entryField = entryTag >> 3;
            final entryWire = entryTag & 0x07;
            if (entryField == 1 && entryWire == 2) {
              int strLen = 0, sShift = 0;
              while (true) {
                final b = bytes[offset++];
                strLen |= (b & 0x7F) << sShift;
                if ((b & 0x80) == 0) break;
                sShift += 7;
              }
              countryCode = String.fromCharCodes(bytes.sublist(offset, offset + strLen)).toUpperCase();
              offset += strLen;
              if (countryCode.length == 2) {
                if (!cMap.containsKey(countryCode)) {
                  cMap[countryCode] = _countryCodes.length;
                  _countryCodes.add(countryCode);
                }
                cIndex = cMap[countryCode]!;
              } else {
                cIndex = -1;
              }
            } else if (entryField == 2 && entryWire == 2) {
              int cLen = 0, cShift = 0;
              while (true) {
                final b = bytes[offset++];
                cLen |= (b & 0x7F) << cShift;
                if ((b & 0x80) == 0) break;
                cShift += 7;
              }
              final cEnd = offset + cLen;
              if (cIndex < 0) {
                offset = cEnd;
                continue;
              }
              List<int>? ipBytes;
              int prefix = 32;
              while (offset < cEnd) {
                final cfTag = bytes[offset++];
                final cfField = cfTag >> 3;
                final cfWire = cfTag & 0x07;
                if (cfField == 1 && cfWire == 2) {
                  int ipLen = 0, iShift = 0;
                  while (true) {
                    final b = bytes[offset++];
                    ipLen |= (b & 0x7F) << iShift;
                    if ((b & 0x80) == 0) break;
                    iShift += 7;
                  }
                  ipBytes = bytes.sublist(offset, offset + ipLen);
                  offset += ipLen;
                } else if (cfField == 2 && cfWire == 0) {
                  int pVal = 0, pShift = 0;
                  while (true) {
                    final b = bytes[offset++];
                    pVal |= (b & 0x7F) << pShift;
                    if ((b & 0x80) == 0) break;
                    pShift += 7;
                  }
                  prefix = pVal;
                }
              }
              if (ipBytes != null && ipBytes.length == 4) {
                int ipNum = ((ipBytes[0] << 24) | (ipBytes[1] << 16) | (ipBytes[2] << 8) | ipBytes[3]) & 0xFFFFFFFF;
                int mask = prefix == 0 ? 0 : ((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF);
                int start = ipNum & mask;
                int endRange = (start | (~mask & 0xFFFFFFFF)) & 0xFFFFFFFF;
                ranges.add(_GeoRange(start, endRange, prefix, cIndex));
              }
            } else {
              if (entryWire == 0) while ((bytes[offset++] & 0x80) != 0) {}
              else if (entryWire == 2) {
                int sLen = 0, sShift = 0;
                while (true) {
                  final b = bytes[offset++];
                  sLen |= (b & 0x7F) << sShift;
                  if ((b & 0x80) == 0) break;
                  sShift += 7;
                }
                offset += sLen;
              }
            }
          }
        }
      }

      ranges.sort((a, b) {
        final c = a.start.compareTo(b.start);
        if (c != 0) return c;
        return b.prefix.compareTo(a.prefix);
      });

      final n = ranges.length;
      _startArr = Uint32List(n);
      _endArr = Uint32List(n);
      _cIdxArr = Uint16List(n);
      for (int i = 0; i < n; i++) {
        _startArr![i] = ranges[i].start;
        _endArr![i] = ranges[i].end;
        _cIdxArr![i] = ranges[i].countryIndex;
      }
      _loaded = true;
    } catch (_) {} finally {
      _loading = false;
    }
  }

  /// Fast binary search lookup for a two-letter country code matching an IP address.
  String? lookup(String ipStr) {
    if (!_loaded || _startArr == null) return null;
    final parts = ipStr.trim().split(".");
    if (parts.length != 4) return null;
    final b0 = int.tryParse(parts[0]);
    final b1 = int.tryParse(parts[1]);
    final b2 = int.tryParse(parts[2]);
    final b3 = int.tryParse(parts[3]);
    if (b0 == null || b1 == null || b2 == null || b3 == null) return null;
    final target = ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & 0xFFFFFFFF;

    int low = 0;
    int high = _startArr!.length - 1;
    int match = -1;

    while (low <= high) {
      int mid = (low + high) >> 1;
      int s = _startArr![mid];
      if (s <= target) {
        if (target <= _endArr![mid]) {
          match = mid;
        }
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (match >= 0) return _countryCodes[_cIdxArr![match]];
    return null;
  }
}
