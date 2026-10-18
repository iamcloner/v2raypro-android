// Settings Config Testing & Concurrency Section
// Configures latency testing performance mode (Normal vs Turbo)
// and worker thread concurrency slider for batch ping operations.
// Optimized for Android multicore CPU architectures.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Latency testing method and concurrency settings section widget.
/// Configures testing mode (Normal vs Turbo) and maximum concurrent ping test limit.
class SettingsTestSection extends ConsumerWidget {
  final String locale;

  /// Creates the config testing settings section.
  const SettingsTestSection({
    super.key,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testMode = ref.watch(testModeProvider);
    final testConcurrency = ref.watch(testConcurrencyProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            _buildTestModeRow(context, ref, testMode),
            const Divider(height: 1),
            _buildConcurrencyRow(context, ref, testConcurrency),
          ],
        ),
      ),
    );
  }

  /// Builds the test mode selection row (Normal or Turbo).
  Widget _buildTestModeRow(BuildContext context, WidgetRef ref, TestMode testMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppTheme.primaryAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.get('test_mode', locale: locale),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTestModeChip(
                  context: context,
                  label: AppStrings.get('test_mode_normal', locale: locale),
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppTheme.primaryAccent,
                  isSelected: testMode == TestMode.normal,
                  onTap: () => ref.read(testModeProvider.notifier).setMode(TestMode.normal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTestModeChip(
                  context: context,
                  label: AppStrings.get('test_mode_turbo', locale: locale),
                  icon: Icons.bolt_rounded,
                  iconColor: Colors.amber,
                  isSelected: testMode == TestMode.turbo,
                  onTap: () => ref.read(testModeProvider.notifier).setMode(TestMode.turbo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a test mode selection chip button with icon and label.
  Widget _buildTestModeChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent.withValues(alpha: 0.18) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? iconColor : Colors.grey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the slider for adjusting concurrent ping test limits.
  Widget _buildConcurrencyRow(BuildContext context, WidgetRef ref, int testConcurrency) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: AppTheme.secondaryAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.get('test_concurrency', locale: locale),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.secondaryAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$testConcurrency',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('test_concurrency_desc', locale: locale),
            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            ),
            child: Slider(
              value: testConcurrency.toDouble(),
              min: 5.0,
              max: 100.0,
              divisions: 95,
              label: '$testConcurrency',
              activeColor: AppTheme.secondaryAccent,
              onChanged: (val) {
                ref.read(testConcurrencyProvider.notifier).setConcurrency(val.round());
              },
            ),
          ),
        ],
      ),
    );
  }
}
