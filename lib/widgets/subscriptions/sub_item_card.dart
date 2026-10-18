// Subscription Item Card Widget
// Renders an expandable card displaying subscription details, remaining traffic/expiry badges,
// batch latency test controls, auto-update toggle, country filter bar, and node listings.
// Designed specifically for the Android touch interface.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/proxy_node.dart';
import '../../models/subscription_item.dart';
import '../../providers/app_providers.dart';
import '../../services/country_service.dart';
import '../country_filter_bar.dart';
import 'sub_card_trailing.dart';
import 'sub_info_badges.dart';
import 'sub_node_tile.dart';
import 'sub_test_runner.dart';

/// Accordion expansion card widget representing a subscription and its children proxy nodes.
/// Displays bandwidth usage, expiration date, batch testing controls, and the server node list.
class SubItemCard extends ConsumerStatefulWidget {
  final SubscriptionItem sub;
  final bool isUpdating;
  final VoidCallback onUpdate;

  /// Creates the subscription card widget.
  const SubItemCard({
    super.key,
    required this.sub,
    required this.isUpdating,
    required this.onUpdate,
  });

  @override
  ConsumerState<SubItemCard> createState() => _SubItemCardState();
}

class _SubItemCardState extends ConsumerState<SubItemCard> {
  bool _isExpandedAll = false;
  int _maxDisplay = 50;
  String? _selectedCountry;
  bool _isTesting = false;
  bool _isCancelled = false;
  int _testedCount = 0;
  int _totalCount = 0;
  String? _eta;
  final Set<String> _testingNodeIds = {};

  SubscriptionItem get sub => widget.sub;

