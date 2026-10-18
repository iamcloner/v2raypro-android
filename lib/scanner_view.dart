// File: lib/scanner_view.dart
// Description: CDN and Cloudflare scanner screen for discovering clean IP addresses.
// Features real-time latency probing, automatic subnet switching, and radar scanning.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/translations.dart';
import 'providers/app_providers.dart';
import 'providers/scanner_state.dart';
import 'widgets/scanner/scanner_clean_ip_tile.dart';
import 'widgets/scanner/scanner_connected_card.dart';
import 'widgets/scanner/scanner_controls_card.dart';
import 'widgets/scanner/scanner_dual_accordion.dart';
import 'widgets/scanner/scanner_progress_card.dart';
import 'widgets/scanner/scanner_stats_dashboard.dart';

export 'widgets/scanner/scanner_clean_ip_tile.dart';
export 'widgets/scanner/scanner_connected_card.dart';
export 'widgets/scanner/scanner_controls_card.dart';
export 'widgets/scanner/scanner_dual_accordion.dart';
export 'widgets/scanner/scanner_progress_card.dart';
export 'widgets/scanner/scanner_stats_dashboard.dart';

/// Main CDN scanner and intelligent radar view.
/// Optimizes server endpoints across Cloudflare and other CDNs by discovering clean IP addresses.
class ScannerView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;

  /// Creates the scanner view widget.
  const ScannerView({super.key, this.onOpenDrawer});

  @override
  ConsumerState<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends ConsumerState<ScannerView>
    with SingleTickerProviderStateMixin {
  double _workers = 20.0;
  double _targetTotal = 500.0;
  int _activeAccordion = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider);
    final nodes = ref.watch(nodesProvider);
    final activeNode = nodes.isEmpty
        ? null
        : nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);
    final locale = ref.watch(currentLocaleProvider);
    ref.watch(nodeCdnMapProvider);
    final detectedCdn = activeNode != null
        ? ref.read(nodeCdnMapProvider.notifier).detectCdnForNode(activeNode)
        : null;

    if (detectedCdn != null && state.selectedCdn != detectedCdn && !state.isScanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(scannerProvider.notifier).setSelectedCdn(detectedCdn);
        }
      });
    }

    final currentCdn = state.selectedCdn;

    if (!state.isScanning) {
      if (_workers.round() != state.workers) {
        _workers = state.workers.toDouble();
      }
      if (_targetTotal.round() != state.targetTotalCandidates) {
        _targetTotal = state.targetTotalCandidates.toDouble();
      }
    }

    if (state.isScanning && state.strategy == ScannerStrategy.radar) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait ||
        MediaQuery.of(context).size.width < 650;
    final scannerTitle = locale == 'fa'
        ? 'اسکنر ${currentCdn.displayNameFa}'
        : '${currentCdn.displayName} Scanner';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: AppStrings.get('more', locale: locale),
          onPressed: widget.onOpenDrawer,
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(
              scannerTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            tooltip: AppStrings.get('reset_scan', locale: locale),
            onPressed: () {
              ref.read(scannerProvider.notifier).resetScan();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.get('scan_reset_done', locale: locale))),
              );
            },
          ),
          if (activeNode?.originalAddress != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restore_rounded, size: 20),
              tooltip: AppStrings.get('restore_original', locale: locale),
              onPressed: () {
                ref.read(nodesProvider.notifier).restoreAddress(activeNode!.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppStrings.get('original_restored', locale: locale))),
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPortrait) ...[
              ScannerStatsDashboard(state: state, locale: locale, isPortrait: true),
              if (state.isScanning) ...[
                const SizedBox(height: 10),
                ScannerProgressCard(state: state, locale: locale),
              ],
              const SizedBox(height: 12),
              ScannerControlsCard(
                state: state,
                activeNode: activeNode,
                locale: locale,
                isPortrait: true,
                workers: _workers,
                targetTotal: _targetTotal,
                onWorkersChanged: (w) => setState(() => _workers = w),
                onTargetTotalChanged: (t) => setState(() => _targetTotal = t),
                onAccordionChanged: (idx) => setState(() => _activeAccordion = idx),
              ),
              const SizedBox(height: 12),
              ScannerConnectedCard(
                state: state,
                activeNode: activeNode,
                locale: locale,
                isPortrait: true,
                pulseAnimation: _pulseAnimation,
              ),
              const SizedBox(height: 12),
              ScannerDualAccordion(
                state: state,
                locale: locale,
                isPortrait: true,
                activeAccordion: _activeAccordion,
                onAccordionChanged: (idx) => setState(() => _activeAccordion = idx),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 280,
                      child: Column(
                        children: [
                          Expanded(child: ScannerStatsDashboard(state: state, locale: locale)),
                          if (state.isScanning) ...[
                            const SizedBox(height: 8),
                            ScannerProgressCard(state: state, locale: locale),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ScannerControlsCard(
                      state: state,
                      activeNode: activeNode,
                      locale: locale,
                      workers: _workers,
                      targetTotal: _targetTotal,
                      onWorkersChanged: (w) => setState(() => _workers = w),
                      onTargetTotalChanged: (t) => setState(() => _targetTotal = t),
                      onAccordionChanged: (idx) => setState(() => _activeAccordion = idx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ScannerConnectedCard(
                      state: state,
                      activeNode: activeNode,
                      locale: locale,
                      pulseAnimation: _pulseAnimation,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ScannerDualAccordion(
                      state: state,
                      locale: locale,
                      activeAccordion: _activeAccordion,
                      onAccordionChanged: (idx) => setState(() => _activeAccordion = idx),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
