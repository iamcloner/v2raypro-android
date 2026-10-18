// Subscription Card Trailing Actions
// Renders the trailing action cluster on a subscription expansion card,
// including batch ping test, manual update trigger, and context menu options.
// Android touch and accessibility friendly.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../models/proxy_node.dart';
import '../../models/subscription_item.dart';
import '../../providers/app_providers.dart';
import 'sub_dialogs.dart';
import 'sub_test_runner.dart';

/// Trailing action buttons widget for the subscription card.
/// Includes batch latency test, subscription refresh, and extended options menu.
class SubCardTrailing extends StatelessWidget {
  final WidgetRef ref;
  final SubscriptionItem sub;
  final List<ProxyNode> subNodes;
  final bool isUpdating;
  final bool isTesting;
  final double subProgress;
  final int subPercent;
  final String? eta;
  final String locale;
  final VoidCallback onBatchTest;
  final VoidCallback onUpdate;

  /// Creates the trailing control buttons widget.
  const SubCardTrailing({
    super.key,
    required this.ref,
    required this.sub,
    required this.subNodes,
    required this.isUpdating,
    required this.isTesting,
    required this.subProgress,
    required this.subPercent,
    required this.eta,
    required this.locale,
    required this.onBatchTest,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subNodes.isNotEmpty) _buildPingButton(),
        if (isUpdating) _buildUpdatingSpinner() else _buildSyncButton(),
        _buildOptionsMenu(context),
      ],
    );
  }

  /// Builds the batch ping test button with progress percentage or cancel status.
  Widget _buildPingButton() {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: isTesting
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: subProgress > 0 ? subProgress : null,
                strokeWidth: 2,
                color: Colors.amber,
              ),
            )
          : const Icon(Icons.speed_rounded, size: 20, color: Colors.blueAccent),
      tooltip: isTesting
          ? (eta != null ? '$subPercent% ($eta)' : '$subPercent% (${AppStrings.get("cancel_scan", locale: locale)})')
          : AppStrings.get("test_all_sub", locale: locale),
      onPressed: onBatchTest,
    );
  }

  /// Builds the subscription update progress spinner.
  Widget _buildUpdatingSpinner() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  /// Builds the manual subscription refresh and node fetch button.
  Widget _buildSyncButton() {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.sync_rounded, size: 20, color: Colors.cyanAccent),
      tooltip: "Update subscription",
      onPressed: onUpdate,
    );
  }

  /// Builds the overflow popup menu (delete dead configs, edit, share, delete).
  Widget _buildOptionsMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      padding: EdgeInsets.zero,
      tooltip: "Options",
      onSelected: (val) {
        if (val == 'delete_dead') {
          SubTestRunner.deleteDeadSubNodes(
            context: context,
            ref: ref,
            sub: sub,
            subNodes: subNodes,
            locale: locale,
          );
        } else if (val == 'edit') {
          SubDialogs.showEditSubDialog(context: context, ref: ref, sub: sub, locale: locale);
        } else if (val == 'share') {
          Clipboard.setData(ClipboardData(text: sub.url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Subscription URL copied to clipboard.")),
          );
        } else if (val == 'delete') {
          ref.read(subscriptionsProvider.notifier).removeSubscription(sub.id);
        }
      },
      itemBuilder: (ctx) => [
        if (subNodes.isNotEmpty)
          PopupMenuItem(
            value: 'delete_dead',
            child: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(AppStrings.get("delete_sub_dead", locale: locale)),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text("Edit"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text("Share URL"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent.shade100),
              const SizedBox(width: 8),
              const Text("Delete"),
            ],
          ),
        ),
      ],
    );
  }
}
