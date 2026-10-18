// File: lib/widgets/routing/installed_apps_picker.dart
// Description: Dialog for picking installed Android applications for routing rules.
// Invokes native MethodChannel to fetch installed packages with search support,
// allowing users to pick package names for direct or proxy routing rules.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';

/// Dialog for searching and selecting installed Android applications.
///
/// Fetches packages from the OS layer and allows users to select
/// applications for proxy routing or bypass rules.
class InstalledAppsPicker extends StatelessWidget {
  final String locale;
  final void Function(String appName, String packageName) onSelected;

  const InstalledAppsPicker({
    super.key,
    required this.locale,
    required this.onSelected,
  });

  /// Static helper method to display the installed applications picker dialog.
  static void show(
    BuildContext context,
    String locale,
    void Function(String appName, String packageName) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => InstalledAppsPicker(
        locale: locale,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String filter = '';

    return StatefulBuilder(
      builder: (dialogCtx, setModalState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            children: [
              const Icon(Icons.apps_rounded, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Text(
                locale == 'fa' ? 'انتخاب برنامه' : 'Select Application',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: math.min(420.0, MediaQuery.of(context).size.width * 0.9),
            height: 400,
            child: Column(
              children: [
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    hintText: locale == 'fa' ? 'جستجوی برنامه...' : 'Search app...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      filter = val.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<List<dynamic>?>(
                    future: const MethodChannel('com.v2raypro.app/native').invokeMethod<List<dynamic>>('getInstalledApps'),
                    builder: (fCtx, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                          child: Text(
                            locale == 'fa' ? 'خطا در بارگذاری برنامه‌ها' : 'Failed to load apps',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }
                      final rawApps = snapshot.data!;
                      final apps = rawApps.map((item) {
                        final map = Map<String, dynamic>.from(item as Map);
                        return {
                          'name': map['name']?.toString() ?? '',
                          'packageName': map['packageName']?.toString() ?? '',
                        };
                      }).where((app) {
                        if (filter.isEmpty) return true;
                        final n = app['name']!.toLowerCase();
                        final p = app['packageName']!.toLowerCase();
                        return n.contains(filter) || p.contains(filter);
                      }).toList();

                      if (apps.isEmpty) {
                        return Center(
                          child: Text(
                            locale == 'fa' ? 'برنامه‌ای یافت نشد' : 'No applications found',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: apps.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final app = apps[idx];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.android_rounded, color: AppTheme.primaryAccent, size: 18),
                            ),
                            title: Text(
                              app['name']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              app['packageName']!,
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              onSelected(app['name']!, app['packageName']!);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(AppStrings.get('cancel', locale: locale)),
            ),
          ],
        );
      },
    );
  }
}