  @override
  Widget build(BuildContext context) {
    final allNodes = ref.watch(nodesProvider);
    final locale = ref.watch(currentLocaleProvider);
    final showFullIp = ref.watch(showFullIpProvider);
    final outbound = ref.watch(outboundInfoProvider);
    final connState = ref.watch(connectionStatusProvider);
    final isConnected = connState == ConnectionStateEnum.connected;
    final cdnMap = ref.watch(nodeCdnMapProvider);

    final subNodes = allNodes.where((n) => n.subscriptionId == sub.id).toList();
    _sortNodes(subNodes);

    final filteredNodes = subNodes.where((n) {
      if (_selectedCountry == null) return true;
      if (_selectedCountry == '__timeouts__') return n.hasTimedOut;
      final nCode = n.countryCode ?? CountryService.resolveSync(n);
      if (_selectedCountry == '__unknown__') {
        return n.hasValidPing && (nCode == null || nCode.trim().isEmpty);
      }
      return n.hasValidPing && nCode?.trim().toUpperCase() == _selectedCountry;
    }).toList();

    final displayedNodes = _isExpandedAll
        ? filteredNodes.take(_maxDisplay).toList()
        : filteredNodes.take(3).toList();

    final subProgress = _totalCount > 0 ? (_testedCount / _totalCount).clamp(0.0, 1.0) : 0.0;
    final subPercent = (subProgress * 100).toInt();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.15),
          child: const Icon(Icons.rss_feed_rounded, color: AppTheme.primaryAccent),
        ),
        title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: SubInfoBadges(sub: sub),
        trailing: SubCardTrailing(
          ref: ref,
          sub: sub,
          subNodes: subNodes,
          isUpdating: widget.isUpdating,
          isTesting: _isTesting,
          subProgress: subProgress,
          subPercent: subPercent,
          eta: _eta,
          locale: locale,
          onBatchTest: () => _handleBatchTest(subNodes),
          onUpdate: widget.onUpdate,
        ),
        children: [
          _buildAutoUpdateRow(locale),
          const Divider(height: 1),
          if (subNodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CountryFilterBar(
                nodes: subNodes,
                selectedCountryCode: _selectedCountry,
                onCountrySelected: (code) => setState(() => _selectedCountry = code),
                locale: locale,
              ),
            ),
          if (subNodes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppStrings.get("no_sub_nodes", locale: locale),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedNodes.length,
              separatorBuilder: (c, i) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, nodeIdx) {
                final node = displayedNodes[nodeIdx];
                final isTestingNode = _testingNodeIds.contains(node.id);
                final cdn = cdnMap[node.address.trim().toLowerCase()] ??
                    ref.read(nodeCdnMapProvider.notifier).detectCdn(node.address);
                final isNodeConn = isConnected && node.isActive;
                final dispCode = isNodeConn
                    ? (outbound.countryCode ?? node.countryCode ?? CountryService.resolveSync(node))
                    : (node.countryCode ?? CountryService.resolveSync(node));
                final dispCountry = isNodeConn
                    ? (outbound.country ?? node.country ?? (dispCode != null ? CountryService.getCountryName(dispCode) : null))
                    : (node.country ?? (dispCode != null ? CountryService.getCountryName(dispCode) : null));

                return SubNodeTile(
                  node: node,
                  isTesting: isTestingNode,
                  showFullIp: showFullIp,
                  cdn: cdn,
                  displayCountryCode: dispCode,
                  displayCountry: dispCountry,
                  locale: locale,
                  onTap: () => ref.read(connectionStatusProvider.notifier).switchNode(node.id),
                  onTestLatency: () => _testSingleNode(node),
                );
              },
            ),
            if (filteredNodes.length > 3)
              _buildExpandControls(filteredNodes.length, displayedNodes.length, locale),
          ],
        ],
      ),
    );
  }

  /// Sorts proxy nodes by connectivity status (valid ping, untested, timeout).
  void _sortNodes(List<ProxyNode> nodes) {
    nodes.sort((a, b) {
      if (a.hasValidPing && b.hasValidPing) return a.latencyMs!.compareTo(b.latencyMs!);
      if (a.hasValidPing && !b.hasValidPing) return -1;
      if (!a.hasValidPing && b.hasValidPing) return 1;
      if (a.isUntested && b.hasTimedOut) return -1;
      if (a.hasTimedOut && b.isUntested) return 1;
      return a.name.compareTo(b.name);
    });
  }

  /// Builds the hourly auto-update switch row for this subscription.
  Widget _buildAutoUpdateRow(String locale) {
    return Container(
      color: Theme.of(context).cardColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get("auto_update_hourly", locale: locale),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                AppStrings.get("auto_update_hourly_desc", locale: locale),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          Switch(
            value: sub.autoUpdate,
            activeColor: AppTheme.primaryAccent,
            onChanged: (val) {
              ref.read(subscriptionsProvider.notifier).toggleAutoUpdate(sub.id, val);
            },
          ),
        ],
      ),
    );
  }

  /// Builds controls for expanding/collapsing the list and loading more configs.
  Widget _buildExpandControls(int totalFiltered, int displayedCount, String locale) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isExpandedAll && totalFiltered > displayedCount)
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  locale == 'fa'
                      ? 'نمایش بیشتر (+50 از ${totalFiltered - displayedCount} باقی‌مانده)'
                      : 'Show More (+50 of ${totalFiltered - displayedCount} remaining)',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => setState(() => _maxDisplay += 50),
              ),
            if (_isExpandedAll && totalFiltered > displayedCount)
              const SizedBox(width: 12),
            TextButton.icon(
              icon: Icon(
                _isExpandedAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
              label: Text(
                _isExpandedAll
                    ? AppStrings.get("show_less_configs", locale: locale)
                    : "${AppStrings.get("show_all_configs", locale: locale)} ($totalFiltered)",
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                setState(() {
                  _isExpandedAll = !_isExpandedAll;
                  if (!_isExpandedAll) _maxDisplay = 50;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Initiates batch ping testing or aborts an active running test.
  Future<void> _handleBatchTest(List<ProxyNode> subNodes) async {
    if (_isTesting) {
      setState(() => _isCancelled = true);
      return;
    }

    setState(() {
      _selectedCountry = null;
      _isTesting = true;
      _isCancelled = false;
      _totalCount = subNodes.length;
      _testedCount = 0;
      _testingNodeIds.addAll(subNodes.map((n) => n.id));
    });

    await SubTestRunner.testAllSubNodes(
      ref: ref,
      sub: sub,
      subNodes: subNodes,
      isCancelled: () => _isCancelled || !mounted,
      onProgress: (tested, eta) {
        if (mounted) {
          setState(() {
            _testedCount = tested;
            _eta = eta;
          });
        }
      },
      onNodeTestingDone: (nodeId) {
        if (mounted) {
          setState(() => _testingNodeIds.remove(nodeId));
        }
      },
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isCancelled = false;
        _eta = null;
      });
    }
  }

  /// Tests latency for an individual server node via the test runner.
  Future<void> _testSingleNode(ProxyNode node) async {
    if (_testingNodeIds.contains(node.id)) return;
    setState(() => _testingNodeIds.add(node.id));

    await SubTestRunner.testNodeLatency(ref: ref, node: node);

    if (mounted) {
      setState(() => _testingNodeIds.remove(node.id));
    }
  }
}
