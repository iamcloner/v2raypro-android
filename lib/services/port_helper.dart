// =======================================================================
// [File Name]: port_helper.dart
// [Description]: Helper utility for checking available network ports and securely allocating local inbounds.
// Prevents port collisions between SOCKS, HTTP, and proxy core API services on Android.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "dart:io";

/// Helper class for discovering and validating available local ports.
class PortHelper {
  /// Validates availability of a local network port.
  static Future<bool> isPortAvailable(int port) async {
    try {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Finds the first available open port if requested port is occupied.
  static Future<int> findAvailablePort(int startingPort) async {
    int port = startingPort;
    while (port < 65535) {
      if (await isPortAvailable(port)) return port;
      port++;
    }
    return startingPort;
  }
}
