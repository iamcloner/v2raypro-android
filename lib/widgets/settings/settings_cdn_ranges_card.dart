// Settings CDN CIDR Ranges Management Card
// Allows inspecting, modifying, saving, and restoring default CIDR IP ranges
// for supported CDN providers (Cloudflare, CloudFront, Fastly, GCore).
// Built for Android touch interaction.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/cdn_scanner_service.dart';

/// CDN IP ranges management card widget.
/// Enables viewing and editing subnets for supported CDN providers used by the scanner.
class SettingsCdnRangesCard extends ConsumerStatefulWidget {
  final String locale;

  /// Creates the CDN ranges card.
  const SettingsCdnRangesCard({
    super.key,
    required this.locale,
  });

  @override
  ConsumerState<SettingsCdnRangesCard> createState() => _SettingsCdnRangesCardState();
}

class _SettingsCdnRangesCardState extends ConsumerState<SettingsCdnRangesCard> {
  CdnProvider _selectedCdn = CdnProvider.cloudflare;
  late TextEditingController _cdnRangesController;

  @override
  void initState() {
    super.initState();
    final cdnRanges = ref.read(cdnRangesProvider);
    final currentList = cdnRanges[_selectedCdn] ?? _selectedCdn.defaultCidrs;
    _cdnRangesController = TextEditingController(text: currentList.join('\n'));
  }

  @override
  void dispose() {
    _cdnRangesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final cdnRanges = ref.watch(cdnRangesProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.network_ping_rounded, color: AppTheme.secondaryAccent),
        title: Text(
          AppStrings.get('cdn_ranges_title', locale: locale),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${cdnRanges[_selectedCdn]?.length ?? 0} CIDR ranges for ${_selectedCdn.displayName}  •  Tap to view / edit',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.get('cdn_ranges_desc', locale: locale),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CdnProvider.values.map((cdn) {
                    final isSelected = _selectedCdn == cdn;
                    return ChoiceChip(
                      label: Text(cdn.displayName),
                      selected: isSelected,
                      selectedColor: AppTheme.secondaryAccent.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCdn = cdn;
                            final list = ref.read(cdnRangesProvider)[cdn] ?? cdn.defaultCidrs;
                            _cdnRangesController.text = list.join('\n');
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cdnRangesController,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: AppStrings.get('cf_ranges_hint', locale: locale),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: Text(AppStrings.get('reset_default', locale: locale), style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        ref.read(cdnRangesProvider.notifier).resetToDefault(_selectedCdn);
                        setState(() {
                          _cdnRangesController.text = _selectedCdn.defaultCidrs.join('\n');
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.get('ranges_reset', locale: locale))),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: Text(AppStrings.get('save_ranges', locale: locale), style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        final lines = _cdnRangesController.text
                            .split('\n')
                            .map((l) => l.trim())
                            .where((l) => l.isNotEmpty && !l.startsWith('#'))
                            .toList();
                        ref.read(cdnRangesProvider.notifier).updateRanges(_selectedCdn, lines);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.get('ranges_saved', locale: locale))),
                        );
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
