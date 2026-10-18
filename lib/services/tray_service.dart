// System Tray Service Stub for Android
// Acts as a no-op stub implementation on Android.
// On Android, background status controls and notifications are handled directly by VpnService.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// System tray service stub interface for controller compatibility on Android.
class AppTrayService {
  static final AppTrayService instance = AppTrayService._();
  AppTrayService._();

  /// Initializes tray service on Android (no-op).
  Future<void> init(ProviderContainer container) async {}

  /// Updates notification icon menu if necessary.
  Future<void> updateTrayMenu() async {}
}
