// =======================================================================
// [File Name]: session_storage.dart
// [Description]: Storage service for persisting active connection session state.
// Retains active node details, connection timestamp, traffic metrics, and outbound
// IP and country information to restore state upon application restart.
// [Platform]: Android Native Proxy & VPN Client
// =======================================================================

import "dart:async";
import "package:shared_preferences/shared_preferences.dart";

/// Manages persistence of active VPN and proxy session information on Android.
class SessionStorage {
  /// Singleton instance of SessionStorage.
  static final SessionStorage instance = SessionStorage._internal();
  SessionStorage._internal();

  static const _activeSessionNodeIdKey = "v2raypro_active_session_node_id";
  static const _activeSessionConnectedAtKey = "v2raypro_active_session_connected_at";
  static const _activeSessionIpKey = "v2raypro_active_session_ip";
  static const _activeSessionCountryKey = "v2raypro_active_session_country";
  static const _activeSessionCountryCodeKey = "v2raypro_active_session_country_code";
  static const _activeSessionUplinkKey = "v2raypro_active_session_uplink";
  static const _activeSessionDownlinkKey = "v2raypro_active_session_downlink";

  /// Saves all session metadata for a newly connected proxy session.
  Future<void> saveActiveSession({
    required String nodeId,
    required DateTime connectedAt,
    String? exitIp,
    String? country,
    String? countryCode,
    int? uplinkBytes,
    int? downlinkBytes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeSessionNodeIdKey, nodeId);
      await prefs.setInt(_activeSessionConnectedAtKey, connectedAt.millisecondsSinceEpoch);
      if (exitIp != null) await prefs.setString(_activeSessionIpKey, exitIp);
      if (country != null) await prefs.setString(_activeSessionCountryKey, country);
      if (countryCode != null) await prefs.setString(_activeSessionCountryCodeKey, countryCode);
      if (uplinkBytes != null) await prefs.setInt(_activeSessionUplinkKey, uplinkBytes);
      if (downlinkBytes != null) await prefs.setInt(_activeSessionDownlinkKey, downlinkBytes);
    } catch (_) {}
  }

  /// Updates uploaded and downloaded byte counters for the current session.
  Future<void> updateActiveSessionTraffic(int uplinkBytes, int downlinkBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_activeSessionUplinkKey, uplinkBytes);
      await prefs.setInt(_activeSessionDownlinkKey, downlinkBytes);
    } catch (_) {}
  }

  /// Updates exit IP and geolocation details for the active session.
  Future<void> updateActiveSessionOutbound({String? exitIp, String? country, String? countryCode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (exitIp != null) await prefs.setString(_activeSessionIpKey, exitIp);
      if (country != null) await prefs.setString(_activeSessionCountryKey, country);
      if (countryCode != null) await prefs.setString(_activeSessionCountryCodeKey, countryCode);
    } catch (_) {}
  }

  /// Loads active session data from storage to restore state in the UI.
  Future<Map<String, dynamic>?> loadActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nodeId = prefs.getString(_activeSessionNodeIdKey);
      final connectedAtMs = prefs.getInt(_activeSessionConnectedAtKey);
      if (nodeId == null || connectedAtMs == null) return null;

      return {
        "nodeId": nodeId,
        "connectedAt": DateTime.fromMillisecondsSinceEpoch(connectedAtMs),
        "exitIp": prefs.getString(_activeSessionIpKey),
        "country": prefs.getString(_activeSessionCountryKey),
        "countryCode": prefs.getString(_activeSessionCountryCodeKey),
        "uplinkBytes": prefs.getInt(_activeSessionUplinkKey) ?? 0,
        "downlinkBytes": prefs.getInt(_activeSessionDownlinkKey) ?? 0,
      };
    } catch (_) {
      return null;
    }
  }

  /// Clears all active session metadata after disconnection.
  Future<void> clearActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeSessionNodeIdKey);
      await prefs.remove(_activeSessionConnectedAtKey);
      await prefs.remove(_activeSessionIpKey);
      await prefs.remove(_activeSessionCountryKey);
      await prefs.remove(_activeSessionCountryCodeKey);
      await prefs.remove(_activeSessionUplinkKey);
      await prefs.remove(_activeSessionDownlinkKey);
    } catch (_) {}
  }
}
