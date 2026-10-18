// File: lib/widgets/free_configs/free_config_card.dart
// Description: Card widget representing a free proxy configuration on Android.
// Displays node information, country flag, ping latency, CDN badge, and connection button.
// Modular and optimized for smooth scrolling performance in list views.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cdn_provider.dart';
import '../../models/proxy_node.dart';
import '../../utils/ip_mask_util.dart';
import '../country_flag_badge.dart';

/// Card displaying a free proxy configuration with details and connect action button.
///
/// Presents connection status, real delay ping, country, protocol type, and server address,
/// with support for retesting latency and direct server connection.
class FreeConfigCard extends StatelessWidget {
  final ProxyNode node;
  final bool isThisNodeActive;
  final bool isThisNodeConnected;
  final bool isThisNodeConnecting;
  final bool isTesting;
  final bool showFullIp;
  final String? displayCountryCode;
  final String? displayCountry;
  final CdnProvider? cdn;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onRetest;
  final VoidCallback onConnect;

  const FreeConfigCard({
    super.key,
    required this.node,
    required this.isThisNodeActive,
    required this.isThisNodeConnected,
    required this.isThisNodeConnecting,
    required this.isTesting,
    required this.showFullIp,
    required this.displayCountryCode,
    required this.displayCountry,
    required this.cdn,
    required this.locale,
    required this.onTap,
    required this.onRetest,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: isThisNodeActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isThisNodeActive
            ? const BorderSide(color: AppTheme.primaryAccent, width: 2.0)
            : BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      color: isThisNodeActive
          ? AppTheme.primaryAccent.withValues(alpha: 0.08)
          : Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CountryPillBadge(
                countryCode: displayCountryCode,
                country: displayCountry,
                showUnknown: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            node.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isThisNodeConnected ? AppTheme.primaryAccent : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cdn != null) ...[
                          const SizedBox(width: 6),
                          CdnBadge(cdn: cdn!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${IpMaskUtil.mask(node.address, showFull: showFullIp)}:${node.port}  •  ${node.protocol.name.toUpperCase()}  •  ${node.network.name.toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildLatencyBadge(context),
              const SizedBox(width: 6),
              _buildActionButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the latency status indicator badge and node retest button.
  Widget _buildLatencyBadge(BuildContext context) {
    if (isTesting) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (node.hasValidPing)
          InkWell(
            onTap: onRetest,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Text(
                '${node.latencyMs} ms',
                style: const TextStyle(
                  color: AppTheme.successColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else if (node.hasTimedOut)
          InkWell(
            onTap: onRetest,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 11, color: AppTheme.errorColor),
                  const SizedBox(width: 3),
                  Text(
                    AppStrings.get('timeout', locale: locale),
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.cyanAccent),
          tooltip: AppStrings.get('retest_ping', locale: locale),
          onPressed: onRetest,
        ),
      ],
    );
  }

  /// Builds the connect or disconnect action button.
  Widget _buildActionButton(BuildContext context) {
    if (isThisNodeConnecting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isThisNodeConnected ? Colors.redAccent.shade700 : AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      onPressed: onConnect,
      child: Text(
        isThisNodeConnected
            ? AppStrings.get('disconnect', locale: locale)
            : AppStrings.get('connect', locale: locale),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
