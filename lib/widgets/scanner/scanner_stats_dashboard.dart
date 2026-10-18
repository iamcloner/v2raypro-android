// Scanner Statistics Dashboard
// Displays key metrics for the CDN scanner including total tested IPs,
// responsive clean IPs, success percentage, and best ping latency.
// Fully responsive on Android portrait and landscape modes.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/scanner_state.dart';

/// Statistics dashboard widget for the CDN scanner.
/// Displays 4 metric cards: tested IP count, responsive IPs, success rate, and lowest latency.
class ScannerStatsDashboard extends StatelessWidget {
  final ScannerState state;
  final String locale;
  final bool isPortrait;

  /// Creates the scanner statistics dashboard.
  const ScannerStatsDashboard({
    super.key,
    required this.state,
    required this.locale,
    this.isPortrait = false,
  });

  @override
  Widget build(BuildContext context) {
    final scannedCount = state.scanned;
    final responsiveCount = state.results.length;
    final successRate = scannedCount > 0
        ? ((responsiveCount / scannedCount) * 100).toStringAsFixed(1)
        : '0.0';
    final bestPing = state.bestIp?.latencyMs != null
        ? '${state.bestIp!.latencyMs} ms'
        : (state.currentBestLatency != null
            ? '${state.currentBestLatency} ms'
            : '--');

    final row1 = Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            context: context,
            icon: Icons.search_rounded,
            iconColor: Colors.blueAccent,
            label: AppStrings.get('tested_ips', locale: locale),
            value: '$scannedCount',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            context: context,
            icon: Icons.dns_rounded,
            iconColor: AppTheme.successColor,
            label: AppStrings.get('responsive_ips', locale: locale),
            value: '$responsiveCount',
            highlightColor: AppTheme.successColor,
          ),
        ),
      ],
    );

    final row2 = Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            context: context,
            icon: Icons.percent_rounded,
            iconColor: Colors.amber,
            label: AppStrings.get('success_rate', locale: locale),
            value: '$successRate%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            context: context,
            icon: Icons.bolt_rounded,
            iconColor: AppTheme.primaryAccent,
            label: AppStrings.get('best_ping', locale: locale),
            value: bestPing,
            highlightColor: bestPing != '--' ? AppTheme.primaryAccent : null,
          ),
        ),
      ],
    );

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row1,
          const SizedBox(height: 10),
          row2,
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: row1),
        const SizedBox(height: 10),
        Expanded(child: row2),
      ],
    );
  }

  /// Builds an individual metric card with colored icon, label, and numerical value.
  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: highlightColor ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
