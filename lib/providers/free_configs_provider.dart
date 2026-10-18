// Free Configs Scraping & Testing Provider
// Manages scraping, validation, and persistence of free proxy configurations from public sources.
// Valid configurations are sorted by ping, supporting individual or batch testing.

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import '../services/country_service.dart';
import '../services/free_configs_service.dart';
import '../services/real_delay_service.dart';
import '../services/storage_service.dart';
import '../services/xray_process_service.dart';
import 'settings_providers.dart';
import 'test_settings_provider.dart';

/// Holds state for free configuration scraping and testing operations.
class FreeConfigsState {
  /// List of successfully tested, responsive nodes.
  final List<ProxyNode> workingNodes;
  /// List of unresponsive or timed-out nodes.
  final List<ProxyNode> timeoutNodes;
  /// Indicates whether scraping and testing is currently active.
  final bool isScanning;
  /// Total number of raw scraped configurations.
  final int totalScraped;
  /// Total number of unique and valid configurations.
  final int totalUnique;
  /// Number of candidate configurations tested so far.
  final int testedCandidates;
  /// Target count of top configurations to retain.
  final int targetCount;
  /// Status description of the process (idle, fetching, testing, completed).
  final String status;
  /// Progress percentage of the operation (between 0.0 and 1.0).
  final double progress;
  /// Estimated remaining time until scan completion.
  final String? estimatedRemainingTime;

  /// Combined list of all working and timed-out nodes.
  List<ProxyNode> get allNodes => [...workingNodes, ...timeoutNodes];

  /// Total count of failed configurations.
  int get failedCount => (testedCandidates - workingNodes.length).clamp(0, testedCandidates);

  /// Initializes the free configs state.
  const FreeConfigsState({
    this.workingNodes = const [],
    this.timeoutNodes = const [],
    this.isScanning = false,
    this.totalScraped = 0,
    this.totalUnique = 0,
    this.testedCandidates = 0,
    this.targetCount = 30,
    this.status = 'idle',
    this.progress = 0.0,
    this.estimatedRemainingTime,
  });

  /// Creates a copy of this state with updated fields.
  FreeConfigsState copyWith({
    List<ProxyNode>? workingNodes,
    List<ProxyNode>? timeoutNodes,
    bool? isScanning,
    int? totalScraped,
    int? totalUnique,
    int? testedCandidates,
    int? targetCount,
    String? status,
    double? progress,
    String? estimatedRemainingTime,
  }) {
    return FreeConfigsState(
      workingNodes: workingNodes ?? this.workingNodes,
      timeoutNodes: timeoutNodes ?? this.timeoutNodes,
      isScanning: isScanning ?? this.isScanning,
      totalScraped: totalScraped ?? this.totalScraped,
      totalUnique: totalUnique ?? this.totalUnique,
      testedCandidates: testedCandidates ?? this.testedCandidates,
      targetCount: targetCount ?? this.targetCount,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      estimatedRemainingTime: estimatedRemainingTime ?? this.estimatedRemainingTime,
    );
  }
}

/// Manages scanning, filtering, and latency testing of free configurations.
class FreeConfigsNotifier extends StateNotifier<FreeConfigsState> {
  final Ref ref;

