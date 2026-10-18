// =======================================================================
// [File Name]: temp_proxy_runner.dart
// [Description]: Manages temporary Xray process instances for background latency testing and exit IP discovery.
// Runs test configurations on dedicated ports and cleans up resources once testing completes.
// [Platform]: Android Native Proxy Testing
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "../models/service_models.dart";
import "country_service.dart";
import "local_geoip.dart";

/// Manages execution of temporary Xray proxy instances for accurate configuration latency evaluation.
class TempProxyRunner {
  /// Singleton instance of TempProxyRunner.
  static final TempProxyRunner instance = TempProxyRunner._internal();
  TempProxyRunner._internal();

  /// Launches a temporary Xray process on a dedicated port to route ping test traffic.
  Future<TemporaryProxyInstance> start({
    required CoreConfig config,
    required int listenPort,
    String? xrayBinaryPath,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final tempDir = (workingDirectory != null && Directory(workingDirectory).existsSync())
        ? Directory(workingDirectory)
        : Directory.systemTemp;
    final tempFile = File("${tempDir.path}/v2raypro_ping_temp_${DateTime.now().millisecondsSinceEpoch}_$listenPort.json");

    final raw = Map<String, dynamic>.from(config.rawJson);
    final inbounds = <Map<String, dynamic>>[
      {
        "tag": "temp-in",
        "port": listenPort,
        "listen": "127.0.0.1",
        "protocol": "mixed",
        "sniffing": {"enabled": false, "destOverride": ["http", "tls"]},
      }
    ];

    final outbounds = (raw["outbounds"] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    if (outbounds.isEmpty && config.node != null) {
      outbounds.add({
        "tag": "proxy",
        "protocol": config.node!.protocol.name,
      });
    }

    final testConfig = {
      "log": {"loglevel": "none"},
      "inbounds": inbounds,
      "outbounds": outbounds,
      "routing": {
        "domainStrategy": "AsIs",
        "rules": [
          {"type": "field", "inboundTag": ["temp-in"], "outboundTag": "proxy"}
        ]
      }
    };

    await tempFile.writeAsString(jsonEncode(testConfig));

    Process? process;
    if (xrayBinaryPath != null && File(xrayBinaryPath).existsSync()) {
      process = await Process.start(
        xrayBinaryPath,
        ["run", "-c", tempFile.path],
        workingDirectory: workingDirectory,
        environment: environment,
      );
      for (int i = 0; i < 25; i++) {
        try {
          final s = await Socket.connect("127.0.0.1", listenPort, timeout: const Duration(milliseconds: 50));
          await s.close();
          s.destroy();
          break;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }

    return TemporaryProxyInstance(process: process, configFile: tempFile);
  }

  /// Sends HTTP requests through the temporary proxy socket to test destinations to calculate real delay.
  Future<int?> measureRealDelayThroughProxy({
    required HttpClient client,
    required String destination,
    required int port,
    required PingType pingType,
    required Duration timeout,
  }) async {
    final schemes = (port == 443) ? ["https", "http"] : ["http"];
    final portSuffix = (port == 80 || port == 443) ? "" : ":$port";
    final urls = <Uri>[
      Uri.parse("http://cp.cloudflare.com/generate_204"),
      Uri.parse("http://www.google.com/generate_204"),
      Uri.parse("${schemes.first}://$destination$portSuffix/generate_204"),
    ];

    for (final uri in urls) {
      int? minDuration;
      bool success = false;
      const attempts = 2;

      for (int i = 0; i < attempts; i++) {
        try {
          final sw = Stopwatch()..start();
          final req = await client.getUrl(uri).timeout(timeout);
          final resp = await req.close().timeout(timeout);
          sw.stop();
          await resp.drain();

          if (resp.statusCode == 200 || resp.statusCode == 204) {
            final duration = sw.elapsedMilliseconds;
            if (!success || duration < (minDuration ?? 999999)) {
              minDuration = duration;
            }
            success = true;
          }
        } catch (_) {
          break;
        }

        if (i == 0 && success) {
          await Future.delayed(const Duration(milliseconds: 30));
        }
      }

      if (success && minDuration != null && minDuration > 0) {
        return minDuration;
      }
    }
    return null;
  }

  /// Retrieves outbound public exit IP and country code via Cloudflare Trace and HTTPS fallbacks.
  Future<({String? countryCode, String? countryName, String? exitIp})> fetchExitIpInfo(
    HttpClient client, {
    required Duration timeout,
  }) async {
    final traceUrls = <Uri>[
      Uri.parse("https://cp.cloudflare.com/cdn-cgi/trace"),
      Uri.parse("https://1.1.1.1/cdn-cgi/trace"),
      Uri.parse("http://cp.cloudflare.com/cdn-cgi/trace"),
    ];

    for (final uri in traceUrls) {
      try {
        final req = await client.getUrl(uri).timeout(timeout);
        final resp = await req.close().timeout(timeout);
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join().timeout(timeout);
          String? ip;
          String? loc;
          for (final line in body.split("\n")) {
            final trimmed = line.trim();
            if (trimmed.startsWith("ip=")) {
              ip = trimmed.substring(3).trim();
            } else if (trimmed.startsWith("loc=")) {
              final l = trimmed.substring(4).trim().toUpperCase();
              if (l.isNotEmpty && l != "XX") loc = l;
            }
          }
          if (ip != null && ip.isNotEmpty) {
            loc ??= LocalGeoIp.instance.lookup(ip);
            final name = loc != null ? CountryService.getCountryName(loc) : null;
            return (countryCode: loc, countryName: name, exitIp: ip);
          }
        }
      } catch (_) {}
    }

    // Secondary fallback: api.ipify.org to capture exit IP
    try {
      final req = await client.getUrl(Uri.parse("https://api.ipify.org?format=json")).timeout(timeout);
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join().timeout(timeout);
        final data = jsonDecode(body);
        final ip = data["ip"]?.toString().trim();
        if (ip != null && ip.isNotEmpty) {
          final loc = LocalGeoIp.instance.lookup(ip);
          final name = loc != null ? CountryService.getCountryName(loc) : null;
          return (countryCode: loc, countryName: name, exitIp: ip);
        }
      }
    } catch (_) {}

    return (countryCode: null, countryName: null, exitIp: null);
  }
}

/// Manages the running temporary proxy instance and cleans up config file and process upon completion.
class TemporaryProxyInstance {
  final Process? process;
  final File configFile;

  TemporaryProxyInstance({this.process, required this.configFile});

  /// Terminates the temporary process and deletes config file from disk.
  Future<void> dispose() async {
    if (process != null) {
      process!.kill();
    }
    try {
      if (await configFile.exists()) {
        await configFile.delete();
      }
    } catch (_) {}
  }
}
