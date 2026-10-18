// Scanner Clean IP Tile Widget
// Renders an individual responsive clean IP candidate card from the target scanner,
// including ranking, country flag, latency badge, port info, and fast-switch connection button.
// Android touch and accessibility friendly.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/scan_result.dart';
import '../../providers/app_providers.dart';
import '../country_flag_badge.dart';

/// Card displaying a clean IP discovered by the scanner.
/// Presents rank, latency, country flag, and direct-switch or copy buttons.
class ScannerCleanIpTile extends ConsumerWidget {
  final ScanResult res;
  final int index;
  final String locale;
  final String? connectedIp;

  /// Creates the scanner clean IP card widget.
  const ScannerCleanIpTile({
    super.key,
    required this.res,
    required this.index,
    required this.locale,
    this.connectedIp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lat = res.totalLatencyMs ?? res.tcpLatencyMs ?? 0;
    final isTop = index == 0;
    final isConnected = connectedIp != null && res.ip == connectedIp;

    Color badgeColor;
    if (lat < 120) {
      badgeColor = AppTheme.successColor;
    } else if (lat < 250) {
      badgeColor = Colors.amber;
    } else {
      badgeColor = AppTheme.errorColor;
    }

    return Card(
      color: isConnected
          ? AppTheme.successColor.withValues(alpha: 0.08)
          : (isTop
              ? AppTheme.primaryAccent.withValues(alpha: 0.08)
              : Theme.of(context).cardColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isConnected
            ? const BorderSide(color: AppTheme.successColor, width: 1.2)
            : (isTop
                ? BorderSide(color: AppTheme.primaryAccent.withValues(alpha: 0.5), width: 1.0)
                : BorderSide.none),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            _buildRankBadge(context, isTop, isConnected),
            const SizedBox(width: 12),
            Expanded(child: _buildIpDetails(isConnected)),
            _buildLatencyChip(lat, badgeColor),
            const SizedBox(width: 8),
            _buildCopyButton(context),
            if (isConnected) _buildActiveButton() else _buildSwitchButton(context, ref, lat),
          ],
        ),
      ),
    );
  }

  /// Builds the quality ranking indicator badge (#1, #2, ...).
  Widget _buildRankBadge(BuildContext context, bool isTop, bool isConnected) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isConnected
            ? AppTheme.successColor.withValues(alpha: 0.2)
            : (isTop
                ? Colors.amber.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isConnected
              ? AppTheme.successColor
              : (isTop ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// Renders IP address details, country flag, and server port.
  Widget _buildIpDetails(bool isConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (res.countryCode != null) ...[
              CountryFlagBadge(
                countryCode: res.countryCode,
                width: 20,
                height: 14,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              res.ip,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (isConnected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 11, color: AppTheme.successColor),
                    const SizedBox(width: 3),
                    Text(
                      AppStrings.get('currently_active', locale: locale),
                      style: const TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${AppStrings.get('server_port', locale: locale)}: ${res.port}  •  ${res.latencyTier}',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  /// Builds the dynamically colored ping latency chip.
  Widget _buildLatencyChip(int lat, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$lat ms',
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          color: badgeColor,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Builds the clipboard copy button for the IP address.
  Widget _buildCopyButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 18),
      tooltip: AppStrings.get('copy_ip', locale: locale),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: res.ip));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('ip_copied', locale: locale))),
        );
      },
    );
  }

  /// Builds the badge indicating this IP is currently active.
  Widget _buildActiveButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.25),
        foregroundColor: AppTheme.successColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: const Icon(Icons.check_rounded, size: 16),
      label: Text(
        AppStrings.get('currently_active', locale: locale),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      onPressed: null,
    );
  }

  /// Builds the button to immediately switch the active config's address to this clean IP.
  Widget _buildSwitchButton(BuildContext context, WidgetRef ref, int lat) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryAccent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
      label: Text(
        AppStrings.get('switch_ip', locale: locale),
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () async {
        await ref.read(scannerProvider.notifier).connectToCandidateIp(res.ip, lat);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('IP ${res.ip} ($lat ms) ${AppStrings.get('connected', locale: locale)}'),
          ),
        );
      },
    );
  }
}
