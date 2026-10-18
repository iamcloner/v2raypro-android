// File: lib/widgets/routing/app_routing_mode_card.dart
// Description: Routing mode policy selector card for per-app routing (Exclusive / Inclusive).
// Allows Android users to toggle between proxying all apps except selected ones (bypass),
// or exclusively proxying only the selected applications.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/routing_rule.dart';
import '../../providers/app_providers.dart';

/// Card for configuring per-app split tunneling routing strategy (inclusive / exclusive).
///
/// Enables selection between Exclusive policy (bypassing specific apps from VPN)
/// and Inclusive policy (routing only specified apps through the VPN).
class AppRoutingModeCard extends StatelessWidget {
  final AppRoutingMode mode;
  final String locale;
  final ValueChanged<AppRoutingMode> onModeChanged;

  const AppRoutingModeCard({
    super.key,
    required this.mode,
    required this.locale,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isExclusive = mode == AppRoutingMode.exclusive;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Text(
                AppStrings.get('app_routing_policy', locale: locale),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isExclusive
                      ? Colors.orange.withValues(alpha: 0.15)
                      : AppTheme.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isExclusive ? 'Exclusive' : 'Inclusive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isExclusive ? Colors.orange : AppTheme.primaryAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!isExclusive) onModeChanged(AppRoutingMode.exclusive);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isExclusive
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isExclusive
                            ? Colors.orange
                            : Theme.of(context).dividerColor.withValues(alpha: 0.4),
                        width: isExclusive ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.call_split_rounded,
                              size: 16,
                              color: isExclusive ? Colors.orange : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                AppStrings.get('app_routing_exclusive', locale: locale),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isExclusive ? Colors.orange : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.get('app_routing_exclusive_desc', locale: locale),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (isExclusive) onModeChanged(AppRoutingMode.inclusive);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: !isExclusive
                          ? AppTheme.primaryAccent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !isExclusive
                            ? AppTheme.primaryAccent
                            : Theme.of(context).dividerColor.withValues(alpha: 0.4),
                        width: !isExclusive ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.filter_alt_rounded,
                              size: 16,
                              color: !isExclusive ? AppTheme.primaryAccent : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                AppStrings.get('app_routing_inclusive', locale: locale),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !isExclusive ? AppTheme.primaryAccent : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.get('app_routing_inclusive_desc', locale: locale),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
