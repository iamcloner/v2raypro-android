// =======================================================================
// [File Name]: ping_service.dart
// [Description]: Latency and real delay evaluation service for proxy configurations on Android.
// Supports both direct IP ping (IP Test) and temporary proxy connection real delay mode
// (Real Delay Mode) alongside outbound exit IP and country extraction.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "../models/service_models.dart";
import "../models/proxy_node.dart";
import "country_service.dart";
import "protocol_probe.dart";
import "temp_proxy_runner.dart";

export "protocol_probe.dart";
export "temp_proxy_runner.dart";

/// Latency measurement and health check service for proxy nodes on Android.
class PingService {
  /// Singleton instance of PingService.
  static final PingService instance = PingService._internal();
  PingService._internal();

  static int _ephemeralPortCounter = 31000;

  /// Main ping execution entrypoint supporting ipTest and realDelay modes.
  Future<PingResult> ping({
    required CoreConfig config,
    String destination = "cp.cloudflare.com",
    int port = 80,
    PingType pingType = PingType.tcp,
    PingMode pingMode = PingMode.realDelay,
    bool showCountry = false,
    Duration timeout = const Duration(seconds: 4),
    String? xrayBinaryPath,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (pingMode == PingMode.ipTest) {
      return await _executeIpTest(
        config: config,
        pingType: pingType,
        timeout: timeout,
      );
    } else {
      return await _executeRealDelay(
        config: config,
        destination: destination,
        port: port,
        pingType: pingType,
        showCountry: showCountry,
        timeout: timeout,
        xrayBinaryPath: xrayBinaryPath,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }
  }

  /// Executes direct ping test to the configured server IP and port.
  Future<PingResult> _executeIpTest({
    required CoreConfig config,
    required PingType pingType,
    required Duration timeout,
  }) async {
    final serverInfo = config.extractServerAddressAndPort();
    final address = serverInfo.address;
    final port = serverInfo.port;

    if (address.isEmpty || port <= 0) {
      return PingResult.failure("Invalid server address or port in config");
    }

    try {
      int? latency;
      switch (pingType) {
        case PingType.tcp:
          latency = await ProtocolProbe.instance.tcpPing(address, port, timeout: timeout);
          break;
        case PingType.icmp:
          latency = await ProtocolProbe.instance.icmpPing(address, timeout: timeout);
          break;
        case PingType.udp:
          latency = await ProtocolProbe.instance.udpPing(address, port, timeout: timeout);
          break;
      }

      if (latency != null && latency > 0) {
        return PingResult.success(latencyMs: latency);
      } else {
        return PingResult.failure("Target unreachable via ${pingType.name.toUpperCase()}");
      }
    } catch (e) {
      return PingResult.failure(e.toString());
    }
  }

  /// Executes real delay measurement through a temporary proxy instance to Cloudflare or Google destinations.
  Future<PingResult> _executeRealDelay({
    required CoreConfig config,
    required String destination,
    required int port,
    required PingType pingType,
    required bool showCountry,
    required Duration timeout,
    String? xrayBinaryPath,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    int? latency;
    String? countryCode;
    String? countryName;
    String? exitIp;

    if (config.node != null && (xrayBinaryPath == null || !File(xrayBinaryPath).existsSync())) {
      latency = await ProtocolProbe.instance.probeNodeStrictProtocol(config.node!, timeout);
      if (latency != null && showCountry) {
        final loc = LocalGeoIp.instance.lookup(config.node!.address);
        if (loc != null) {
          countryCode = loc;
          countryName = CountryService.getCountryName(loc);
        }
      }
    } else {
      final tempPort = _getEphemeralPort();
      TemporaryProxyInstance? tempProxy;

      try {
        tempProxy = await TempProxyRunner.instance.start(
          config: config,
          listenPort: tempPort,
          xrayBinaryPath: xrayBinaryPath,
          workingDirectory: workingDirectory,
          environment: environment,
        );

        final client = HttpClient();
        client.findProxy = (uri) => "PROXY 127.0.0.1:$tempPort";
        client.connectionTimeout = timeout;
        client.badCertificateCallback = (cert, host, port) => true;

        latency = await TempProxyRunner.instance.measureRealDelayThroughProxy(
          client: client,
          destination: destination,
          port: port,
          pingType: pingType,
          timeout: timeout,
        );

        if (showCountry) {
          if (latency != null) {
            final ipInfo = await TempProxyRunner.instance.fetchExitIpInfo(client, timeout: timeout);
            countryCode = ipInfo.countryCode;
            countryName = ipInfo.countryName;
            exitIp = ipInfo.exitIp;
          }
          if (countryCode == null && config.node != null) {
            final loc = LocalGeoIp.instance.lookup(config.node!.address);
            if (loc != null) {
              countryCode = loc;
              countryName = CountryService.getCountryName(loc);
            }
          }
        }
      } catch (e) {
        return PingResult.failure(e.toString());
      } finally {
        await tempProxy?.dispose();
      }
    }

    if (latency != null && latency > 0) {
      return PingResult.success(
        latencyMs: latency,
        countryCode: countryCode,
        countryName: countryName,
        exitIp: exitIp,
      );
    } else {
      return PingResult.failure("Real delay probe timed out or destination unreachable");
    }
  }

  /// Measures direct protocol handshake latency for a proxy configuration via ProtocolProbe.
  Future<int?> pingProtocolDelay(
    ProxyNode node, {
    Duration timeout = const Duration(seconds: 3),
    int count = 1,
  }) async {
    return await ProtocolProbe.instance.pingProtocolDelay(node, timeout: timeout, count: count);
  }

  /// Tests connection latency to Google's HTTP 204 endpoint using an active proxy client.
  Future<int?> pingGoogleViaProxy(
    HttpClient client, {
    int count = 1,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    int? best;
    for (int i = 0; i < count; i++) {
      try {
        final sw = Stopwatch()..start();
        final req = await client.getUrl(Uri.parse("http://www.google.com/generate_204")).timeout(timeout);
        final resp = await req.close().timeout(timeout);
        sw.stop();
        await resp.drain();
        if (resp.statusCode == 204 || resp.statusCode == 200) {
          final lat = sw.elapsedMilliseconds;
          if (best == null || lat < best) best = lat;
        }
      } catch (_) {}
    }
    return best;
  }

  /// Allocates an ephemeral port to prevent collisions during concurrent ping tests.
  int _getEphemeralPort() {
    _ephemeralPortCounter++;
    if (_ephemeralPortCounter > 60000) _ephemeralPortCounter = 31000;
    return _ephemeralPortCounter;
  }
}


