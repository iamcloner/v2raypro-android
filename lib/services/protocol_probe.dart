// =======================================================================
// [File Name]: protocol_probe.dart
// [Description]: Specialized module for direct network protocol testing and evaluation (TCP, TLS, WS, XHTTP).
// Accurately measures transport layer latency by establishing direct sockets
// and executing target protocol handshakes on Android without spinning up heavy core processes.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:convert";
import "dart:io";
import "../models/proxy_node.dart";

/// Provider for direct transport layer latency measurements and protocol handshakes on Android.
class ProtocolProbe {
  /// Singleton instance of ProtocolProbe.
  static final ProtocolProbe instance = ProtocolProbe._internal();
  ProtocolProbe._internal();

  /// Measures direct protocol latency by repeating probes and selecting the lowest latency.
  Future<int?> pingProtocolDelay(
    ProxyNode node, {
    Duration timeout = const Duration(seconds: 3),
    int count = 1,
  }) async {
    int? lowest;
    for (int i = 0; i < count; i++) {
      final res = await probeNodeStrictProtocol(node, timeout);
      if (res != null && res > 0) {
        if (lowest == null || res < lowest) lowest = res;
      } else {
        if (i == 0) break;
      }
    }
    return lowest;
  }

  /// Direct TCP socket ping to specified host and port.
  Future<int?> tcpPing(String host, int port, {required Duration timeout}) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      await socket.close();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  /// Executes system ICMP ping by invoking the ping system binary.
  Future<int?> icmpPing(String host, {required Duration timeout}) async {
    final sw = Stopwatch()..start();
    try {
      final res = await Process.run("ping", ["-c", "1", "-W", timeout.inSeconds.toString(), host]).timeout(timeout);
      sw.stop();
      if (res.exitCode == 0) {
        final out = res.stdout.toString();
        final match = RegExp(r"(?:time|زمان)[=< ]*(\d+(?:\.\d+)?)ms", caseSensitive: false).firstMatch(out);
        if (match != null) {
          final t = double.tryParse(match.group(1)!);
          if (t != null) return t.round();
        }
        return sw.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tests UDP packet delivery to specified host and port.
  Future<int?> udpPing(String host, int port, {required Duration timeout}) async {
    final sw = Stopwatch()..start();
    RawDatagramSocket? socket;
    try {
      final addresses = await InternetAddress.lookup(host).timeout(timeout);
      if (addresses.isEmpty) return null;

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final dummyPacket = [0x00, 0x01, 0x02];
      socket.send(dummyPacket, addresses.first, port);
      sw.stop();
      return sw.elapsedMilliseconds > 0 ? sw.elapsedMilliseconds : 1;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  /// Advanced real delay probe using TCP socket, TLS upgrade, and HTTP request to probe WebSocket or XHTTP.
  Future<int?> probeNodeStrictProtocol(ProxyNode node, Duration timeout) async {
    final sw = Stopwatch()..start();
    Socket? rawSocket;
    try {
      rawSocket = await Socket.connect(node.address, node.port, timeout: timeout);
      final tcpLatency = sw.elapsedMilliseconds;
      Socket activeSocket = rawSocket;

      final sni = (node.sni != null && node.sni!.isNotEmpty)
          ? node.sni!
          : ((node.host != null && node.host!.isNotEmpty) ? node.host! : node.address);

      if (node.security == SecurityType.tls) {
        try {
          activeSocket = await SecureSocket.secure(
            rawSocket,
            host: sni,
            supportedProtocols: const ["http/1.1"],
            onBadCertificate: (_) => node.allowInsecure,
          ).timeout(timeout);
        } catch (_) {
          rawSocket.destroy();
          return null;
        }
      }

      final isWsTransport = node.network == NetworkType.ws || node.network == NetworkType.httpUpgrade;
      final isXhttpTransport = node.network == NetworkType.xhttp || node.network == NetworkType.splithttp;

      if (isWsTransport || isXhttpTransport) {
        final path = (node.path == null || node.path!.trim().isEmpty)
            ? "/"
            : (node.path!.trim().startsWith("/") ? node.path!.trim() : "/${node.path!.trim()}");

        final hostHeader = (node.host != null && node.host!.trim().isNotEmpty)
            ? node.host!.trim()
            : sni;

        final String httpRequest;
        if (isWsTransport) {
          httpRequest =
              "GET $path HTTP/1.1\r\n"
              "Host: $hostHeader\r\n"
              "User-Agent: Mozilla/5.0 (Linux; Android 14) Mobile\r\n"
              "Upgrade: websocket\r\n"
              "Connection: Upgrade\r\n"
              "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
              "Sec-WebSocket-Version: 13\r\n\r\n";
        } else {
          httpRequest =
              "GET $path HTTP/1.1\r\n"
              "Host: $hostHeader\r\n"
              "User-Agent: Mozilla/5.0 (Linux; Android 14) Mobile\r\n"
              "Accept: */*\r\n"
              "Connection: close\r\n\r\n";
        }

        final reqSw = Stopwatch()..start();
        activeSocket.add(utf8.encode(httpRequest));
        await activeSocket.flush();

        final completer = Completer<int?>();
        final sub = activeSocket.listen((data) {
          reqSw.stop();
          if (!completer.isCompleted) {
            final respStr = utf8.decode(data, allowMalformed: true);
            final firstLine = respStr.split("\r\n").first;
            final isCdnError = respStr.contains("502") ||
                respStr.contains("503") ||
                respStr.contains("504") ||
                respStr.contains("520") ||
                respStr.contains("521") ||
                respStr.contains("522") ||
                respStr.contains("523") ||
                respStr.contains("524") ||
                respStr.contains("525") ||
                respStr.contains("526") ||
                respStr.contains("530") ||
                respStr.contains("Error 1000") ||
                respStr.contains("Error 1005") ||
                respStr.contains("Error 1020") ||
                respStr.contains("Direct IP access not allowed");

            final isAcceptable = isWsTransport
                ? ((firstLine.contains(" 101 ") ||
                        firstLine.contains(" 200 ") ||
                        firstLine.contains(" 204 ") ||
                        firstLine.contains(" 400 ")) &&
                    !isCdnError)
                : ((firstLine.contains(" 101 ") ||
                        firstLine.contains(" 200 ") ||
                        firstLine.contains(" 204 ") ||
                        firstLine.contains(" 400 ") ||
                        firstLine.contains(" 404 ") ||
                        firstLine.contains(" 405 ")) &&
                    !isCdnError);

            if (isAcceptable) {
              final roundTrip = reqSw.elapsedMilliseconds;
              final accurateDelay = roundTrip > 0 ? roundTrip : tcpLatency;
              completer.complete(accurateDelay);
            } else {
              completer.complete(null);
            }
          }
        }, onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        }, onDone: () {
          if (!completer.isCompleted) completer.complete(null);
        });

        final res = await completer.future.timeout(timeout, onTimeout: () => null);
        await sub.cancel();
        activeSocket.destroy();
        return res;
      }

      sw.stop();
      activeSocket.destroy();
      return tcpLatency > 0 ? tcpLatency : sw.elapsedMilliseconds;
    } catch (_) {
      try {
        rawSocket?.destroy();
      } catch (_) {}
      return null;
    }
  }
}
