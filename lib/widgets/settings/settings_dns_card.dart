// Settings DNS Configuration Card
// Manages DNS resolver presets (Cloudflare, Google, AdGuard, Quad9)
// and custom DNS server address entries.
// Designed for Android touch interfaces.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/dns_settings.dart';
import '../../providers/app_providers.dart';

/// DNS server configuration card widget.
/// Allows selecting trusted DNS provider presets or configuring custom server addresses.
class SettingsDnsCard extends ConsumerStatefulWidget {
  final String locale;

  /// Creates the DNS settings card.
  const SettingsDnsCard({
    super.key,
    required this.locale,
  });

  @override
  ConsumerState<SettingsDnsCard> createState() => _SettingsDnsCardState();
}

class _SettingsDnsCardState extends ConsumerState<SettingsDnsCard> {
  late TextEditingController _dnsServersController;

  @override
  void initState() {
    super.initState();
    final dnsSettings = ref.read(dnsSettingsProvider);
    _dnsServersController = TextEditingController(text: dnsSettings.servers.join('\n'));
  }

  @override
  void dispose() {
    _dnsServersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final dnsSettings = ref.watch(dnsSettingsProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.dns_rounded, color: AppTheme.primaryAccent),
        title: Text(
          AppStrings.get('dns_settings_title', locale: locale),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${dnsSettings.servers.length} servers configured (${dnsSettings.presetId.toUpperCase()})  •  Tap to view / edit',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.get('dns_settings_desc', locale: locale),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DnsSettings.presets.map((preset) {
                    final isSelected = dnsSettings.presetId == preset.id;
                    return ChoiceChip(
                      label: Text(preset.name),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryAccent.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(dnsSettingsProvider.notifier).setPreset(preset.id);
                          if (preset.id != 'custom') {
                            _dnsServersController.text = preset.servers.join('\n');
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dnsServersController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: AppStrings.get('custom_dns_hint', locale: locale),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: Text(AppStrings.get('save_dns', locale: locale)),
                      onPressed: () {
                        final servers = _dnsServersController.text
                            .split(RegExp(r'[\n,]'))
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        if (servers.isNotEmpty) {
                          ref.read(dnsSettingsProvider.notifier).updateCustomServers(servers);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppStrings.get('dns_saved', locale: locale))),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
