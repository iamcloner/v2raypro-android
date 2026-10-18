// File: lib/widgets/routing/routing_rule_dialog.dart
// Description: Dialog for creating or editing routing rules on Android.
// Allows specifying action (Direct, Proxy, Block), remark, rule values,
// and quick selection from installed Android applications.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/routing_rule.dart';
import 'installed_apps_picker.dart';

/// Dialog for creating or editing a traffic routing rule.
///
/// Collects rule type, targets, associated outbound action, and remark,
/// returning the final result as a [RoutingRule] object.
class RoutingRuleDialog extends StatefulWidget {
  final RoutingRule? existingRule;
  final RoutingRuleType defaultType;
  final String locale;
  final void Function(RoutingRule rule) onSave;

  const RoutingRuleDialog({
    super.key,
    this.existingRule,
    required this.defaultType,
    required this.locale,
    required this.onSave,
  });

  /// Static method to display the routing rule editor dialog.
  static void show({
    required BuildContext context,
    RoutingRule? existingRule,
    required RoutingRuleType defaultType,
    required String locale,
    required void Function(RoutingRule rule) onSave,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => RoutingRuleDialog(
        existingRule: existingRule,
        defaultType: defaultType,
        locale: locale,
        onSave: onSave,
      ),
    );
  }

  @override
  State<RoutingRuleDialog> createState() => _RoutingRuleDialogState();
}

class _RoutingRuleDialogState extends State<RoutingRuleDialog> {
  late RoutingRuleType _type;
  late TextEditingController _valuesController;
  late TextEditingController _remarkController;
  late RoutingAction _selectedAction;

  @override
  void initState() {
    super.initState();
    _type = widget.existingRule?.type ?? widget.defaultType;
    _valuesController = TextEditingController(
      text: widget.existingRule != null ? widget.existingRule!.values.join('\n') : '',
    );
    _remarkController = TextEditingController(text: widget.existingRule?.remark ?? '');
    _selectedAction = widget.existingRule?.action ?? RoutingAction.direct;
  }

  @override
  void dispose() {
    _valuesController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  String _getHintText() {
    switch (_type) {
      case RoutingRuleType.address:
        return AppStrings.get('routing_pattern_hint', locale: widget.locale);
      case RoutingRuleType.ip:
        return AppStrings.get('routing_ip_hint', locale: widget.locale);
      case RoutingRuleType.app:
        return AppStrings.get('routing_app_hint', locale: widget.locale);
    }
  }

  void _save() {
    final raw = _valuesController.text;
    final lines = raw
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.locale == 'fa' ? 'لطفاً حداقل یک مقدار وارد کنید' : 'Please enter at least one value'),
        ),
      );
      return;
    }

    final remark = _remarkController.text.trim();
    final rule = widget.existingRule != null
        ? widget.existingRule!.copyWith(
            action: _selectedAction,
            values: lines,
            remark: remark.isNotEmpty ? remark : null,
          )
        : RoutingRule(
            id: const Uuid().v4(),
            type: _type,
            values: lines,
            action: _selectedAction,
            enabled: true,
            remark: remark.isNotEmpty ? remark : null,
          );

    widget.onSave(rule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.locale;
    final hintText = _getHintText();

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Row(
        children: [
          Icon(
            widget.existingRule != null ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
            color: AppTheme.primaryAccent,
          ),
          const SizedBox(width: 8),
          Text(
            widget.existingRule != null
                ? AppStrings.get('routing_edit_rule', locale: loc)
                : AppStrings.get('routing_add_rule', locale: loc),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(480.0, MediaQuery.of(context).size.width * 0.88),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('routing_action', locale: loc),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(AppStrings.get('routing_action_direct', locale: loc), style: const TextStyle(fontSize: 12)),
                    selected: _selectedAction == RoutingAction.direct,
                    selectedColor: AppTheme.primaryAccent.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _selectedAction = RoutingAction.direct);
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.vpn_lock_rounded, size: 16),
                    label: Text(AppStrings.get('routing_action_proxy', locale: loc), style: const TextStyle(fontSize: 12)),
                    selected: _selectedAction == RoutingAction.proxy,
                    selectedColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _selectedAction = RoutingAction.proxy);
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.block_rounded, size: 16),
                    label: Text(AppStrings.get('routing_action_block', locale: loc), style: const TextStyle(fontSize: 12)),
                    selected: _selectedAction == RoutingAction.block,
                    selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) setState(() => _selectedAction = RoutingAction.block);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _remarkController,
                decoration: InputDecoration(
                  labelText: loc == 'fa' ? 'یادداشت / برچسب (اختیاری)' : 'Remark / Label (Optional)',
                  hintText: loc == 'fa' ? 'مثال: سایت‌های ایرانی، تبلیغات' : 'e.g. Local traffic, Ads',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              if (_type == RoutingRuleType.app) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        loc == 'fa' ? 'برنامه اندروید:' : 'Android Application:',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.apps_rounded, size: 16, color: AppTheme.primaryAccent),
                      label: Text(
                        loc == 'fa' ? 'انتخاب از برنامه‌ها' : 'Select App',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryAccent, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        InstalledAppsPicker.show(context, loc, (appName, packageName) {
                          setState(() {
                            final current = _valuesController.text.trim();
                            if (current.isEmpty) {
                              _valuesController.text = packageName;
                            } else {
                              final lines = current
                                  .split(RegExp(r'[\r\n,]+'))
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .toList();
                              if (!lines.contains(packageName)) {
                                lines.add(packageName);
                                _valuesController.text = lines.join('\n');
                              }
                            }
                            if (_remarkController.text.trim().isEmpty) {
                              _remarkController.text = appName;
                            }
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _valuesController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  labelText: loc == 'fa' ? 'مقادیر (یک مورد در هر سطر یا با ویرگول)' : 'Values (one per line or comma-separated)',
                  hintText: hintText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hintText,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.get('cancel', locale: loc)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: Text(AppStrings.get('save', locale: loc)),
        ),
      ],
    );
  }
}
