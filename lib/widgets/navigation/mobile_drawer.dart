// Mobile Navigation Drawer Widget
// Provides side drawer navigation for quick access to all views in V2Ray Pro Android.
// Features brand header with logo, PRO badge, version tag, and localized section tiles.
// Highlights active navigation state and triggers smooth tab switching callbacks.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../services/update_service.dart';

/// Side navigation drawer for accessing app sections.
/// Displays screen navigation destinations including Dashboard, Servers, Subscriptions, Free Configs, and Settings.
class MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final String locale;
  final bool hasCdn;
  final String scannerLabel;
  final ValueChanged<int> onTabSelected;

  const MobileDrawer({
    super.key,
    required this.selectedIndex,
    required this.locale,
    required this.hasCdn,
    required this.scannerLabel,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final routingIdx = hasCdn ? 5 : 4;
    final logsIdx = hasCdn ? 6 : 5;
    final settingsIdx = hasCdn ? 7 : 6;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00D2FF).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "V2Ray",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D2FF), Color(0xFFFF7A00)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "PRO",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        UpdateService.currentAppVersion,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: Text(AppStrings.get('dashboard', locale: locale)),
              selected: selectedIndex == 0,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_rounded),
              title: Text(AppStrings.get('configs', locale: locale)),
              selected: selectedIndex == 1,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: Text(AppStrings.get('free_configs', locale: locale)),
              selected: selectedIndex == 3,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed_rounded),
              title: Text(AppStrings.get('subscriptions', locale: locale)),
              selected: selectedIndex == 2,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(2);
              },
            ),
            if (hasCdn)
              ListTile(
                leading: const Icon(Icons.radar_rounded),
                title: Text(scannerLabel),
                selected: selectedIndex == 4,
                onTap: () {
                  Navigator.of(context).pop();
                  onTabSelected(4);
                },
              ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.alt_route_rounded),
              title: Text(AppStrings.get('routing', locale: locale)),
              selected: selectedIndex == routingIdx,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(routingIdx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_rounded),
              title: Text(AppStrings.get('logs', locale: locale)),
              selected: selectedIndex == logsIdx,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(logsIdx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: Text(AppStrings.get('settings', locale: locale)),
              selected: selectedIndex == settingsIdx,
              onTap: () {
                Navigator.of(context).pop();
                onTabSelected(settingsIdx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
