// File: lib/main.dart
// Description: Main entry point for V2Ray Pro Android application.
// Initializes Flutter engine, Rust FFI bridges, logging, and Android VPN services.
// Implements root theming, internationalization routing, and shell navigation.

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'configs_view.dart';
import 'core/ffi/rust_bridge.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'free_configs_view.dart';
import 'logs_view.dart';
import 'models/proxy_node.dart';
import 'providers/app_providers.dart';
import 'routing_view.dart';
import 'scanner_view.dart';
import 'services/cdn_scanner_service.dart';
import 'services/log_service.dart';
import 'services/tray_service.dart';
import 'services/update_service.dart';
import 'services/xray_process_service.dart';
import 'settings_view.dart';
import 'subscriptions_view.dart';
import 'widgets/dashboard/dashboard_view.dart';
import 'widgets/navigation/bottom_nav_bar.dart';
import 'widgets/navigation/mobile_drawer.dart';
import 'widgets/navigation/startup_update_dialog.dart';

/// Main entry point for the V2Ray Pro application.
/// Initializes logging infrastructure, Rust FFI bridges, and Android network configuration.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RustBridge.instance.initialize();
  await LogService.instance.init();

  if (Platform.isAndroid) {
    try {
      await XrayProcessService.instance.initAndroid();
    } catch (_) {}
  }

  try {
    if (!Platform.isAndroid || !(await XrayProcessService.instance.isAndroidVpnRunning())) {
      XrayProcessService.instance.cleanupSystemAndXray();
    }
  } catch (_) {}

  final container = ProviderContainer();
  await AppTrayService.instance.init(container);
  runApp(UncontrolledProviderScope(container: container, child: const V2RayProApp()));
}

/// Root application widget containing theme settings, localization, and primary navigation.
/// Manages application lifecycle, locale switches, and theme state.
class V2RayProApp extends ConsumerStatefulWidget {
  const V2RayProApp({super.key});

  @override
  ConsumerState<V2RayProApp> createState() => _V2RayProAppState();
}

class _V2RayProAppState extends ConsumerState<V2RayProApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        if (!Platform.isAndroid) {
          try {
            XrayProcessService.instance.cleanupSystemAndXray();
          } catch (_) {}
        }
        return AppExitResponse.exit;
      },
      onDetach: () {
        if (!Platform.isAndroid) {
          try {
            XrayProcessService.instance.cleanupSystemAndXray();
          } catch (_) {}
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeStr = ref.watch(currentLocaleProvider);
    final locale = Locale(localeStr);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      title: 'V2Ray Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('fa', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShell(),
    );
  }
}

/// Primary application shell containing sidebar drawer, bottom navigation bar, and tab screens.
/// Handles tab switching, backstack history, and automatic startup update checks.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  final List<int> _navigationHistory = [0];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Switches selected tab while preserving navigation history.
  void _navigateToTab(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _navigationHistory.add(index);
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      XrayProcessService.instance.onAndroidNotificationDisconnect = () {
        if (mounted) {
          ref.read(connectionStatusProvider.notifier).setDisconnected();
        }
      };
      const MethodChannel('com.v2raypro.app/native').invokeMethod('requestNotificationPermission');
      const MethodChannel('com.v2raypro.app/native').invokeMethod('requestIgnoreBatteryOptimizations');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isAndroid) {
        await ref.read(connectionStatusProvider.notifier).checkExistingConnection();
      }
      _checkAutoConnect();
      _checkStartupUpdate();
    });
  }

  /// Checks for and performs auto-connect to the last active configuration on startup.
  void _checkAutoConnect() {
    final autoConnect = ref.read(autoConnectOnLaunchProvider);
    final status = ref.read(connectionStatusProvider);
    if (autoConnect && status == ConnectionStateEnum.disconnected) {
      final nodes = ref.read(nodesProvider);
      final activeNode = nodes.isEmpty ? null : nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);
      if (activeNode != null) {
        ref.read(connectionStatusProvider.notifier).connect(activeNode);
      }
    }
  }

  /// Checks for newer application versions on startup.
  Future<void> _checkStartupUpdate() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    try {
      final info = await UpdateService.instance.checkAppUpdate();
      if (!mounted) return;

      final isActuallyNewer = info.hasUpdate && UpdateService.isVersionNewer(info.latestVersion, info.currentVersion);
      if (isActuallyNewer && mounted) {
        await showStartupUpdateDialog(context, ref, info);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(currentLocaleProvider);
    final nodes = ref.watch(nodesProvider);
    final activeNode = nodes.isEmpty ? null : nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);
    ref.watch(nodeCdnMapProvider);
    final activeCdn = activeNode != null
        ? ref.read(nodeCdnMapProvider.notifier).detectCdnForNode(activeNode)
        : null;
    final hasCdn = activeCdn != null;
    final scannerLabel = hasCdn
        ? (locale == 'fa' ? 'اسکنر ${activeCdn.displayNameFa}' : '${activeCdn.displayName} Scanner')
        : (locale == 'fa' ? 'اسکنر' : 'Scanner');

    final pages = <Widget>[
      const DashboardView(),
      ConfigsView(
        onNavigateToFreeConfigs: () => _navigateToTab(3),
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      SubscriptionsView(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      FreeConfigsView(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      if (hasCdn)
        ScannerView(
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      RoutingView(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      LogsView(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      SettingsView(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    ];

    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    int bottomNavIndex = 3;
    if (_selectedIndex == 0) {
      bottomNavIndex = 0;
    } else if (_selectedIndex == 1) {
      bottomNavIndex = 1;
    } else if (_selectedIndex == 2) {
      bottomNavIndex = 2;
    }

    return PopScope(
      canPop: _selectedIndex == 0 && !(_scaffoldKey.currentState?.isDrawerOpen ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        if (_selectedIndex != 0) {
          setState(() {
            while (_navigationHistory.isNotEmpty && _navigationHistory.last == _selectedIndex) {
              _navigationHistory.removeLast();
            }
            _selectedIndex = _navigationHistory.isNotEmpty ? _navigationHistory.removeLast() : 0;
          });
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: MobileDrawer(
          selectedIndex: _selectedIndex,
          locale: locale,
          hasCdn: hasCdn,
          scannerLabel: scannerLabel,
          onTabSelected: _navigateToTab,
        ),
        appBar: _selectedIndex != 0
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: AppStrings.get('more', locale: locale),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00D2FF).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "V2Ray",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D2FF), Color(0xFFFF7A00)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "PRO",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        body: pages[_selectedIndex],
        bottomNavigationBar: BottomNavBar(
          selectedIndex: _selectedIndex,
          bottomNavIndex: bottomNavIndex,
          locale: locale,
          hasCdn: hasCdn,
          scannerLabel: scannerLabel,
          onTabSelected: _navigateToTab,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
    );
  }
}
