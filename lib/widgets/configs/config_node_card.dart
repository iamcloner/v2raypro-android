// File: lib/widgets/configs/config_node_card.dart
// Description: Card widget representing a custom proxy node in the Android configs list.
// Displays node name, protocol/network type, masked address, country and CDN badges,
// active status, real delay ping, and an action menu for editing, sharing, and deleting.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cdn_provider.dart';
import '../../models/proxy_node.dart';
import '../../utils/ip_mask_util.dart';
import '../country_flag_badge.dart';

/// Card displaying a proxy server with tap-to-activate support.
///
/// Presents technical info such as latency, protocol type, transport network,
/// country, and an action menu in a compact and clean layout.
class ConfigNodeCard extends StatelessWidget {
  final ProxyNode node;
  final bool isTesting;
  final bool showFullIp;
  final CdnProvider? cdn;
  final String? displayCountryCode;
  final String? displayCountry;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onPing;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const ConfigNodeCard({
    super.key,
    required this.node,
    required this.isTesting,
    required this.showFullIp,
    required this.cdn,
    required this.displayCountryCode,
    required this.displayCountry,
    required this.locale,
    required this.onTap,
    required this.onPing,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: node.isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: node.isActive
            ? const BorderSide(color: AppTheme.primaryAccent, width: 2.0)
            : BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      color: node.isActive
          ? AppTheme.primaryAccent.withValues(alpha: 0.08)
          : Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      node.protocol.name.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontWeight: node.isActive ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                        color: node.isActive ? Colors.white : Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (cdn != null) ...[
                    const SizedBox(width: 4),
                    CdnBadge(cdn: cdn!),
                  ],
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      switch (val) {
                        case 'ping':
                          onPing();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'share':
                          onShare();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'ping',
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 18, color: Colors.cyanAccent),
                            SizedBox(width: 8),
                            Text('Ping test'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 18, color: Colors.amberAccent),
                            const SizedBox(width: 8),
                            Text(AppStrings.get('edit_config', locale: locale)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            const Icon(Icons.share, size: 18, color: Colors.purpleAccent),
                            const SizedBox(width: 8),
                            Text(AppStrings.get('share_config', locale: locale)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${IpMaskUtil.mask(node.address, showFull: showFullIp)}:${node.port}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            node.network.name.toUpperCase(),
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isTesting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    if (displayCountryCode != null && displayCountryCode!.isNotEmpty) ...[
                      CountryPillBadge(
                        countryCode: displayCountryCode,
                        country: displayCountry,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (node.hasValidPing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: Text(
                          '${node.latencyMs} ms',
                          style: const TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (node.hasTimedOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 10, color: AppTheme.errorColor),
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
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
