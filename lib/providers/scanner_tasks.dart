// Scanner Tasks Implementation (Radar & Target Modes)
// Orchestrates multi-threaded background probing of CDN edge IP candidates.
// Manages real delay testing, latency ranking, auto-reconnect on improvement, and time estimation.
// Fully integrated with Riverpod state notifiers and native Xray core tunnels.

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/log_entry.dart';
import '../models/proxy_node.dart';
import '../models/scan_result.dart';
import '../services/cdn_scanner_service.dart';
import '../services/country_service.dart';
import '../services/log_service.dart';
import '../services/real_delay_service.dart';
import 'connection_provider.dart';
import 'nodes_provider.dart';
import 'scanner_provider.dart';

/// Executes clean IP scanning in radar mode.
/// Continuously probes candidate IPs in the background and auto-connects upon discovering better latency.
class RadarScannerTask {
  final Ref ref;
  final ScannerNotifier notifier;

  RadarScannerTask({required this.ref, required this.notifier});

  Future<void> run({
    required ProxyNode activeNode,
    required CdnProvider cdn,
    required List<String> customCidrs,
    required String origAddress,
    required bool isDomain,
    required int workers,
  }) async {
    notifier.updateState((s) => s.copyWith(
      isScanning: true,
      total: 0,
      scanned: 0,
      currentIp: "",
      results: [],
      bestIp: null,
      connectedIp: activeNode.address,
      currentBestLatency: null,
      radarLogs: [],
      statusMessage: "Radar active...",
      radarHealthyCount: 0,
      showRadarTrafficWarning: false,
    ));

    final rng = Random();
    final poolSize = workers.clamp(5, 50);

    Future<void> runWorker() async {
      while (!notifier.isCancelled) {
        final ipList = CdnScannerService.generateCandidateIps(
          cdn: cdn,
          count: 1,
          customCidrs: customCidrs,
          rng: rng,
        );
        if (ipList.isEmpty) break;
        final ip = ipList.first;

        final cand = activeNode.copyWith(
          id: 'scan_radar_${ip.replaceAll('.', '_')}',
          address: ip,
          host: (activeNode.host != null && activeNode.host!.isNotEmpty)
              ? activeNode.host
              : (isDomain ? origAddress : null),
          sni: (activeNode.sni != null && activeNode.sni!.isNotEmpty)
              ? activeNode.sni
              : (isDomain ? origAddress : null),
        );

        final res = await testRealDelay(
          mode: 'turbo',
          type: 'xray',
          config: cand.toJson(),
          timeout: const Duration(milliseconds: 1800),
        );

        if (notifier.isCancelled) break;

        notifier.updateState((s) => s.copyWith(
          scanned: s.scanned + 1,
          currentIp: ip,
        ));

        final isVerified = res.isSuccess && res.ping != null && res.ping! > 0;
        if (isVerified) {
          final lat = res.ping!;
          final cCode = (res.countryCode != null && res.countryCode!.isNotEmpty && res.countryCode != 'XX')
              ? res.countryCode!
              : (CountryService.extractCountryCodeFromName(activeNode.name) ?? 'XX');
          final cName = res.country ?? CountryService.getCountryName(cCode);

          final s = notifier.currentState;
          final newHealthyCount = s.radarHealthyCount + 1;
          final shouldWarn = newHealthyCount >= 10 && !notifier.hasWarnedRadarTraffic;
          if (shouldWarn) notifier.setWarnedRadarTraffic(true);

          final scanRes = ScanResult(
            ip: ip,
            port: activeNode.port,
            tcpSuccess: true,
            tcpLatencyMs: lat,
            tlsSuccess: activeNode.security == SecurityType.tls || activeNode.security == SecurityType.reality,
            tlsLatencyMs: lat,
            protocolSuccess: true,
            totalLatencyMs: lat,
            rankScore: lat.toDouble(),
            countryCode: cCode,
            country: cName,
            exitIp: res.exitIp,
          );

          final existingIndex = s.results.indexWhere((r) => r.ip == ip);
          List<ScanResult> updatedResults;
          if (existingIndex >= 0) {
            final existing = s.results[existingIndex];
            if ((existing.totalLatencyMs ?? 99999) > lat) {
              updatedResults = List<ScanResult>.from(s.results);
              updatedResults[existingIndex] = scanRes;
            } else {
              updatedResults = s.results;
            }
          } else {
            updatedResults = [...s.results, scanRes];
          }
          updatedResults.sort((a, b) => (a.totalLatencyMs ?? 99999).compareTo(b.totalLatencyMs ?? 99999));

          final prevBest = s.currentBestLatency;
          final isNewBest = prevBest == null || (lat < prevBest && (prevBest - lat) >= 20);

          if (isNewBest) {
            final improvement = prevBest != null ? (prevBest - lat) : null;
            final newEntry = RadarLogEntry(
              ip: ip,
              latencyMs: lat,
              timestamp: DateTime.now(),
              improvementMs: improvement,
            );

            notifier.updateState((st) => st.copyWith(
              results: updatedResults,
              bestIp: scanRes,
              connectedIp: ip,
              currentBestLatency: lat,
              radarLogs: [newEntry, ...st.radarLogs],
              radarHealthyCount: newHealthyCount,
              showRadarTrafficWarning: shouldWarn ? true : st.showRadarTrafficWarning,
            ));

            LogService.instance.add(
              "[Radar] Discovered new best ${cdn.displayName} IP: $ip (${lat}ms)${improvement != null ? ' - improved by ${improvement}ms' : ''}",
              level: LogLevel.access,
              source: "scanner",
            );
            ref.read(nodesProvider.notifier).applyIp(
              activeNode.id,
              ip,
              latencyMs: lat,
              countryCode: cCode,
              country: cName,
            );
            await ref.read(connectionStatusProvider.notifier).reconnect();
          } else {
            notifier.updateState((st) => st.copyWith(
              results: updatedResults,
              radarHealthyCount: newHealthyCount,
              showRadarTrafficWarning: shouldWarn ? true : st.showRadarTrafficWarning,
            ));
            LogService.instance.add(
              "[Radar] Discovered responsive ${cdn.displayName} IP: $ip (${lat}ms)",
              level: LogLevel.info,
              source: "scanner",
            );
          }
        }
      }
    }

    await Future.wait(List.generate(poolSize, (_) => runWorker()));
    notifier.updateState((s) => s.copyWith(isScanning: false, statusMessage: "Stopped"));
  }
}

