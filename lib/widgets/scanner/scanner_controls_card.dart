// Scanner Controls & Strategy Card
// Provides user interface controls for selecting the scan strategy (Radar vs Target),
// configuring worker thread concurrency, target IP count, and launching or stopping scans.
// Designed with touch-friendly sliders and buttons for Android.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../providers/scanner_state.dart';

/// Scanner control and strategy configuration card widget.
/// Manages strategy switching between Radar and Target modes, concurrency threads, and scan lifecycle.
class ScannerControlsCard extends ConsumerWidget {
  final ScannerState state;
  final ProxyNode? activeNode;
  final String locale;
  final bool isPortrait;
  final double workers;
  final double targetTotal;
  final ValueChanged<double> onWorkersChanged;
  final ValueChanged<double> onTargetTotalChanged;
  final ValueChanged<int> onAccordionChanged;

  /// Creates the scanner control and strategy card.
  const ScannerControlsCard({
    super.key,
    required this.state,
    required this.activeNode,
    required this.locale,
    this.isPortrait = false,
    required this.workers,
    required this.targetTotal,
    required this.onWorkersChanged,
    required this.onTargetTotalChanged,
    required this.onAccordionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRadar = state.strategy == ScannerStrategy.radar;

    return SizedBox(
      height: isPortrait ? null : 280,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: isPortrait ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
            children: [
              _buildStrategySelectionRow(context, ref, isRadar),
              const SizedBox(height: 12),
              _buildWorkersSlider(context, ref),
              if (!isRadar) ...[
                const SizedBox(height: 6),
                _buildTargetTotalSlider(context, ref),
              ],
              const SizedBox(height: 10),
              _buildScanActionButton(ref, isRadar),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the strategy selection row for Radar vs Target with description tooltips.
  Widget _buildStrategySelectionRow(BuildContext context, WidgetRef ref, bool isRadar) {
    return Row(
      children: [
        Expanded(
          child: _buildStrategyButton(
            context: context,
            strategy: ScannerStrategy.radar,
            isSelected: isRadar,
            title: AppStrings.get('radar', locale: locale),
            icon: Icons.radar_rounded,
            tooltipDesc: AppStrings.get('radar_full_desc', locale: locale),
            isScanning: state.isScanning,
            onTap: () {
              ref.read(scannerProvider.notifier).setStrategy(ScannerStrategy.radar);
              onAccordionChanged(0);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStrategyButton(
            context: context,
            strategy: ScannerStrategy.target,
            isSelected: !isRadar,
            title: AppStrings.get('target', locale: locale),
            icon: Icons.track_changes_rounded,
            tooltipDesc: AppStrings.get('target_full_desc', locale: locale),
            isScanning: state.isScanning,
            onTap: () {
              ref.read(scannerProvider.notifier).setStrategy(ScannerStrategy.target);
              onAccordionChanged(1);
            },
          ),
        ),
      ],
    );
  }

  /// Builds a single strategy selection button with title and description tooltip.
  Widget _buildStrategyButton({
    required BuildContext context,
    required ScannerStrategy strategy,
    required bool isSelected,
    required String title,
    required IconData icon,
    required String tooltipDesc,
    required bool isScanning,
    required VoidCallback onTap,
  }) {
    final primaryColor = strategy == ScannerStrategy.radar
        ? AppTheme.primaryAccent
        : Colors.amber;

    return Material(
      color: isSelected ? primaryColor.withValues(alpha: 0.12) : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isScanning ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primaryColor : Theme.of(context).dividerColor.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: isSelected ? primaryColor : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? primaryColor : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Tooltip(
                message: tooltipDesc,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                preferBelow: true,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.info_outline_rounded, size: 16, color: isSelected ? primaryColor : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the slider for adjusting concurrent test worker threads.
  Widget _buildWorkersSlider(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  AppStrings.get('concurrent_workers', locale: locale),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${workers.round()} Threads',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            activeTrackColor: AppTheme.primaryAccent,
            thumbColor: AppTheme.primaryAccent,
          ),
          child: Slider(
            value: workers.clamp(5.0, 100.0),
            min: 5.0,
            max: 100.0,
            divisions: 95,
            label: '${workers.round()}',
            onChanged: state.isScanning
                ? null
                : (val) {
                    onWorkersChanged(val);
                    ref.read(scannerProvider.notifier).setWorkers(val.round());
                  },
          ),
        ),
      ],
    );
  }

  /// Builds the slider for setting total candidate IP limits in Target mode.
  Widget _buildTargetTotalSlider(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  AppStrings.get('target_total_count', locale: locale),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${targetTotal.round()} IPs',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            activeTrackColor: Colors.amber,
            thumbColor: Colors.amber,
          ),
          child: Slider(
            value: targetTotal,
            min: 200.0,
            max: 10000.0,
            divisions: 49,
            label: '${targetTotal.round()}',
            onChanged: state.isScanning
                ? null
                : (val) {
                    onTargetTotalChanged(val);
                    ref.read(scannerProvider.notifier).setTargetTotalCandidates(val.round());
                  },
          ),
        ),
      ],
    );
  }

  /// Builds the primary action button to start or stop the scanner.
  Widget _buildScanActionButton(WidgetRef ref, bool isRadar) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: state.isScanning ? AppTheme.errorColor : AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(
        state.isScanning
            ? Icons.stop_circle_rounded
            : (isRadar ? Icons.radar_rounded : Icons.search_rounded),
        size: 18,
      ),
      label: Text(
        state.isScanning
            ? (isRadar
                ? AppStrings.get('stop_radar', locale: locale)
                : AppStrings.get('stop_target', locale: locale))
            : (isRadar
                ? AppStrings.get('start_radar', locale: locale)
                : AppStrings.get('start_target', locale: locale)),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      onPressed: (activeNode == null)
          ? null
          : () {
              if (state.isScanning) {
                ref.read(scannerProvider.notifier).cancelScan();
              } else {
                ref.read(scannerProvider.notifier).startScan();
              }
            },
    );
  }
}
