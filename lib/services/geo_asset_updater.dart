// =======================================================================
// [File Name]: geo_asset_updater.dart
// [Description]: Dedicated module for downloading and updating geo database files (geoip.dat and geosite.dat).
// Downloads the latest routing and geographical separation rules from the Loyalsoldier repository
// and replaces them in the core static asset directory on the Android device storage.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";
import "../models/update_info.dart";
import "xray_process_service.dart";

/// Service provider for querying and updating geo data assets (GeoIP/GeoSite) on Android.
class GeoAssetUpdater {
  /// Checks for newer releases of geo data files in the official Loyalsoldier repository.
  static Future<UpdateInfo> checkGeoUpdate({
    required HttpClient Function() clientFactory,
  }) async {
    String current = "Installed";
    final androidDir = XrayProcessService.instance.androidAssetDir;
    if (androidDir != null) {
      final geoip = File("${androidDir.path}/geoip.dat");
      if (geoip.existsSync()) {
        final modified = geoip.lastModifiedSync();
        current = "${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}";
      }
    }

    final client = clientFactory();
    try {
      final req = await client.getUrl(Uri.parse("https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest"));
      req.headers.set(HttpHeaders.userAgentHeader, "V2RayPro-Android/1.3.2");
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tagName = (json["tag_name"] as String? ?? "").trim();
        return UpdateInfo(
          currentVersion: current,
          latestVersion: tagName.isNotEmpty ? tagName : "Latest Release",
          hasUpdate: true,
          downloadUrl: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download",
        );
      }
    } catch (e) {
      debugPrint("checkGeoUpdate error: $e");
    } finally {
      client.close();
    }

    return UpdateInfo(
      currentVersion: current,
      latestVersion: "Available on GitHub",
      hasUpdate: true,
      downloadUrl: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download",
    );
  }

  /// Downloads geoip.dat and geosite.dat files and deploys them to the Android assets directory.
  static Future<bool> updateGeoFiles({
    required HttpClient Function() clientFactory,
    void Function(double progress)? onProgress,
  }) async {
    final client = clientFactory();
    try {
      final tempDir = await getTemporaryDirectory();
      const geoipUrl = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat";
      const geositeUrl = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat";

      final tempGeoip = File("${tempDir.path}/geoip_temp.dat");
      final tempGeosite = File("${tempDir.path}/geosite_temp.dat");

      final req1 = await client.getUrl(Uri.parse(geoipUrl));
      final res1 = await req1.close();
      if (res1.statusCode != 200 && res1.statusCode != 302) return false;
      final sink1 = tempGeoip.openWrite();
      await res1.pipe(sink1);
      onProgress?.call(0.5);

      final req2 = await client.getUrl(Uri.parse(geositeUrl));
      final res2 = await req2.close();
      if (res2.statusCode != 200 && res2.statusCode != 302) return false;
      final sink2 = tempGeosite.openWrite();
      await res2.pipe(sink2);
      onProgress?.call(1.0);

      final targets = <File>[];
      final androidDir = XrayProcessService.instance.androidAssetDir;
      if (androidDir != null) {
        targets.add(File("${androidDir.path}/geoip.dat"));
        targets.add(File("${androidDir.path}/geosite.dat"));
      }
      targets.add(File("assets/bin/geoip.dat"));
      targets.add(File("assets/bin/geosite.dat"));

      for (final t in targets) {
        if (t.path.contains("geoip") && t.existsSync()) {
          try { await tempGeoip.copy(t.path); } catch (_) {}
        } else if (t.path.contains("geosite") && t.existsSync()) {
          try { await tempGeosite.copy(t.path); } catch (_) {}
        }
      }

      try {
        if (await tempGeoip.exists()) await tempGeoip.delete();
        if (await tempGeosite.exists()) await tempGeosite.delete();
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint("updateGeoFiles failed: $e");
      return false;
    } finally {
      client.close();
    }
  }
}
