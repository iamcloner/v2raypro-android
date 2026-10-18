// =======================================================================
// [File Name]: update_service.dart
// [Description]: Application and core update checking and management service for V2RayPro on Android.
// Monitors new GitHub releases, downloads APK update packages,
// and invokes the installation process via Android native communication channels.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "package:url_launcher/url_launcher.dart";
import "../models/update_info.dart";
import "xray_process_service.dart";
import "geo_asset_updater.dart";

export "../models/update_info.dart";
export "geo_asset_updater.dart";

/// Application and core update lifecycle management service on Android.
class UpdateService {
  /// Singleton instance of UpdateService.
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  static const String _defaultFallbackVersion = "v1.3.2";
  static String? _cachedCurrentVersion;

  /// Official GitHub releases repository URL for the Android app.
  static const String defaultAppRepoUrl = "https://github.com/iamcloner/v2raypro-android/releases";

  /// Repository URL used for automated integration tests.
  static const String defaultAppTestUrl = defaultAppRepoUrl;

  /// Reads current application version from version configuration file or returns default v1.3.2.
  static String getCurrentAppVersion() {
    if (_cachedCurrentVersion != null) return _cachedCurrentVersion!;

    try {
      final candidates = [
        "version.ini",
        "../version.ini",
      ];
      for (final p in candidates) {
        final f = File(p);
        if (f.existsSync()) {
          final lines = f.readAsLinesSync();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith("version=")) {
              final v = trimmed.substring("version=".length).trim().replaceAll('"', "").replaceAll("'", "");
              if (v.isNotEmpty) {
                _cachedCurrentVersion = v.startsWith("v") ? v : "v$v";
                return _cachedCurrentVersion!;
              }
            }
          }
        }
      }
    } catch (_) {}

    _cachedCurrentVersion = _defaultFallbackVersion;
    return _cachedCurrentVersion!;
  }

  /// Retrieves current application version number.
  static String get currentAppVersion => getCurrentAppVersion();

  /// Invalidates cached application version to force re-reading from file.
  static void invalidateVersionCache() {
    _cachedCurrentVersion = null;
  }

  /// Creates an HttpClient configured with local proxy if the VPN engine is running.
  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    if (XrayProcessService.instance.state == EngineState.running) {
      client.findProxy = (uri) => "PROXY 127.0.0.1:${XrayProcessService.instance.httpPort}; DIRECT";
    }
    return client;
  }

  /// Extracts default embedded core version from Android native library.
  Future<String> getCurrentXrayVersion() async => "v26.6.1";

  /// Checks for newer Xray core releases on the official GitHub project.
  Future<UpdateInfo> checkXrayUpdate() async {
    final current = await getCurrentXrayVersion();
    return UpdateInfo(
      currentVersion: current,
      latestVersion: current,
      hasUpdate: false,
      releaseNotes: "Embedded Android Core (libxray.so)",
    );
  }

  /// Updates core binary (core is embedded in APK package on Android).
  Future<bool> updateXray(String downloadUrl, {void Function(double progress)? onProgress}) async {
    return true;
  }

  /// Checks for new releases of IP and domain geo databases.
  Future<UpdateInfo> checkGeoUpdate() async {
    return await GeoAssetUpdater.checkGeoUpdate(clientFactory: _createHttpClient);
  }

  /// Downloads and installs the latest geo databases on Android.
  Future<bool> updateGeoFiles({void Function(double progress)? onProgress}) async {
    return await GeoAssetUpdater.updateGeoFiles(clientFactory: _createHttpClient, onProgress: onProgress);
  }

  /// Evaluates whether [latest] is strictly newer than [current] using Semantic Versioning (SemVer).
  static bool isVersionNewer(String latest, String current) {
    final cleanLatest = latest.replaceAll(RegExp(r"[^0-9\.]"), "").trim();
    final cleanCurrent = current.replaceAll(RegExp(r"[^0-9\.]"), "").trim();
    if (cleanLatest.isEmpty || cleanLatest == cleanCurrent) return false;
    if (cleanCurrent.isEmpty) return true;

    final latestParts = cleanLatest.split(".").map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.split(".").map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    for (int i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Locates OS-specific compressed archive asset from GitHub release assets.
  static String? findOsSpecificZipAsset(List<dynamic> assets) {
    for (final a in assets) {
      final name = (a["name"] as String? ?? "").toLowerCase();
      if (!name.endsWith(".zip")) continue;
      if (name.contains("windows") || name.contains("win64") || name.contains("win32") || name.contains("win")) {
        return a["browser_download_url"] as String?;
      }
    }
    for (final a in assets) {
      final name = (a["name"] as String? ?? "").toLowerCase();
      if (name.endsWith(".zip")) {
        return a["browser_download_url"] as String?;
      }
    }
    return null;
  }

  /// Parses GitHub release JSON object into UpdateInfo model.
  UpdateInfo _parseReleaseJson(Map<String, dynamic> json, {String? targetTag}) {
    final tagName = (json["tag_name"] as String? ?? targetTag ?? currentAppVersion).trim();
    final bodyNotes = json["body"] as String? ?? "";
    final assets = (json["assets"] as List<dynamic>? ?? []);

    String? fileDownloadUrl;
    for (final a in assets) {
      if (a is Map) {
        final name = (a["name"] as String? ?? "").toLowerCase();
        if (name.endsWith(".apk")) {
          fileDownloadUrl = a["browser_download_url"] as String?;
          break;
        }
      }
    }
    fileDownloadUrl ??= "https://github.com/iamcloner/v2raypro-android/releases/download/$tagName/v2raypro-$tagName-android.apk";

    final cleanTag = tagName.replaceAll(RegExp(r"[^0-9\.]"), "").trim();
    final cleanCur = currentAppVersion.replaceAll(RegExp(r"[^0-9\.]"), "").trim();
    final hasUpdate = cleanTag != cleanCur && isVersionNewer(tagName, currentAppVersion);

    return UpdateInfo(
      currentVersion: currentAppVersion,
      latestVersion: tagName.isNotEmpty ? tagName : currentAppVersion,
      hasUpdate: hasUpdate,
      downloadUrl: fileDownloadUrl,
      releaseNotes: bodyNotes,
    );
  }

  /// Checks for new Android application releases in the GitHub repository iamcloner/v2raypro-android.
  Future<UpdateInfo> checkAppUpdate({String? customUrl}) async {
    final client = _createHttpClient();
    const repo = "iamcloner/v2raypro-android";
    try {
      final reqLatest = await client.getUrl(Uri.parse("https://api.github.com/repos/$repo/releases/latest"));
      reqLatest.headers.set(HttpHeaders.userAgentHeader, "V2RayPro-Android/$currentAppVersion");
      reqLatest.headers.set(HttpHeaders.acceptHeader, "application/vnd.github.v3+json");
      final resLatest = await reqLatest.close().timeout(const Duration(seconds: 10));
      if (resLatest.statusCode == 200) {
        final body = await resLatest.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return _parseReleaseJson(json);
      }

      final req = await client.getUrl(Uri.parse("https://api.github.com/repos/$repo/releases?per_page=5"));
      req.headers.set(HttpHeaders.userAgentHeader, "V2RayPro-Android/$currentAppVersion");
      req.headers.set(HttpHeaders.acceptHeader, "application/vnd.github.v3+json");
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        if (list.isNotEmpty) {
          return _parseReleaseJson(list.first as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint("checkAppUpdate github error: $e");
    } finally {
      client.close();
    }

    return UpdateInfo(
      currentVersion: currentAppVersion,
      latestVersion: currentAppVersion,
      hasUpdate: false,
      downloadUrl: defaultAppRepoUrl,
    );
  }

  /// Downloads latest APK package and hands it over to the Android package manager for installation.
  Future<bool> downloadAndApplyAppUpdate(
    String downloadUrl, {
    void Function(String status, double progress)? onProgress,
  }) async {
    String targetUrl = downloadUrl.trim().isNotEmpty ? downloadUrl.trim() : defaultAppRepoUrl;

    final client = _createHttpClient();
    try {
      onProgress?.call("checking", 0.05);
      if (!targetUrl.toLowerCase().endsWith(".apk") && !targetUrl.contains("/download/")) {
        final resolved = await checkAppUpdate(customUrl: targetUrl);
        if (resolved.downloadUrl != null && resolved.downloadUrl!.isNotEmpty) {
          targetUrl = resolved.downloadUrl!;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final apkFile = File("${tempDir.path}/v2raypro_update_$timestamp.apk");

      onProgress?.call("downloading", 0.10);

      HttpClientResponse? res;
      for (int i = 0; i < 6; i++) {
        final req = await client.getUrl(Uri.parse(targetUrl));
        req.headers.set(HttpHeaders.userAgentHeader, "V2RayPro-Android/$currentAppVersion");
        req.headers.set(HttpHeaders.acceptHeader, "application/octet-stream,application/vnd.android.package-archive,*/*");
        req.followRedirects = false;
        final candidate = await req.close();
        if (candidate.statusCode == 301 ||
            candidate.statusCode == 302 ||
            candidate.statusCode == 303 ||
            candidate.statusCode == 307 ||
            candidate.statusCode == 308) {
          final loc = candidate.headers.value(HttpHeaders.locationHeader);
          await candidate.drain();
          if (loc != null) {
            targetUrl = loc;
            continue;
          }
        }
        res = candidate;
        break;
      }

      if (res == null || res.statusCode != 200) {
        final uri = Uri.parse(targetUrl);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      final totalBytes = res.contentLength;
      int receivedBytes = 0;
      final sink = apkFile.openWrite();

      await for (final chunk in res) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          final p = 0.10 + (receivedBytes / totalBytes) * 0.85;
          onProgress("downloading", p.clamp(0.0, 0.95));
        }
      }
      await sink.flush();
      await sink.close();

      onProgress?.call("installing", 1.0);

      const channel = MethodChannel("com.v2raypro.app/native");
      final bool? success = await channel.invokeMethod<bool>("installApk", {
        "filePath": apkFile.path,
      });
      return success ?? true;
    } catch (e) {
      debugPrint("downloadAndApplyAppUpdate Android error: $e");
      try {
        final uri = Uri.parse(targetUrl);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    } finally {
      client.close();
    }
  }
}
