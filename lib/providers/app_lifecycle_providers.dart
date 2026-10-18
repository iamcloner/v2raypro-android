// Application Lifecycle & Preferences Providers
// Manages application locale, theme mode (Light/Dark/System), and startup auto-connect/boot behaviors.
// Coordinates system dispatchers and local persistent storage.
// Built for Android preference synchronization.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// Manages the current application UI locale (Persian / English).
class LocaleNotifier extends StateNotifier<String> {
  /// Initializes with the operating system default locale.
  LocaleNotifier() : super(_detectInitialLocale()) {
    _init();
  }

  static String _detectInitialLocale() {
    try {
      final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase();
      if (code.startsWith('fa')) return 'fa';
    } catch (_) {}
    return 'en';
  }

  Future<void> _init() async {
    final saved = await StorageService.instance.loadLocale();
    if (saved != null && (saved == 'fa' || saved == 'en')) {
      if (mounted) super.state = saved;
    }
  }

  set state(String val) {
    super.state = val;
    StorageService.instance.saveLocale(val);
  }

  /// Updates the application locale and persists it to local storage.
  void setLocale(String val) {
    state = val;
  }
}

final currentLocaleProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});

/// Manages the application visual theme mode (Light, Dark, System default).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final str = await StorageService.instance.loadThemeMode();
    if (str == "light") {
      state = ThemeMode.light;
    } else if (str == "dark") {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  /// Sets and persists the application theme mode.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final str = mode == ThemeMode.light ? "light" : (mode == ThemeMode.dark ? "dark" : "system");
    await StorageService.instance.saveThemeMode(str);
  }

  Future<void> setTheme(ThemeMode mode) => setMode(mode);
}

final appThemeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// Controls automatic application execution on device boot.
class StartOnBootNotifier extends StateNotifier<bool> {
  StartOnBootNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.loadStartOnBoot();
  }

  /// Toggles the start-on-boot state.
  Future<void> toggle(bool val) async {
    state = val;
    await StorageService.instance.saveStartOnBoot(val);
  }
}

final startOnBootProvider = StateNotifierProvider<StartOnBootNotifier, bool>((ref) => StartOnBootNotifier());

/// Controls automatic connection to the last config upon application launch.
class AutoConnectNotifier extends StateNotifier<bool> {
  AutoConnectNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.loadAutoConnect();
  }

  /// Toggles the auto-connect on launch state.
  Future<void> toggle(bool val) async {
    state = val;
    await StorageService.instance.saveAutoConnect(val);
  }
}

final autoConnectOnLaunchProvider = StateNotifierProvider<AutoConnectNotifier, bool>((ref) => AutoConnectNotifier());

/// Controls automatic enabling of system proxy upon connection.
class AutoSysProxyNotifier extends StateNotifier<bool> {
  AutoSysProxyNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.loadAutoSysProxy();
  }

  /// Toggles automatic system proxy configuration on connect.
  Future<void> toggle(bool val) async {
    state = val;
    await StorageService.instance.saveAutoSysProxy(val);
  }
}

final autoEnableSysProxyOnConnectProvider = StateNotifierProvider<AutoSysProxyNotifier, bool>((ref) => AutoSysProxyNotifier());

/// Controls automatic enabling of VPN tunnel upon connection.
class AutoTunNotifier extends StateNotifier<bool> {
  AutoTunNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.instance.loadAutoTun();
  }

  /// Toggles automatic VPN tunnel configuration on connect.
  Future<void> toggle(bool val) async {
    state = val;
    await StorageService.instance.saveAutoTun(val);
  }
}

final autoEnableTunOnConnectProvider = StateNotifierProvider<AutoTunNotifier, bool>((ref) => AutoTunNotifier());
