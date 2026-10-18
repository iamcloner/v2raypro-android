// Dashboard Connect Button Card
// Central connection action card featuring the primary power toggle button,
// connection state indicators, active proxy server info, and Android VPN conflict checks.
// Designed with prominent touch feedback for Android devices.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../services/cdn_scanner_service.dart';
import '../../services/country_service.dart';
import '../../services/xray_process_service.dart';
import '../../utils/ip_mask_util.dart';
import '../country_flag_badge.dart';

/// Main connection action button card in the dashboard.
/// Provides the circular connect/disconnect toggle, network status, and active server details.
class ConnectButtonCard extends ConsumerWidget {
  final ConnectionStateEnum status;
  final List<ProxyNode> nodes;
  final ProxyNode? activeNode;
  final String locale;
  final bool isConnected;
  final bool isConnecting;
  final CdnProvider? activeCdn;
  final bool showFullIp;

  /// Creates the dashboard connection action card.
  const ConnectButtonCard({
    super.key,
    required this.status,
    required this.nodes,
    required this.activeNode,
    required this.locale,
    required this.isConnected,
    required this.isConnecting,
    required this.activeCdn,
    required this.showFullIp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = isConnected
        ? AppTheme.successColor
        : (isConnecting ? AppTheme.primaryAccent : Colors.grey.shade400);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircularButton(context, ref),
            const SizedBox(height: 12),
            Text(
              nodes.isEmpty
                  ? AppStrings.get('no_nodes', locale: locale)
                  : isConnected
                      ? AppStrings.get('connected', locale: locale)
                      : isConnecting
                          ? AppStrings.get('connecting', locale: locale)
                          : AppStrings.get('disconnected', locale: locale),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
              textAlign: TextAlign.center,
            ),
            if (activeNode != null) ...[
              const SizedBox(height: 6),
              _buildActiveNodeDetails(ref),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the circular power toggle button for turning proxy on and off.
  Widget _buildCircularButton(BuildContext context, WidgetRef ref) {
    final circleBg = (isConnected
            ? AppTheme.successColor
            : (isConnecting ? AppTheme.primaryAccent : Colors.grey.shade800))
        .withValues(alpha: 0.15);
    final borderColor = isConnected
        ? AppTheme.successColor
        : (isConnecting ? AppTheme.primaryAccent : Colors.grey.shade700);

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: circleBg,
        border: Border.all(color: borderColor, width: 2.8),
      ),
      child: Center(
        child: IconButton(
          iconSize: 40,
          icon: isConnecting
              ? const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryAccent),
                )
              : Icon(
                  isConnected ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                  color: isConnected
                      ? AppTheme.successColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.primaryAccent),
                ),
          onPressed: nodes.isEmpty || isConnecting ? null : () => _handleConnect(context, ref),
        ),
      ),
    );
  }

  /// Builds the row showing flag, name, masked address, and CDN badge of the active node.
  Widget _buildActiveNodeDetails(WidgetRef ref) {
    final outbound = ref.watch(outboundInfoProvider);
    final displayCode = isConnected
        ? (outbound.countryCode ?? activeNode!.countryCode ?? CountryService.resolveSync(activeNode!))
        : (activeNode!.countryCode ?? CountryService.resolveSync(activeNode!));
    final displayCountry = isConnected
        ? (outbound.country ?? activeNode!.country ?? (displayCode != null ? CountryService.getCountryName(displayCode) : null))
        : activeNode!.country;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CountryPillBadge(
          countryCode: displayCode,
          country: displayCountry,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${activeNode!.name} (${IpMaskUtil.mask(activeNode!.address, showFull: showFullIp)}:${activeNode!.port})',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (activeCdn != null) ...[
          const SizedBox(width: 6),
          CdnBadge(cdn: activeCdn!),
        ],
      ],
    );
  }

  /// Handles connect/disconnect requests and checks for conflicting Android VPNs.
  Future<void> _handleConnect(BuildContext context, WidgetRef ref) async {
    if (!isConnected) {
      final hasOtherVpn = await XrayProcessService.instance.isAnotherVpnActive();
      if (hasOtherVpn && context.mounted) {
        final proceed = await _showVpnConflictDialog(context);
        if (proceed != true) return;
      }
      final isTun = ref.read(isTunEnabledProvider);
      if (isTun) {
        final prepOk = await XrayProcessService.instance.prepareAndroidVpn();
        if (!prepOk) return;
      }
    }
    ref.read(connectionStatusProvider.notifier).toggleConnect();
  }

  /// Dialog warning the user of another active VPN connection on the Android device.
  Future<bool?> _showVpnConflictDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                locale == 'fa' ? 'هشدار اتصال وی‌پی‌ان' : 'VPN Conflict Warning',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          locale == 'fa'
              ? 'یک وی‌پی‌ان دیگر در گوشی شما فعال است. اتصال همزمان به دو فیلترشکن ممکن است باعث قطع ارتباط اینترنت شود. آیا مایل به ادامه اتصال هستید؟'
              : 'Another VPN connection is currently active on your device. Running multiple VPNs simultaneously may disrupt network access. Do you wish to continue?',
          style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(locale == 'fa' ? 'انصراف' : 'Cancel', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(locale == 'fa' ? 'ادامه اتصال' : 'Proceed'),
          ),
        ],
      ),
    );
  }
}
