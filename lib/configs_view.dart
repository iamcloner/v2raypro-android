// File: lib/configs_view.dart
// Description: Management screen for manual and custom configurations in v2raypro.
// Supports manual entry, clipboard import, camera QR scanning, batch latency testing,
// and quick removal of dead configurations.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'models/proxy_node.dart';
import 'providers/app_providers.dart';
import 'services/country_service.dart';
import 'widgets/add_config_dialog.dart';
import 'widgets/configs/add_config_sheet.dart';
import 'widgets/configs/config_node_card.dart';
import 'widgets/configs/configs_action_helper.dart';
import 'widgets/configs/configs_test_runner.dart';
import 'widgets/country_filter_bar.dart';
import 'widgets/edit_config_dialog.dart';

/// Configuration list view for custom and manual proxy nodes.
///
/// Handles node operations, sorting by ping, parallel latency testing,
/// and synchronization with underlying storage services.
class ConfigsView extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToFreeConfigs;
  final VoidCallback? onOpenDrawer;
  const ConfigsView({super.key, this.onNavigateToFreeConfigs, this.onOpenDrawer});

  @override
  ConsumerState<ConfigsView> createState() => _ConfigsViewState();
}

class _ConfigsViewState extends ConsumerState<ConfigsView> {
  final Set<String> _testingNodeIds = {};
  bool _isTestingAll = false;
  bool _cancelTestingAll = false;
  int _totalToTest = 0;
  int _testedCount = 0;
  String? _selectedCountryCode;
  String? _testRemainingEta;

  /// Tests latency for an individual proxy node.
  Future<void> _testNodeLatency(ProxyNode node) async {
    if (_testingNodeIds.contains(node.id)) return;
    setState(() => _testingNodeIds.add(node.id));
    try {
      await ConfigsTestRunner.testSingleNode(ref, node);
    } finally {
      if (mounted) setState(() => _testingNodeIds.remove(node.id));
    }
  }

