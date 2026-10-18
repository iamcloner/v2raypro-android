// File: lib/routing_view.dart
// Description: Management screen for network traffic routing rules in Android.
// Supports intelligent routing by domain name, IP address, and installed applications.
// Includes support for per-app routing strategies and rule toggling.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'models/routing_rule.dart';
import 'providers/app_providers.dart';
import 'widgets/routing/app_routing_mode_card.dart';
import 'widgets/routing/installed_apps_picker.dart';
import 'widgets/routing/routing_rule_dialog.dart';
import 'widgets/routing/routing_rule_tile.dart';

/// Routing rules management screen widget for Android.
///
/// Manages traffic splitting tabs based on domains, IPs, and app packages,
/// and synchronizes rules with active Xray or Sing-box cores.
class RoutingView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  const RoutingView({super.key, this.onOpenDrawer});

  @override
  ConsumerState<RoutingView> createState() => _RoutingViewState();
}

class _RoutingViewState extends ConsumerState<RoutingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Resolves rule type based on active tab index.
  RoutingRuleType _typeForIndex(int index) {
    switch (index) {
      case 0:
        return RoutingRuleType.address;
      case 1:
        return RoutingRuleType.ip;
      case 2:
      default:
        return RoutingRuleType.app;
    }
  }

  /// Opens dialog to add or edit a routing rule.
  void _openRuleDialog({RoutingRule? existingRule, RoutingRuleType? defaultType}) {
    final locale = ref.read(currentLocaleProvider);
    final type = existingRule?.type ?? defaultType ?? _typeForIndex(_tabController.index);

    RoutingRuleDialog.show(
      context: context,
      existingRule: existingRule,
      defaultType: type,
      locale: locale,
      onSave: (rule) {
        if (existingRule != null) {
          ref.read(routingRulesProvider.notifier).updateRule(rule);
        } else {
          ref.read(routingRulesProvider.notifier).addRule(rule);
        }
        if (ref.read(connectionStatusProvider) == ConnectionStateEnum.connected) {
          ref.read(connectionStatusProvider.notifier).reconnectWithUpdatedSettings();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(currentLocaleProvider);

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
              AppStrings.get('routing', locale: locale),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.get('routing_add_rule', locale: locale),
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryAccent),
            onPressed: () => _openRuleDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.language_rounded, size: 18),
                text: AppStrings.get('routing_tab_address', locale: locale),
              ),
              Tab(
                icon: const Icon(Icons.lan_rounded, size: 18),
                text: AppStrings.get('routing_tab_ip', locale: locale),
              ),
              Tab(
                icon: const Icon(Icons.apps_rounded, size: 18),
                text: AppStrings.get('routing_tab_app', locale: locale),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRuleList(RoutingRuleType.address, locale),
                _buildRuleList(RoutingRuleType.ip, locale),
                _buildRuleList(RoutingRuleType.app, locale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds rule list for a specific category (domain, IP, or app).
  Widget _buildRuleList(RoutingRuleType type, String locale) {
    final allRules = ref.watch(routingRulesProvider);
    final rules = allRules.where((r) => r.type == type).toList();

    return Column(
      children: [
        if (type == RoutingRuleType.app) ...[
          AppRoutingModeCard(
            mode: ref.watch(appRoutingModeProvider),
            locale: locale,
            onModeChanged: (newMode) {
              ref.read(appRoutingModeProvider.notifier).setMode(newMode);
              if (ref.read(connectionStatusProvider) == ConnectionStateEnum.connected) {
                ref.read(connectionStatusProvider.notifier).reconnectWithUpdatedSettings();
              }
            },
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.get('routing_tun_required', locale: locale),
                    style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: rules.isEmpty
              ? _buildEmptyState(type, locale)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rules.length,
                  itemBuilder: (ctx, idx) {
                    final rule = rules[idx];
                    return RoutingRuleTile(
                      rule: rule,
                      locale: locale,
                      onToggle: (val) {
                        ref.read(routingRulesProvider.notifier).toggleRule(rule.id, val);
                        if (ref.read(connectionStatusProvider) == ConnectionStateEnum.connected) {
                          ref.read(connectionStatusProvider.notifier).reconnectWithUpdatedSettings();
                        }
                      },
                      onEdit: () => _openRuleDialog(existingRule: rule),
                      onDelete: () {
                        ref.read(routingRulesProvider.notifier).deleteRule(rule.id);
                        if (ref.read(connectionStatusProvider) == ConnectionStateEnum.connected) {
                          ref.read(connectionStatusProvider.notifier).reconnectWithUpdatedSettings();
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Empty state widget for routing rules with quick action buttons.
  Widget _buildEmptyState(RoutingRuleType type, String locale) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            AppStrings.get('routing_empty', locale: locale),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(AppStrings.get('routing_add_rule', locale: locale)),
                onPressed: () => _openRuleDialog(defaultType: type),
              ),
              if (type == RoutingRuleType.app)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryAccent, width: 1.2),
                  ),
                  icon: const Icon(Icons.apps_rounded, size: 18, color: AppTheme.primaryAccent),
                  label: Text(
                    locale == 'fa' ? 'انتخاب از برنامه‌ها' : 'Select App',
                    style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    InstalledAppsPicker.show(context, locale, (appName, packageName) {
                      _openRuleDialog(
                        defaultType: RoutingRuleType.app,
                        existingRule: RoutingRule(
                          id: const Uuid().v4(),
                          type: RoutingRuleType.app,
                          values: [packageName],
                          action: RoutingAction.direct,
                          enabled: true,
                          remark: appName,
                        ),
                      );
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
