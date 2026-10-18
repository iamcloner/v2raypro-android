// Scanner Progress Card
// Renders the real-time scanning progress bar, estimated time of arrival (ETA),
// and current candidate IP address being probed by worker threads.
// Android optimized UI component.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/scanner_state.dart';

/// Progress bar and real-time scanning status card widget.
/// Displays scan progress percentage, estimated time remaining (ETA), and active candidate IP.
class ScannerProgressCard extends StatelessWidget {
  final ScannerState state;
  final String locale;

  /// Creates the scanner progress card.
  const ScannerProgressCard({
    super.key,
    required this.state,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final isRadar = state.strategy == ScannerStrategy.radar;
    final progress = (state.total > 0 && !isRadar)
        ? (state.scanned / state.total).clamp(0.0, 1.0)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          isRadar
                              ? '${AppStrings.get(state.isScanning ? 'scanning' : 'scan_finished', locale: locale)} (${state.scanned})'
                              : '${AppStrings.get(state.isScanning ? 'scanning' : 'scan_finished', locale: locale)} (${state.scanned} / ${state.total})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRadar && state.isScanning && state.estimatedRemainingTime != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 10, color: AppTheme.primaryAccent),
                              const SizedBox(width: 3),
                              Text(
                                state.estimatedRemainingTime!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (state.currentIp.isNotEmpty)
                  Text(
                    state.currentIp,
                    style: const TextStyle(
                      color: AppTheme.primaryAccent,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade800,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