  /// Batch-tests latency across all nodes with cancellation and progress reporting.
  Future<void> _testAllNodes(List<ProxyNode> nodes) async {
    if (nodes.isEmpty) return;
    if (_isTestingAll) {
      setState(() => _cancelTestingAll = true);
      return;
    }

    setState(() {
      _selectedCountryCode = null;
      _isTestingAll = true;
      _cancelTestingAll = false;
      _testingNodeIds.addAll(nodes.map((n) => n.id));
      _totalToTest = nodes.length;
      _testedCount = 0;
    });

    try {
      await ConfigsTestRunner.testAllNodes(
        ref: ref,
        nodes: nodes,
        isCancelled: () => _cancelTestingAll || !mounted,
        onProgress: (tested, eta) {
          if (mounted) {
            setState(() {
              _testedCount = tested;
              _testRemainingEta = eta;
            });
          }
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingAll = false;
          _cancelTestingAll = false;
          _testingNodeIds.clear();
          _testRemainingEta = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allNodes = ref.watch(nodesProvider);
    final nodes = allNodes.where((n) => n.subscriptionId == null && !n.isFree).toList();
    nodes.sort((a, b) {
      if (a.hasValidPing && b.hasValidPing) return a.latencyMs!.compareTo(b.latencyMs!);
      if (a.hasValidPing && !b.hasValidPing) return -1;
      if (!a.hasValidPing && b.hasValidPing) return 1;
      if (a.isUntested && b.hasTimedOut) return -1;
      if (a.hasTimedOut && b.isUntested) return 1;
      return a.name.compareTo(b.name);
    });

    final locale = ref.watch(currentLocaleProvider);
    final showFullIp = ref.watch(showFullIpProvider);
    final outbound = ref.watch(outboundInfoProvider);
    final connState = ref.watch(connectionStatusProvider);
    final isConnected = connState == ConnectionStateEnum.connected;
    final progress = _totalToTest > 0 ? (_testedCount / _totalToTest).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progress * 100).toInt();

    final filteredNodes = nodes.where((n) {
      if (_selectedCountryCode == null) return true;
      if (_selectedCountryCode == '__timeouts__') return n.hasTimedOut;
      if (_selectedCountryCode == '__unknown__') {
        return n.hasValidPing && (n.countryCode == null || n.countryCode!.trim().isEmpty);
      }
      return n.hasValidPing && n.countryCode?.trim().toUpperCase() == _selectedCountryCode;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: AppStrings.get('more', locale: locale),
          onPressed: widget.onOpenDrawer,
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.get('configs', locale: locale),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.card_giftcard_rounded, color: Colors.orangeAccent, size: 22),
            tooltip: locale == 'fa' ? 'کانفیگ رایگان' : 'Free Configs',
            onPressed: () => widget.onNavigateToFreeConfigs?.call(),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: _isTestingAll
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  )
                : const Icon(Icons.speed_rounded, color: Colors.blueAccent),
            tooltip: _isTestingAll
                ? (_testRemainingEta != null
                    ? '$progressPercent% ($_testRemainingEta)'
                    : '$progressPercent% (${AppStrings.get("cancel_scan", locale: locale)})')
                : (locale == 'fa' ? 'تست پینگ همه' : 'Test all configs'),
            onPressed: nodes.isEmpty ? null : () => _testAllNodes(nodes),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: locale == 'fa' ? 'منو عملیات' : 'Options',
            onSelected: (val) {
              if (val == 'delete_dead') {
                ConfigsActionHelper.deleteDeadNodes(context, ref, nodes, locale);
              } else if (val == 'delete_all') {
                ConfigsActionHelper.deleteAllNodes(context, ref, locale);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'delete_dead',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(locale == 'fa' ? 'حذف کانفیگ‌های نامعتبر' : 'Delete Dead Configs'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(locale == 'fa' ? 'حذف تمامی کانفیگ‌ها' : 'Delete All Configs'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: locale == 'fa' ? 'افزودن کانفیگ' : 'Add Config',
        onPressed: () => AddConfigSheet.show(
          context,
          locale: locale,
          onManual: () => AddConfigDialog.show(context, locale),
          onClipboard: () => ConfigsActionHelper.pasteFromClipboard(context, ref),
          onQrScan: () => ConfigsActionHelper.scanQrCode(context, ref, locale),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (nodes.isNotEmpty)
              CountryFilterBar(
                nodes: nodes,
                selectedCountryCode: _selectedCountryCode,
                onCountrySelected: (code) => setState(() => _selectedCountryCode = code),
                locale: locale,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: nodes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey.shade700),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.get('no_nodes', locale: locale),
                            style: const TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredNodes.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
                        final cdnMap = ref.watch(nodeCdnMapProvider);
                        final cdn = cdnMap[node.address.trim().toLowerCase()] ?? ref.read(nodeCdnMapProvider.notifier).detectCdn(node.address);
                        final isThisNodeConnected = isConnected && node.isActive;
                        final displayCountryCode = isThisNodeConnected
                            ? (outbound.countryCode ?? node.countryCode ?? CountryService.resolveSync(node))
                            : (node.countryCode ?? CountryService.resolveSync(node));
                        final displayCountry = isThisNodeConnected
                            ? (outbound.country ?? node.country ?? (displayCountryCode != null ? CountryService.getCountryName(displayCountryCode) : null))
                            : (node.country ?? (displayCountryCode != null ? CountryService.getCountryName(displayCountryCode) : null));

                        return ConfigNodeCard(
                          node: node,
                          isTesting: _testingNodeIds.contains(node.id),
                          showFullIp: showFullIp,
                          cdn: cdn,
                          displayCountryCode: displayCountryCode,
                          displayCountry: displayCountry,
                          locale: locale,
                          onTap: () => ref.read(connectionStatusProvider.notifier).switchNode(node.id),
                          onPing: () => _testNodeLatency(node),
                          onEdit: () => EditConfigDialog.show(context, node, locale),
                          onShare: () {
                            Clipboard.setData(ClipboardData(text: node.toShareUrl()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.get('share_copied', locale: locale))),
                            );
                          },
                          onDelete: () => ref.read(nodesProvider.notifier).removeNode(node.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}