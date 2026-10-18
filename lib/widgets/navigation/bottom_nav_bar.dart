// Bottom Navigation Bar Widget
// Displays a modern floating Telegram-style capsule bottom navigation bar for Android.
// Supports dynamic active item indicators, notification badge pills, and drawer toggle actions.
// Incorporates haptic feedback and fluid micro-animations for responsive tactile interaction.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../providers/app_providers.dart';

/// Modern floating capsule bottom navigation bar.
/// Houses primary destinations (Dashboard, Configs, Subscriptions) and drawer button with badge counters.
class BottomNavBar extends ConsumerWidget {
  final int selectedIndex;
  final int bottomNavIndex;
  final String locale;
  final bool hasCdn;
  final String scannerLabel;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onOpenDrawer;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.bottomNavIndex,
    required this.locale,
    required this.hasCdn,
    required this.scannerLabel,
    required this.onTabSelected,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData moreActiveIcon = Icons.grid_view_rounded;
    IconData moreInactiveIcon = Icons.grid_view_outlined;
    String moreLabel = AppStrings.get('more', locale: locale);

    if (selectedIndex >= 3) {
      if (selectedIndex == 3) {
        moreActiveIcon = Icons.card_giftcard_rounded;
        moreInactiveIcon = Icons.card_giftcard_outlined;
        moreLabel = AppStrings.get('free_configs', locale: locale);
      } else if (hasCdn && selectedIndex == 4) {
        moreActiveIcon = Icons.radar_rounded;
        moreInactiveIcon = Icons.radar_outlined;
        moreLabel = scannerLabel;
      } else if ((hasCdn && selectedIndex == 5) || (!hasCdn && selectedIndex == 4)) {
        moreActiveIcon = Icons.alt_route_rounded;
        moreInactiveIcon = Icons.alt_route_outlined;
        moreLabel = AppStrings.get('routing', locale: locale);
      } else if ((hasCdn && selectedIndex == 6) || (!hasCdn && selectedIndex == 5)) {
        moreActiveIcon = Icons.article_rounded;
        moreInactiveIcon = Icons.article_outlined;
        moreLabel = AppStrings.get('logs', locale: locale);
      } else if ((hasCdn && selectedIndex == 7) || (!hasCdn && selectedIndex == 6)) {
        moreActiveIcon = Icons.settings_rounded;
        moreInactiveIcon = Icons.settings_outlined;
        moreLabel = AppStrings.get('settings', locale: locale);
      }
    }

    final items = [
      (
        activeIcon: Icons.dashboard_rounded,
        inactiveIcon: Icons.dashboard_outlined,
        label: AppStrings.get('dashboard', locale: locale),
      ),
      (
        activeIcon: Icons.hub_rounded,
        inactiveIcon: Icons.hub_outlined,
        label: AppStrings.get('configs', locale: locale),
      ),
      Platform.isAndroid
          ? (
              activeIcon: Icons.rss_feed_rounded,
              inactiveIcon: Icons.rss_feed_outlined,
              label: locale == 'fa' ? 'اشتراک‌ها' : 'Sub',
            )
          : (
              activeIcon: Icons.card_giftcard_rounded,
              inactiveIcon: Icons.card_giftcard_outlined,
              label: AppStrings.get('free_configs', locale: locale),
            ),
      (
        activeIcon: moreActiveIcon,
        inactiveIcon: moreInactiveIcon,
        label: moreLabel,
      ),
    ];

    final nodes = ref.watch(nodesProvider);
    final subs = ref.watch(subscriptionsProvider);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17212B) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (idx) {
              final isSelected = bottomNavIndex == idx;
              final item = items[idx];

              int? badgeCount;
              final customConfigsCount = nodes.where((n) => n.subscriptionId == null && !n.isFree).length;
              if (idx == 1 && customConfigsCount > 0) badgeCount = customConfigsCount;
              if (idx == 2 && subs.isNotEmpty) badgeCount = subs.length;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (idx == 0) {
                        onTabSelected(0);
                      } else if (idx == 1) {
                        onTabSelected(1);
                      } else if (idx == 2) {
                        onTabSelected(Platform.isAndroid ? 2 : 3);
                      } else if (idx == 3) {
                        onOpenDrawer();
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    splashColor: const Color(0xFF2AABEE).withValues(alpha: 0.15),
                    highlightColor: const Color(0xFF2AABEE).withValues(alpha: 0.08),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0x332AABEE) : const Color(0x220088CC))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.inactiveIcon,
                                size: 22,
                                color: isSelected
                                    ? const Color(0xFF2AABEE)
                                    : (isDark ? const Color(0xFFB4C1CE) : const Color(0xFF707E8C)),
                              ),
                              if (badgeCount != null && badgeCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                    constraints: const BoxConstraints(minWidth: 16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF2AABEE)
                                          : (isDark ? const Color(0xFF242F3D) : const Color(0xFFE4E7EA)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      badgeCount > 99 ? '99+' : '$badgeCount',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? const Color(0xFFB4C1CE) : const Color(0xFF506070)),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: isSelected ? 11 : 10.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF2AABEE)
                                  : (isDark ? const Color(0xFFB4C1CE) : const Color(0xFF707E8C)),
                            ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
