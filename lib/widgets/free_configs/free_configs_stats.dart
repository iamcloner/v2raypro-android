// File: lib/widgets/free_configs/free_configs_stats.dart
// Description: Dashboard presenting metrics and statistics for scraped free configs.
// Displays total candidates, unique items, tested counts, working nodes, and timeouts.
// Optimized for Android with multi-language support (English/Persian).

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Widget displaying statistics and status counters for free config scraping and testing.
///
/// Presents metrics including total scraped, unique items, tested candidates,
/// responsive servers, and timeouts in formatted cards.
class FreeConfigsStats extends StatelessWidget {
  final FreeConfigsState state;
  final String locale;

  const FreeConfigsStats({
    super.key,
    required this.state,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final card1 = _buildStatCard(
      context: context,
      icon: Icons.cloud_download_rounded,
      iconColor: Colors.blueAccent,
      label: AppStrings.get('total_candidates', locale: locale),
      value: state.totalScraped > 0
          ? '${state.totalScraped}'
          : (state.workingNodes.isNotEmpty ? '${state.workingNodes.length}' : '0'),
    );
    final card2 = _buildStatCard(
      context: context,
      icon: Icons.filter_alt_rounded,
      iconColor: Colors.purpleAccent,
      label: AppStrings.get('unique_candidates', locale: locale),
      value: state.totalUnique > 0
          ? '${state.totalUnique}'
          : (state.workingNodes.isNotEmpty ? '${state.workingNodes.length}' : '0'),
    );
    final card3 = _buildStatCard(
      context: context,
      icon: Icons.speed_rounded,
      iconColor: Colors.amber,
      label: AppStrings.get('tested_count', locale: locale),
      value: state.testedCandidates > 0
          ? '${state.testedCandidates}'
          : (state.workingNodes.isNotEmpty ? '${state.workingNodes.length}' : '0'),
    );
    final card4 = _buildStatCard(
      context: context,
      icon: Icons.check_circle_rounded,
      iconColor: AppTheme.successColor,
      label: AppStrings.get('responsive_configs_count', locale: locale),
      value: '${state.workingNodes.length}',
      highlightColor: AppTheme.successColor,
    );
    final card5 = _buildStatCard(
      context: context,
      icon: Icons.cancel_rounded,
      iconColor: Colors.redAccent,
      label: AppStrings.get('failed_timeout_count', locale: locale),
      value: '${state.failedCount}',
      highlightColor: state.failedCount > 0 ? Colors.redAccent : null,
    );

    const spacing = 6.0;
    return Column(
      children: [
        Row(children: [card1, const SizedBox(width: spacing), card2]),
        const SizedBox(height: spacing),
        Row(children: [card3, const SizedBox(width: spacing), card4]),
        const SizedBox(height: spacing),
        Row(children: [card5]),
      ],
    );
  }

  /// Builds an individual statistics card with icon, label, and metric value.
  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: highlightColor ?? Theme.of(context).colorScheme.onSurface,
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
