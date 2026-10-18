// Dashboard Outbound IP & Connection Info Card
// Renders the outbound public IP location details, geolocation flags, ISP name,
// IPv4/IPv6 address items, live ping latency retest, and elapsed session timer.
// Fully optimized for Android touch and clipboard features.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/outbound_info.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../services/country_service.dart';
import '../../services/real_delay_service.dart';
import '../../utils/ip_mask_util.dart';
import '../country_flag_badge.dart';
import 'ip_info_tile.dart';

/// Card displaying outbound IP details, geolocation, and connection duration.
/// Displays IPv4/IPv6 addresses, ping latency, elapsed connection time, and country info.
class IpInfoCard extends StatefulWidget {
  final WidgetRef ref;
  final OutboundInfo outbound;
  final ProxyNode? activeNode;
  final String locale;
  final bool isConnected;
  final DateTime? connectedAt;
  final bool showFullIp;

  /// Creates the IP info and connection latency card.
  const IpInfoCard({
    super.key,
    required this.ref,
    required this.outbound,
    required this.activeNode,
    required this.locale,
    required this.isConnected,
    required this.connectedAt,
    required this.showFullIp,
  });

  @override
  State<IpInfoCard> createState() => _IpInfoCardState();
}

class _IpInfoCardState extends State<IpInfoCard> {
  bool _isTestingPing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outbound = widget.outbound;
    final locale = widget.locale;
    final isConnected = widget.isConnected;
    final activeNode = widget.activeNode;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeaderRow(context, outbound, activeNode, locale, isConnected),
            Divider(height: 20, color: theme.dividerColor),
            Row(
              children: [
                Expanded(
                  child: IpInfoTile(
                    title: AppStrings.get('ipv4_address', locale: locale),
                    value: isConnected
                        ? (outbound.ipv4 != null
                            ? IpMaskUtil.mask(outbound.ipv4!, showFull: widget.showFullIp)
                            : (outbound.isLoading ? '...' : '--'))
                        : '--',
                    icon: Icons.lan_rounded,
                    color: const Color(0xFF38BDF8),
                    copyable: isConnected && outbound.ipv4 != null,
                    copyValue: outbound.ipv4,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: IpInfoTile(
                    title: AppStrings.get('ipv6_address', locale: locale),
                    value: isConnected
                        ? (outbound.ipv6 != null
                            ? IpMaskUtil.mask(outbound.ipv6!, showFull: widget.showFullIp)
                            : (outbound.isLoading ? '...' : AppStrings.get('not_supported', locale: locale)))
                        : '--',
                    icon: Icons.alt_route_rounded,
                    color: const Color(0xFFA78BFA),
                    copyable: isConnected && outbound.ipv6 != null,
                    copyValue: outbound.ipv6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: IpPingTile(
                    title: AppStrings.get('ping', locale: locale),
                    latency: isConnected ? activeNode?.latencyMs : null,
                    isTesting: _isTestingPing,
                    onRetest: (isConnected && activeNode != null) ? () => _retestPing(activeNode) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: IpInfoTile(
                    title: AppStrings.get('connection_duration', locale: locale),
                    value: isConnected ? _formatDuration(widget.connectedAt) : "00:00:00",
                    icon: Icons.timer_outlined,
                    color: isConnected ? AppTheme.successColor : Colors.grey,
                    copyable: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the header row with country name, flag, ISP, refresh button, and visibility toggle.
  Widget _buildHeaderRow(
    BuildContext context,
    OutboundInfo outbound,
    ProxyNode? activeNode,
    String locale,
    bool isConnected,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: (isConnected ? AppTheme.primaryAccent : Colors.grey.shade700).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.public_rounded,
            size: 20,
            color: isConnected ? AppTheme.primaryAccent : Colors.grey,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected
                    ? AppStrings.get('connected_country', locale: locale)
                    : AppStrings.get('outbound_ip', locale: locale),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (isConnected)
                Row(
                  children: [
                    CountryFlagBadge(
                      countryCode: outbound.countryCode ?? activeNode?.countryCode ?? (activeNode != null ? CountryService.resolveSync(activeNode) : null),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        outbound.country != null
                            ? '${outbound.country!}${outbound.city != null ? ' (${outbound.city})' : ''}'
                            : (activeNode?.country != null
                                ? activeNode!.country!
                                : (activeNode?.countryCode != null && CountryService.getCountryName(activeNode!.countryCode) != null
                                    ? CountryService.getCountryName(activeNode!.countryCode)!
                                    : (outbound.isLoading
                                        ? AppStrings.get('fetching_ip', locale: locale)
                                        : AppStrings.get('unknown_location', locale: locale)))),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (outbound.isp != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '•  ${outbound.isp}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                )
              else
                Text(
                  AppStrings.get('offline_hint', locale: locale),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: AppStrings.get(widget.showFullIp ? 'hide_ip' : 'show_full_ip', locale: locale),
          icon: Icon(
            widget.showFullIp ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 19,
            color: widget.showFullIp ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            widget.ref.read(showFullIpProvider.notifier).state = !widget.showFullIp;
          },
        ),
        IconButton(
          tooltip: AppStrings.get('refresh_ip', locale: locale),
          icon: outbound.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: isConnected ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.grey.shade600,
                ),
          onPressed: (!isConnected || outbound.isLoading)
              ? null
              : () => widget.ref.read(outboundInfoProvider.notifier).fetch(),
        ),
      ],
    );
  }


  /// Re-tests real delay latency for the currently connected server.
  Future<void> _retestPing(ProxyNode node) async {
    if (_isTestingPing) return;
    setState(() => _isTestingPing = true);
    final testMode = widget.ref.read(testModeProvider);
    final res = await testRealDelay(
      mode: testMode == TestMode.turbo ? 'turbo' : 'normal',
      type: 'xray',
      config: node.toJson(),
    );
    if (mounted) {
      widget.ref.read(nodesProvider.notifier).updateLatency(
        node.id,
        res.ping,
        countryCode: res.country?.toUpperCase(),
        country: res.countryName,
      );
      setState(() => _isTestingPing = false);
    }
  }

  /// Formats the elapsed connection duration into HH:MM:SS.
  String _formatDuration(DateTime? connectedAt) {
    if (connectedAt == null) return "00:00:00";
    final diff = DateTime.now().difference(connectedAt);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }
}
