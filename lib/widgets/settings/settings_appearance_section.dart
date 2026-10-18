// Settings Appearance & Localization Section
// Renders theme selection controls (System, Dark, Light), application language selector,
// and IP address masking toggles in a modern Android-tailored card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Appearance and language settings section widget.
/// Configures theme mode (Dark, Light, System), UI language, and IP address masking display.
class SettingsAppearanceSection extends ConsumerWidget {
  final String locale;

  /// Creates the appearance and localization settings section.
  const SettingsAppearanceSection({
    super.key,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final showFullIp = ref.watch(showFullIpProvider);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6_rounded, color: AppTheme.primaryAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get('theme_mode', locale: locale),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeChip(
                        context: context,
                        label: AppStrings.get('theme_dark', locale: locale),
                        icon: Icons.dark_mode_rounded,
                        isSelected: themeMode == ThemeMode.dark,
                        onTap: () => ref.read(appThemeModeProvider.notifier).setTheme(ThemeMode.dark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeChip(
                        context: context,
                        label: AppStrings.get('theme_light', locale: locale),
                        icon: Icons.light_mode_rounded,
                        isSelected: themeMode == ThemeMode.light,
                        onTap: () => ref.read(appThemeModeProvider.notifier).setTheme(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeChip(
                        context: context,
                        label: AppStrings.get('theme_system', locale: locale),
                        icon: Icons.brightness_auto_rounded,
                        isSelected: themeMode == ThemeMode.system,
                        onTap: () => ref.read(appThemeModeProvider.notifier).setTheme(ThemeMode.system),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language_rounded, color: AppTheme.secondaryAccent),
            title: const Text('Language / زبان'),
            subtitle: Text(
              locale == 'fa' ? 'فارسی' : 'English',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: DropdownButton<String>(
              value: locale,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'fa', child: Text('فارسی')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(currentLocaleProvider.notifier).state = val;
                }
              },
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_rounded, color: Colors.cyanAccent),
            title: Text(
              locale == 'fa' ? 'نمایش کامل آدرس آی‌پی' : 'Show Full IP Address',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              locale == 'fa'
                  ? 'نمایش تمام ارقام آی‌پی سرورها بدون ماسک کردن ستاره‌ای'
                  : 'Display unmasked IP addresses for servers instead of masking with stars',
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
            value: showFullIp,
            onChanged: (val) {
              ref.read(showFullIpProvider.notifier).state = val;
            },
          ),
        ],
      ),
    );
  }

  /// Builds a selectable theme chip button with icon and label.
  Widget _buildThemeChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent.withValues(alpha: 0.18) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppTheme.primaryAccent : Colors.grey),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
