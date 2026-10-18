// Test Settings & Concurrency Providers
// Manages latency testing mode (Normal vs Turbo) and background test worker concurrency (5-100).
// Persists testing preferences in local storage for fast startup.
// Formatted for reactive Riverpod state binding.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// Latency and speed test modes (normal or high-speed turbo).
enum TestMode {
  normal,
  turbo,
}

/// Manages ping and real delay test mode.
class TestModeNotifier extends StateNotifier<TestMode> {
  TestModeNotifier() : super(TestMode.normal) {
    _init();
  }

  Future<void> _init() async {
    final str = await StorageService.instance.loadTestMode();
    if (!mounted) return;
    state = str == 'turbo' ? TestMode.turbo : TestMode.normal;
  }

  /// Sets and saves the configuration test mode.
  Future<void> setMode(TestMode mode) async {
    state = mode;
    await StorageService.instance.saveTestMode(mode.name);
  }
}

final testModeProvider = StateNotifierProvider<TestModeNotifier, TestMode>((ref) {
  return TestModeNotifier();
});

/// Manages parallel worker concurrency for configuration testing.
class TestConcurrencyNotifier extends StateNotifier<int> {
  bool _manualOverride = false;

  TestConcurrencyNotifier() : super(25) {
    _init();
  }

  Future<void> _init() async {
    final val = await StorageService.instance.loadTestConcurrency();
    if (!mounted || _manualOverride) return;
    state = val.clamp(5, 100);
  }

  /// Sets test worker concurrency (clamped between 5 and 100).
  Future<void> setConcurrency(int val) async {
    _manualOverride = true;
    final clamped = val.clamp(5, 100);
    state = clamped;
    await StorageService.instance.saveTestConcurrency(clamped);
  }
}

final testConcurrencyProvider = StateNotifierProvider<TestConcurrencyNotifier, int>((ref) {
  return TestConcurrencyNotifier();
});
