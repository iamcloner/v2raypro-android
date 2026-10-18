// File: lib/free_configs_view.dart
// Description: Display, filter, and management screen for public free servers in Android.
// Provides free subscription scanning, real delay testing, country filtering,
// and direct connection to the optimal configuration.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'models/proxy_node.dart';
import 'providers/app_providers.dart';
import 'services/country_service.dart';
import 'services/real_delay_service.dart';
import 'widgets/country_filter_bar.dart';
import 'widgets/free_configs/free_config_card.dart';
import 'widgets/free_configs/free_configs_progress_banner.dart';
import 'widgets/free_configs/free_configs_stats.dart';

/// Free configurations screen widget in v2raypro Android.
///
/// Manages fetching, listing, latency testing, country filtering,
/// and automated scanning state for free public configurations.
class FreeConfigsView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  const FreeConfigsView({super.key, this.onOpenDrawer});

  @override
  ConsumerState<FreeConfigsView> createState() => _FreeConfigsViewState();
}

class _FreeConfigsViewState extends ConsumerState<FreeConfigsView> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _testingNodeIds = {};
  String _searchFilter = '';
  String? _selectedCountryCode;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchFilter = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    ref.read(freeConfigsProvider.notifier).cancelScan();
    super.dispose();
  }

  /// Connects or disconnects the selected node while synchronizing provider state.
  Future<void> _handleConnect(ProxyNode node) async {
    final connState = ref.read(connectionStatusProvider);
    final nodes = ref.read(nodesProvider);
    final activeNode = nodes.where((n) => n.isActive).firstOrNull;

    if (connState == ConnectionStateEnum.connected && activeNode?.id == node.id) {
      await ref.read(connectionStatusProvider.notifier).toggleConnect();
    } else {
      ref.read(nodesProvider.notifier).selectAndConnectFreeNode(node);
      await ref.read(connectionStatusProvider.notifier).connect(node);
    }
  }

  /// Tests real delay for a specific node in the background.
  Future<void> _testFreeNodeLatency(ProxyNode node) async {
    if (_testingNodeIds.contains(node.id)) return;
    setState(() => _testingNodeIds.add(node.id));

    try {
      final testMode = ref.read(testModeProvider);
      final res = await testRealDelay(
        mode: testMode == TestMode.turbo ? 'turbo' : 'normal',
        type: 'xray',
        config: node.toJson(),
      );

      final cCode = res.country?.toUpperCase() ?? node.countryCode ?? CountryService.resolveSync(node);
      final cName = res.countryName ?? (cCode != null ? CountryService.getCountryName(cCode) : node.country);

      final updatedNode = node.copyWith(
        latencyMs: res.ping ?? -1,
        countryCode: cCode,
        country: cName,
        lastTestedAt: DateTime.now(),
      );

      ref.read(freeConfigsProvider.notifier).updateSingleNode(updatedNode);
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _testingNodeIds.remove(node.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final freeState = ref.watch(freeConfigsProvider);
    final locale = ref.watch(currentLocaleProvider);
    final showFullIp = ref.watch(showFullIpProvider);
    final cdnMap = ref.watch(nodeCdnMapProvider);
    final connectionState = ref.watch(connectionStatusProvider);
    final outbound = ref.watch(outboundInfoProvider);
    final nodes = ref.watch(nodesProvider);
    final activeNode = nodes.where((n) => n.isActive).firstOrNull;

    final isConnected = connectionState == ConnectionStateEnum.connected;
    final isConnecting = connectionState == ConnectionStateEnum.connecting;

    final nodesToFilter = freeState.allNodes.isNotEmpty ? freeState.allNodes : freeState.workingNodes;
    final filteredNodes = nodesToFilter.where((n) {
      if (_selectedCountryCode != null) {
        if (_selectedCountryCode == '__timeouts__') {
          if (!n.hasTimedOut) return false;
        } else if (_selectedCountryCode == '__unknown__') {
          if (!n.hasValidPing || (n.countryCode != null && n.countryCode!.trim().isNotEmpty)) return false;
        } else {
          if (!n.hasValidPing || n.countryCode?.trim().toUpperCase() != _selectedCountryCode) return false;
        }
      }

      if (_searchFilter.isNotEmpty) {
        final name = n.name.toLowerCase();
        final addr = n.address.toLowerCase();
        final proto = n.protocol.name.toLowerCase();
        if (!name.contains(_searchFilter) && !addr.contains(_searchFilter) && !proto.contains(_searchFilter)) {
          return false;
        }
      }
      return true;
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
              AppStrings.get('free_configs', locale: locale),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search, size: 20),
            tooltip: AppStrings.get('search_nodes', locale: locale),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                }
              });
            },
          ),
          if (freeState.isScanning)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
              ),
              tooltip: AppStrings.get('cancel_scan', locale: locale),
              onPressed: () => ref.read(freeConfigsProvider.notifier).cancelScan(),
            )
          else ...[
            if (freeState.workingNodes.isNotEmpty || freeState.timeoutNodes.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.speed_rounded, color: Colors.cyanAccent),
                tooltip: AppStrings.get('test_all', locale: locale),
                onPressed: () => ref.read(freeConfigsProvider.notifier).testAllFreeNodes(),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.autorenew_rounded, color: AppTheme.primaryAccent),
              tooltip: AppStrings.get('get_new_configs', locale: locale),
              onPressed: () {
                setState(() => _selectedCountryCode = null);
                ref.read(freeConfigsProvider.notifier).startScan();
              },
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSearchExpanded) ...[
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: AppStrings.get('search_nodes', locale: locale),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _searchFilter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            FreeConfigsStats(state: freeState, locale: locale),
            const SizedBox(height: 12),
            if (freeState.isScanning) ...[
              FreeConfigsProgressBanner(state: freeState, locale: locale),
              const SizedBox(height: 12),
            ],
            if (nodesToFilter.isNotEmpty)
              CountryFilterBar(
                nodes: nodesToFilter,
                selectedCountryCode: _selectedCountryCode,
                onCountrySelected: (code) => setState(() => _selectedCountryCode = code),
                locale: locale,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: nodesToFilter.isEmpty && !freeState.isScanning
                  ? _buildEmptyState(locale)
                  : ListView.separated(
                      itemCount: filteredNodes.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
                        final isThisNodeActive = activeNode?.id == node.id ||
                            (activeNode != null &&
                                activeNode.address == node.address &&
                                activeNode.port == node.port &&
                                activeNode.uuidOrPassword == node.uuidOrPassword);

                        final isThisNodeConnected = isConnected && isThisNodeActive;
                        final isThisNodeConnecting = isConnecting && isThisNodeActive;

                        final displayCountryCode = isThisNodeConnected
                            ? (outbound.countryCode ?? node.countryCode ?? CountryService.resolveSync(node))
                            : (node.countryCode ?? CountryService.resolveSync(node));
                        final displayCountry = isThisNodeConnected
                            ? (outbound.country ?? node.country ?? (displayCountryCode != null ? CountryService.getCountryName(displayCountryCode) : null))
                            : (node.country ?? (displayCountryCode != null ? CountryService.getCountryName(displayCountryCode) : null));

                        final cdn = cdnMap[node.address.trim().toLowerCase()] ??
                            ref.read(nodeCdnMapProvider.notifier).detectCdn(node.address);

                        return FreeConfigCard(
                          node: node,
                          isThisNodeActive: isThisNodeActive,
                          isThisNodeConnected: isThisNodeConnected,
                          isThisNodeConnecting: isThisNodeConnecting,
                          isTesting: _testingNodeIds.contains(node.id),
                          showFullIp: showFullIp,
                          displayCountryCode: displayCountryCode,
                          displayCountry: displayCountry,
                          cdn: cdn,
                          locale: locale,
                          onTap: () => _handleConnect(node),
                          onRetest: () => _testFreeNodeLatency(node),
                          onConnect: () => _handleConnect(node),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }


  /// Empty state widget displayed when no configurations are found.
  Widget _buildEmptyState(String locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade700),
          const SizedBox(height: 14),
          Text(
            AppStrings.get('no_free_configs_yet', locale: locale),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            icon: const Icon(Icons.autorenew_rounded, size: 16),
            label: Text(AppStrings.get('get_new_configs', locale: locale)),
            onPressed: () => ref.read(freeConfigsProvider.notifier).startScan(),
          ),
        ],
      ),
    );
  }
}