/// Executes targeted scanning across a specified batch of candidate IPs.
/// Tracks scan progress, estimates remaining time, and ranks discovered responsive servers.
class TargetScannerTask {
  final Ref ref;
  final ScannerNotifier notifier;

  TargetScannerTask({required this.ref, required this.notifier});

  Future<void> run({
    required ProxyNode activeNode,
    required CdnProvider cdn,
    required List<String> customCidrs,
    required String origAddress,
    required bool isDomain,
    required int workers,
  }) async {
    final totalCount = notifier.currentState.targetTotalCandidates;
    final candidates = CdnScannerService.generateCandidateIps(
      cdn: cdn,
      count: totalCount,
      customCidrs: customCidrs,
    );

    notifier.updateState((s) => s.copyWith(
      isScanning: true,
      total: candidates.length,
      scanned: 0,
      currentIp: "",
      results: [],
      bestIp: null,
      connectedIp: activeNode.address,
      currentBestLatency: null,
      radarLogs: [],
      statusMessage: "Scanning...",
    ));

    final scanStartTime = DateTime.now();
    int currentIndex = 0;
    final poolSize = workers.clamp(5, 100);

    Future<void> runWorker() async {
      while (currentIndex < candidates.length && !notifier.isCancelled) {
        final idx = currentIndex++;
        if (idx >= candidates.length) break;
        final ip = candidates[idx];

        final cand = activeNode.copyWith(
          id: 'scan_target_${ip.replaceAll('.', '_')}',
          address: ip,
          host: (activeNode.host != null && activeNode.host!.isNotEmpty)
              ? activeNode.host
              : (isDomain ? origAddress : null),
          sni: (activeNode.sni != null && activeNode.sni!.isNotEmpty)
              ? activeNode.sni
              : (isDomain ? origAddress : null),
        );

        final res = await testRealDelay(
          mode: 'turbo',
          type: 'xray',
          config: cand.toJson(),
          timeout: const Duration(milliseconds: 1800),
        );

        if (notifier.isCancelled) break;

        final newScanned = notifier.currentState.scanned + 1;
        String? eta;
        if (newScanned > 5 && candidates.length > 50) {
          final elapsedMs = DateTime.now().difference(scanStartTime).inMilliseconds;
          final msPerItem = elapsedMs / newScanned;
          final remSec = ((candidates.length - newScanned) * msPerItem / 1000).ceil();
          eta = '~${(remSec ~/ 60).toString().padLeft(2, '0')}:${(remSec % 60).toString().padLeft(2, '0')}';
        }

        notifier.updateState((s) => s.copyWith(
          scanned: newScanned,
          currentIp: ip,
          estimatedRemainingTime: eta,
        ));

        final isVerified = res.isSuccess && res.latencyMs != null && res.latencyMs! > 0;
        if (isVerified) {
          final lat = res.latencyMs!;
          final cCode = (res.countryCode != null && res.countryCode!.isNotEmpty && res.countryCode != 'XX')
              ? res.countryCode!
              : (CountryService.extractCountryCodeFromName(activeNode.name) ?? 'XX');
          final cName = res.country ?? CountryService.getCountryName(cCode);

          final scanRes = ScanResult(
            ip: ip,
            port: activeNode.port,
            tcpSuccess: true,
            tcpLatencyMs: lat,
            tlsSuccess: activeNode.security == SecurityType.tls || activeNode.security == SecurityType.reality,
            tlsLatencyMs: lat,
            protocolSuccess: true,
            totalLatencyMs: lat,
            rankScore: lat.toDouble(),
            countryCode: cCode,
            country: cName,
            exitIp: res.exitIp,
          );

          notifier.updateState((s) {
            final updatedList = [...s.results, scanRes];
            updatedList.sort((a, b) => (a.totalLatencyMs ?? 99999).compareTo(b.totalLatencyMs ?? 99999));
            return s.copyWith(
              results: updatedList,
              bestIp: updatedList.first,
            );
          });
        }
      }
    }

    await Future.wait(List.generate(poolSize, (_) => runWorker()));
    notifier.updateState((s) => s.copyWith(isScanning: false, statusMessage: "Finished", estimatedRemainingTime: null));
    LogService.instance.add(
      "[Target] Scan finished. Tested ${notifier.currentState.scanned}/${candidates.length} IPs, found ${notifier.currentState.results.length} responsive servers.",
      level: LogLevel.info,
      source: "scanner",
    );
  }
}