  /// Loads previously saved free configurations on initialization.
  FreeConfigsNotifier(this.ref) : super(const FreeConfigsState()) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await StorageService.instance.loadFreeConfigs();
    if (saved.isNotEmpty) {
      state = state.copyWith(workingNodes: saved);
    }
  }

  /// Starts scraping new configurations and testing their real delay.
  Future<void> startScan() async {
    if (state.isScanning) return;
    state = state.copyWith(
      isScanning: true,
      status: 'fetching',
      progress: 0.0,
      testedCandidates: 0,
      totalScraped: 0,
      totalUnique: 0,
      workingNodes: [],
      timeoutNodes: [],
      estimatedRemainingTime: null,
    );

    final concurrency = ref.read(testConcurrencyProvider);
    final testMode = ref.read(testModeProvider);

    await FreeConfigsService.instance.fetchAndScan(
      concurrency: concurrency,
      testMode: testMode,
      onProgress: (prog) {
        if (!state.isScanning && prog.status != 'completed') return;
        final progressRatio = prog.totalUnique > 0
            ? (prog.testedCandidates / prog.totalUnique).clamp(0.0, 1.0)
            : 0.0;
        state = state.copyWith(
          workingNodes: prog.workingNodes,
          timeoutNodes: prog.timeoutNodes,
          totalScraped: prog.totalScraped,
          totalUnique: prog.totalUnique,
          testedCandidates: prog.testedCandidates,
          status: prog.status,
          progress: progressRatio,
          isScanning: !prog.isCompleted,
          estimatedRemainingTime: prog.estimatedRemainingTime,
        );
      },
    );

    if (state.workingNodes.isNotEmpty) {
      await StorageService.instance.saveFreeConfigs(state.workingNodes);
    }

    state = state.copyWith(isScanning: false, status: 'completed', estimatedRemainingTime: null);
  }

  /// Updates ping and details of a single tested configuration in the state list.
  void updateSingleNode(ProxyNode updatedNode) {
    final currentWorking = List<ProxyNode>.from(state.workingNodes);
    final currentTimeout = List<ProxyNode>.from(state.timeoutNodes);

    currentWorking.removeWhere((n) => n.id == updatedNode.id);
    currentTimeout.removeWhere((n) => n.id == updatedNode.id);

    if (updatedNode.hasValidPing) {
      currentWorking.add(updatedNode);
      currentWorking.sort((a, b) => (a.latencyMs ?? 99999).compareTo(b.latencyMs ?? 99999));
    } else {
      currentTimeout.add(updatedNode);
    }

    state = state.copyWith(
      workingNodes: List.unmodifiable(currentWorking),
      timeoutNodes: List.unmodifiable(currentTimeout),
    );

    if (currentWorking.isNotEmpty) {
      StorageService.instance.saveFreeConfigs(currentWorking);
    }
  }

  /// Executes real delay re-testing across all existing free configurations.
  Future<void> testAllFreeNodes() async {
    if (state.isScanning) return;
    final all = [...state.workingNodes, ...state.timeoutNodes];
    if (all.isEmpty) return;

    if (XrayProcessService.instance.core.androidBinaryPath == null) {
      await XrayProcessService.instance.initAndroid();
    }

    state = state.copyWith(
      isScanning: true,
      status: 'testing',
      progress: 0.0,
      totalUnique: all.length,
      testedCandidates: 0,
    );

    final concurrency = ref.read(testConcurrencyProvider).clamp(1, 100);
    final testMode = ref.read(testModeProvider);
    final modeStr = testMode == TestMode.turbo ? 'turbo' : 'normal';

    final working = <ProxyNode>[];
    final timeouts = <ProxyNode>[];
    int tested = 0;
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (!state.isScanning) break;
        int idx;
        if (nextIndex >= all.length) break;
        idx = nextIndex++;

        final n = all[idx];
        final res = await testRealDelay(
          mode: modeStr,
          type: 'xray',
          config: n.toJson(),
        );

        if (!state.isScanning) break;

        tested++;
        if (res.isSuccess) {
          final cCode = res.country?.toUpperCase() ?? n.countryCode ?? CountryService.resolveSync(n);
          final cName = res.countryName ?? (cCode != null ? CountryService.getCountryName(cCode) : n.country);
          working.add(n.copyWith(
            latencyMs: res.ping,
            countryCode: cCode,
            country: cName,
            lastTestedAt: DateTime.now(),
          ));
          working.sort((a, b) => (a.latencyMs ?? 99999).compareTo(b.latencyMs ?? 99999));
        } else {
          timeouts.add(n.copyWith(
            latencyMs: -1,
            lastTestedAt: DateTime.now(),
          ));
        }

        state = state.copyWith(
          workingNodes: List.unmodifiable(working),
          timeoutNodes: List.unmodifiable(timeouts),
          testedCandidates: tested,
          progress: (tested / all.length).clamp(0.0, 1.0),
        );
      }
    }

    final workerCount = min(concurrency, all.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    if (working.isNotEmpty) {
      await StorageService.instance.saveFreeConfigs(working);
    }

    state = state.copyWith(
      isScanning: false,
      status: 'completed',
    );
  }

  /// Cancels and halts the free configuration scan process.
  void cancelScan() {
    FreeConfigsService.instance.cancel();
    state = state.copyWith(isScanning: false, status: 'cancelled', estimatedRemainingTime: null);
  }
}

/// Riverpod provider for free configurations state.
final freeConfigsProvider = StateNotifierProvider<FreeConfigsNotifier, FreeConfigsState>((ref) {
  return FreeConfigsNotifier(ref);
});
