// Scanner Connected IP Card
// Displays the active connected clean IP address discovered by the scanner,
// latency improvements, radar scanning animation, and radar data warning notices.
// Optimized for Android touch interactions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../providers/scanner_state.dart';

/// Card displaying the currently connected and active clean IP from the scanner.
/// Displays radar animation, bandwidth consumption notice, and details of the best discovered IP.
class ScannerConnectedCard extends ConsumerWidget {
  final ScannerState state;
  final ProxyNode? activeNode;
  final String locale;
  final bool isPortrait;
  final Animation<double> pulseAnimation;

  /// Creates the scanner connected IP card.
  const ScannerConnectedCard({
    super.key,
    required this.state,
    required this.activeNode,
    required this.locale,
    this.isPortrait = false,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasConnectedIp = state.connectedIp != null && state.currentBestLatency != null;
    final showTrafficNotice = state.isScanning && state.showRadarTrafficWarning;

    return SizedBox(
      height: isPortrait ? null : 280,
      child: Card(
        color: hasConnectedIp
            ? AppTheme.primaryAccent.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              if (showTrafficNotice) _buildTrafficNoticeBanner(context, ref),
              if (!isPortrait) const Spacer() else const SizedBox(height: 12),
              _buildPulseIcon(hasConnectedIp, showTrafficNotice),
              SizedBox(height: showTrafficNotice ? 6 : 10),
              if (hasConnectedIp)
                ..._buildConnectedDetails(context)
              else
                ..._buildIdleOrSearchingDetails(context),
              if (!isPortrait) const Spacer() else const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the radar internet bandwidth consumption warning banner.
  Widget _buildTrafficNoticeBanner(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700, width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppStrings.get('radar_traffic_warning', locale: locale),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => ref.read(scannerProvider.notifier).dismissRadarWarning(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the animated pulsing radar icon matching the scan state.
  Widget _buildPulseIcon(bool hasConnectedIp, bool showTrafficNotice) {
    return ScaleTransition(
      scale: (state.isScanning && state.strategy == ScannerStrategy.radar)
          ? pulseAnimation
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: EdgeInsets.all(showTrafficNotice ? 8 : 12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (hasConnectedIp
                  ? AppTheme.successColor
                  : (state.isScanning ? AppTheme.primaryAccent : Colors.grey))
              .withValues(alpha: 0.15),
          border: Border.all(
            color: (hasConnectedIp
                    ? AppTheme.successColor
                    : (state.isScanning ? AppTheme.primaryAccent : Colors.grey))
                .withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.radar_rounded,
          size: showTrafficNotice ? 26 : 34,
          color: hasConnectedIp
              ? AppTheme.successColor
              : (state.isScanning ? AppTheme.primaryAccent : Colors.grey),
        ),
      ),
    );
  }

  /// Builds connected IP details including address, latency, and copy button.
  List<Widget> _buildConnectedDetails(BuildContext context) {
    return [
      Text(
        AppStrings.get('current_active_ip', locale: locale),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 3),
      SelectableText(
        state.connectedIp!,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: AppTheme.successColor, size: 14),
            const SizedBox(width: 4),
            Text(
              '${state.currentBestLatency} ms  •  ${AppStrings.get('connected', locale: locale)}',
              style: const TextStyle(
                color: AppTheme.successColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.copy_rounded, size: 12),
        label: Text(
          AppStrings.get('copy_ip', locale: locale),
          style: const TextStyle(fontSize: 11),
        ),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: state.connectedIp!));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.get('ip_copied', locale: locale))),
          );
        },
      ),
    ];
  }

  /// Builds status messages for actively scanning or idle radar states.
  List<Widget> _buildIdleOrSearchingDetails(BuildContext context) {
    return [
      Text(
        state.isScanning
            ? AppStrings.get('searching_clean_ip', locale: locale)
            : AppStrings.get('radar_ready', locale: locale),
        style: TextStyle(
          color: state.isScanning ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          state.isScanning
              ? AppStrings.get('radar_first_connect_hint', locale: locale)
              : AppStrings.get('radar_start_prompt', locale: locale),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ];
  }
}
