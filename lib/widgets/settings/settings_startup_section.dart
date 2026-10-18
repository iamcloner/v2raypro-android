// Settings Startup & Automation Section
// Manages auto-connect on application launch and background behavior preferences.
// Android touch and battery optimization aware.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../providers/app_providers.dart';

/// Startup and automated connection settings section widget.
/// Enables automatic connection to the last active proxy server when launching the app.
class SettingsStartupSection extends ConsumerWidget {
  final String locale;

  /// Creates the startup settings section.
  const SettingsStartupSection({
    super.key,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoConnectOnLaunch = ref.watch(autoConnectOnLaunchProvider);

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.flash_on_rounded, color: Colors.amber),
        title: Text(
          AppStrings.get('auto_connect_on_launch', locale: locale),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          AppStrings.get('auto_connect_on_launch_desc', locale: locale),
          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        value: autoConnectOnLaunch,
        onChanged: (val) {
          ref.read(autoConnectOnLaunchProvider.notifier).toggle(val);
        },
      ),
    );
  }
}
