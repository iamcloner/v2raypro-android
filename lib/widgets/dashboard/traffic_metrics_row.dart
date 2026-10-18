// Dashboard Traffic Metrics Row
// Displays live real-time network bandwidth statistics including total downloaded
// and uploaded bytes, formatted with dynamic magnitude units (KB, MB, GB).
// Designed for high-frequency low-overhead updates on Android.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/traffic_stats.dart';

/// Traffic consumption metrics display widget for the main dashboard.
/// Presents current download and upload volume across dedicated stat cards.
class TrafficMetricsRow extends StatelessWidget {
  final TrafficStats traffic;
  final bool isConnected;
  final String locale;

  /// Creates the network traffic cards row.
  const TrafficMetricsRow({
    super.key,
    required this.traffic,
    required this.isConnected,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: AppStrings.get('download', locale: locale),
            value: isConnected ? TrafficStats.formatBytes(traffic.downlinkBytes) : '0 B',
            icon: Icons.arrow_downward_rounded,
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: AppStrings.get('upload', locale: locale),
            value: isConnected ? TrafficStats.formatBytes(traffic.uplinkBytes) : '0 B',
            icon: Icons.arrow_upward_rounded,
            color: AppTheme.secondaryAccent,
          ),
        ),
      ],
    );
  }

  /// Builds an individual traffic metric tile with directional icon and formatted text value.
  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
