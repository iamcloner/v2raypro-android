// Subscription Node Tile Widget
// Renders an individual proxy configuration card inside a subscription expansion list.
// Displays connection status, protocol, CDN badges, latency, country flags, and node action menus.
// Tailored for smooth scrolling and touch targets on Android devices.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cdn_provider.dart';
import '../../models/proxy_node.dart';
import '../../utils/ip_mask_util.dart';
import '../country_flag_badge.dart';
import '../edit_config_dialog.dart';

/// Proxy configuration tile widget for subscription items.
/// Displays server details, ping latency, country flag, and options popup menu.
class SubNodeTile extends StatelessWidget {
  final ProxyNode node;
  final bool isTesting;
  final bool showFullIp;
  final CdnProvider? cdn;
  final String? displayCountryCode;
  final String? displayCountry;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onTestLatency;

  /// Creates the subscription node tile widget.
  const SubNodeTile({
    super.key,
    required this.node,
    required this.isTesting,
    required this.showFullIp,
    required this.cdn,
    required this.displayCountryCode,
    required this.displayCountry,
    required this.locale,
    required this.onTap,
    required this.onTestLatency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: node.isActive ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: node.isActive
              ? const BorderSide(color: AppTheme.primaryAccent, width: 2.0)
              : BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
        ),
        color: node.isActive
            ? AppTheme.primaryAccent.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeaderRow(context),
                const SizedBox(height: 5),
                _buildDetailsRow(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the top header row with protocol badge, config name, CDN badge, and options menu.
  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            node.protocol.name.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primaryAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            node.name,
            style: TextStyle(
              fontWeight: node.isActive ? FontWeight.bold : FontWeight.w600,
              fontSize: 12.5,
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
        _buildPopupMenu(context),
      ],
    );
  }

  /// Builds the details row with address, network type, country badge, and ping latency button.
  Widget _buildDetailsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${IpMaskUtil.mask(node.address, showFull: showFullIp)}:${node.port}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
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
                  style: TextStyle(fontSize: 8.5, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
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
              countryCode: displayCountryCode!,
              country: displayCountry,
            ),
            const SizedBox(width: 5),
          ],
          _buildLatencyBadge(),
        ],
      ],
    );
  }

  /// Builds the latency badge, timeout indicator, or bolt icon for instant re-testing.
  Widget _buildLatencyBadge() {
    if (node.hasValidPing) {
      return InkWell(
        onTap: onTestLatency,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Text(
            "${node.latencyMs} ms",
            style: const TextStyle(
              color: AppTheme.successColor,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (node.hasTimedOut) {
      return InkWell(
        onTap: onTestLatency,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                AppStrings.get("timeout", locale: locale),
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: onTestLatency,
        borderRadius: BorderRadius.circular(4),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(Icons.bolt_rounded, size: 16, color: Colors.cyanAccent),
        ),
      );
    }
  }

  /// Builds the options popup menu for pinging, editing, and sharing configuration links.
  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      padding: EdgeInsets.zero,
      onSelected: (val) {
        if (val == 'ping') {
          onTestLatency();
        } else if (val == 'edit') {
          EditConfigDialog.show(context, node, locale);
        } else if (val == 'share') {
          Clipboard.setData(ClipboardData(text: node.toShareUrl()));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.get("share_copied", locale: locale))),
          );
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'ping',
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Text(AppStrings.get('retest_ping', locale: locale)),
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
      ],
    );
  }
}
