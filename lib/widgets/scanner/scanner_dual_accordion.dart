// Scanner Dual Accordion Widget
// Displays two expandable accordions: Radar Latency Improvements History
// and Discovered Clean IPs candidate list with interactive search and filtering.
// Android touch and orientation friendly.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/scanner_state.dart';
import 'scanner_clean_ip_tile.dart';

/// Dual accordion widget for the CDN scanner.
/// Displays Radar latency improvements history and discovered clean IPs list with search capabilities.
class ScannerDualAccordion extends StatefulWidget {
  final ScannerState state;
  final String locale;
  final bool isPortrait;
  final int activeAccordion;
  final ValueChanged<int> onAccordionChanged;

  /// Creates the dual accordion scanner widget.
  const ScannerDualAccordion({
    super.key,
    required this.state,
    required this.locale,
    this.isPortrait = false,
    required this.activeAccordion,
    required this.onAccordionChanged,
  });

  @override
  State<ScannerDualAccordion> createState() => _ScannerDualAccordionState();
}

class _ScannerDualAccordionState extends State<ScannerDualAccordion> {
  String _searchQuery = '';

  ScannerState get state => widget.state;
  String get locale => widget.locale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.isPortrait ? 380 : 280,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAccordionHeader(
                index: 0,
                icon: Icons.history_rounded,
                iconColor: AppTheme.primaryAccent,
                title: AppStrings.get('radar_history', locale: locale),
                badgeCount: state.radarLogs.length,
                isOpen: widget.activeAccordion == 0,
                onTap: () => widget.onAccordionChanged(0),
              ),
              if (widget.activeAccordion == 0) ...[
                const SizedBox(height: 6),
                Expanded(child: _buildRadarHistoryContent()),
                const SizedBox(height: 6),
              ] else ...[
                const SizedBox(height: 6),
              ],
              _buildAccordionHeader(
                index: 1,
                icon: Icons.dns_rounded,
                iconColor: AppTheme.successColor,
                title: AppStrings.get('discovered_clean_ips', locale: locale),
                badgeCount: state.results.length,
                isOpen: widget.activeAccordion == 1,
                onTap: () => widget.onAccordionChanged(1),
              ),
              if (widget.activeAccordion == 1) ...[
                const SizedBox(height: 6),
                Expanded(child: _buildCleanIpsContent()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds each accordion header with icon, title, and record count badge.
  Widget _buildAccordionHeader({
    required int index,
    required IconData icon,
    required Color iconColor,
    required String title,
    required int badgeCount,
    required bool isOpen,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isOpen
              ? iconColor.withValues(alpha: 0.12)
              : (theme.brightness == Brightness.dark
                  ? const Color(0xFF161A26)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOpen ? iconColor.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isOpen ? iconColor : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isOpen ? iconColor : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: isOpen
                    ? iconColor.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isOpen ? iconColor : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isOpen ? iconColor : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the list of latency improvement logs in Radar strategy.
  Widget _buildRadarHistoryContent() {
    if (state.radarLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            state.isScanning
                ? AppStrings.get('scanning_subnets', locale: locale)
                : AppStrings.get('no_improvements_yet', locale: locale),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.radarLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final log = state.radarLogs[index];
        final isFirst = index == state.radarLogs.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: index == 0
                ? AppTheme.primaryAccent.withValues(alpha: 0.12)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF131722)
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
            border: index == 0
                ? Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                index == 0 ? Icons.star_rounded : Icons.trending_down_rounded,
                color: index == 0 ? Colors.amber : AppTheme.successColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.ip,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      isFirst
                          ? AppStrings.get('initial_connection', locale: locale)
                          : (log.improvementMs != null
                              ? '${log.improvementMs} ms ${AppStrings.get('latency_improved', locale: locale)}'
                              : AppStrings.get('latency_improved', locale: locale)),
                      style: TextStyle(
                        fontSize: 10,
                        color: index == 0 ? AppTheme.primaryAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${log.latencyMs} ms',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the clean IPs list content with real-time search field.
  Widget _buildCleanIpsContent() {
    final filtered = state.results.where((r) {
      if (_searchQuery.isNotEmpty && !r.ip.contains(_searchQuery)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: TextField(
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: AppStrings.get('filter_ip_hint', locale: locale),
              prefixIcon: const Icon(Icons.search, size: 16),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () => setState(() => _searchQuery = ''),
                      padding: EdgeInsets.zero,
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF131722)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      state.isScanning
                          ? AppStrings.get('target_active', locale: locale)
                          : AppStrings.get('no_responsive_ips', locale: locale),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final res = filtered[index];
                    return ScannerCleanIpTile(
                      res: res,
                      index: index,
                      locale: locale,
                      connectedIp: state.connectedIp,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
