// File: lib/settings_view.dart
// Description: Comprehensive application settings screen for Android.
// Manages appearance, network routing/TUN mode, DNS presets, latency testing, CDN ranges, and OTA updates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'services/update_service.dart';
import 'widgets/settings/settings_appearance_section.dart';
import 'widgets/settings/settings_cdn_ranges_card.dart';
import 'widgets/settings/settings_dns_card.dart';
import 'widgets/settings/settings_network_section.dart';
import 'widgets/settings/settings_startup_section.dart';
import 'widgets/settings/settings_test_section.dart';
import 'widgets/settings/settings_updates_section.dart';

export 'widgets/settings/settings_appearance_section.dart';
export 'widgets/settings/settings_cdn_ranges_card.dart';
export 'widgets/settings/settings_dns_card.dart';
export 'widgets/settings/settings_network_section.dart';
export 'widgets/settings/settings_startup_section.dart';
export 'widgets/settings/settings_test_section.dart';
export 'widgets/settings/settings_updates_section.dart';

/// Comprehensive application settings view.
/// Configures appearance, network options, DNS, speed test modes, CDN domains, and updates.
class SettingsView extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;

  /// Creates the settings view widget.
  const SettingsView({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(currentLocaleProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: AppStrings.get('more', locale: locale),
          onPressed: onOpenDrawer,
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
              AppStrings.get('settings', locale: locale),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 12, color: AppTheme.primaryAccent),
                const SizedBox(width: 4),
                Text(
                  UpdateService.currentAppVersion,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          // 1. Appearance & Language
          _buildCategoryHeader(Icons.palette_rounded, AppStrings.get('settings_cat_appearance', locale: locale)),
          SettingsAppearanceSection(locale: locale),
          const SizedBox(height: 18),

          // 2. Startup & Automation
          _buildCategoryHeader(Icons.power_settings_new_rounded, AppStrings.get('settings_cat_startup', locale: locale)),
          SettingsStartupSection(locale: locale),
          const SizedBox(height: 18),

          // 3. Core & Network Settings
          _buildCategoryHeader(Icons.router_rounded, AppStrings.get('settings_cat_core_net', locale: locale)),
          SettingsNetworkSection(locale: locale),
          const SizedBox(height: 12),
          SettingsDnsCard(locale: locale),
          const SizedBox(height: 18),

          // 4. Config Testing & Concurrency
          _buildCategoryHeader(Icons.speed_rounded, AppStrings.get('settings_cat_testing', locale: locale)),
          SettingsTestSection(locale: locale),
          const SizedBox(height: 18),

          // 5. CDN IP Ranges
          _buildCategoryHeader(Icons.cell_tower_rounded, AppStrings.get('settings_cat_cdn', locale: locale)),
          SettingsCdnRangesCard(locale: locale),
          const SizedBox(height: 18),

          // 6. Updates Center
          _buildCategoryHeader(Icons.system_update_rounded, AppStrings.get('settings_cat_updates', locale: locale)),
          SettingsUpdatesSection(locale: locale),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Builds a category section header with icon and group title.
  Widget _buildCategoryHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
