// File: lib/widgets/routing/routing_rule_tile.dart
// Description: Card widget representing a routing rule (domain, IP, or app package).
// Displays enabled status, action type (Direct, Proxy, Block), remark label,
// and target values with edit and delete controls.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/routing_rule.dart';

/// Card widget displaying a single routing rule.
///
/// Presents action type (Direct, Proxy, Block),
/// toggle activation switch, filtered match values, and action controls.
class RoutingRuleTile extends StatelessWidget {
  final RoutingRule rule;
  final String locale;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoutingRuleTile({
    super.key,
    required this.rule,
    required this.locale,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color _actionColor(RoutingAction action) {
    switch (action) {
      case RoutingAction.direct:
        return AppTheme.successColor;
      case RoutingAction.proxy:
        return AppTheme.primaryAccent;
      case RoutingAction.block:
        return Colors.redAccent;
    }
  }

  IconData _actionIcon(RoutingAction action) {
    switch (action) {
      case RoutingAction.direct:
        return Icons.arrow_forward_rounded;
      case RoutingAction.proxy:
        return Icons.vpn_lock_rounded;
      case RoutingAction.block:
        return Icons.block_rounded;
    }
  }

  String _actionLabel(RoutingAction action, String locale) {
    switch (action) {
      case RoutingAction.direct:
        return AppStrings.get('routing_action_direct', locale: locale);
      case RoutingAction.proxy:
        return AppStrings.get('routing_action_proxy', locale: locale);
      case RoutingAction.block:
        return AppStrings.get('routing_action_block', locale: locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionColor = _actionColor(rule.action);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Switch(
              value: rule.enabled,
              activeColor: AppTheme.primaryAccent,
              onChanged: onToggle,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: actionColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_actionIcon(rule.action), size: 14, color: actionColor),
                  const SizedBox(width: 4),
                  Text(
                    _actionLabel(rule.action, locale),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: actionColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rule.remark != null && rule.remark!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        rule.remark!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: rule.values.map((v) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          v,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              tooltip: AppStrings.get('routing_edit_rule', locale: locale),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              tooltip: AppStrings.get('delete', locale: locale),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
