// Dashboard View Screen
// Primary home view presenting the main VPN connection toggle,
// public outbound IP address details, latency indicators, and live network traffic metrics.
// Optimized for Android touch interactions and high frame-rate rendering.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../services/cdn_scanner_service.dart';
import '../../services/xray_process_service.dart';
import 'connect_button_card.dart';
import 'ip_info_card.dart';
import 'traffic_metrics_row.dart';

/// Main application dashboard view.
/// Houses the primary connect button, IP information card, and download/upload traffic metrics.
class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  Timer? _ticker;
  bool _hasOtherVpn = false;
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        if (_tickCount++ % 2 == 0) {
          final status = ref.read(connectionStatusProvider);
          if (status == ConnectionStateEnum.disconnected) {
            XrayProcessService.instance.isAnotherVpnActive().then((active) {
              if (mounted && _hasOtherVpn != active) {
                setState(() => _hasOtherVpn = active);
              }
            });
          } else if (_hasOtherVpn) {
            setState(() => _hasOtherVpn = false);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionStatusProvider);
    final nodes = ref.watch(nodesProvider);
    final activeNode = nodes.isEmpty ? null : nodes.firstWhere((n) => n.isActive, orElse: () => nodes.first);
    final locale = ref.watch(currentLocaleProvider);
    final connectedAt = ref.watch(connectedAtProvider);
    final outbound = ref.watch(outboundInfoProvider);
    final traffic = ref.watch(trafficStatsProvider);
    final cdnMap = ref.watch(nodeCdnMapProvider);
    final showFullIp = ref.watch(showFullIpProvider);

    final isConnected = status == ConnectionStateEnum.connected;
    final isConnecting = status == ConnectionStateEnum.connecting;
    final activeCdn = activeNode != null
        ? (cdnMap[activeNode.address.trim().toLowerCase()] ??
            ref.read(nodeCdnMapProvider.notifier).detectCdn(activeNode.address))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasOtherVpn && !isConnected) ...[
            _buildVpnConflictNotice(locale),
            const SizedBox(height: 12),
          ],
          ConnectButtonCard(
            status: status,
            nodes: nodes,
            activeNode: activeNode,
            locale: locale,
            isConnected: isConnected,
            isConnecting: isConnecting,
            activeCdn: activeCdn,
            showFullIp: showFullIp,
          ),
          const SizedBox(height: 14),
          IpInfoCard(
            ref: ref,
            outbound: outbound,
            activeNode: activeNode,
            locale: locale,
            isConnected: isConnected,
            connectedAt: connectedAt,
            showFullIp: showFullIp,
          ),
          const SizedBox(height: 14),
          TrafficMetricsRow(
            traffic: traffic,
            isConnected: isConnected,
            locale: locale,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Banner warning about another active VPN in the Android background.
  Widget _buildVpnConflictNotice(String locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade700, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              locale == 'fa'
                  ? 'یک فیلترشکن دیگر در دستگاه شما فعال است. لطفاً برای جلوگیری از تداخل، آن را قطع کنید.'
                  : 'Another VPN is currently active on your device. Please disconnect it to avoid conflicts.',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
