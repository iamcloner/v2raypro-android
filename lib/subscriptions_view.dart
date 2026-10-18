// File: lib/subscriptions_view.dart
// Description: User subscriptions management screen for Android.
// Displays subscriptions, update preferences, latency testing, and imported servers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'models/subscription_item.dart';
import 'providers/app_providers.dart';
import 'widgets/subscriptions/sub_dialogs.dart';
import 'widgets/subscriptions/sub_item_card.dart';

/// Main subscriptions management screen.
/// Displays user subscriptions, update options, latency testing, and adding new subscriptions.
class SubscriptionsView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;

  /// Creates the subscriptions view widget.
  const SubscriptionsView({super.key, this.onOpenDrawer});

  @override
  ConsumerState<SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends ConsumerState<SubscriptionsView> {
  final Set<String> _updatingSubIds = {};
  bool _isUpdatingAll = false;

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final locale = ref.watch(currentLocaleProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
            SubDialogs.pasteSubFromClipboard(context: context, ref: ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _buildAppBar(subs, locale),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.primaryAccent,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: AppStrings.get("add_subscription", locale: locale),
            onPressed: () => SubDialogs.showAddSubBottomSheet(
              context: context,
              ref: ref,
              locale: locale,
            ),
            child: const Icon(Icons.add, size: 28),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: subs.isEmpty ? _buildEmptyState(locale) : _buildSubsList(subs),
          ),
        ),
      ),
    );
  }

  /// Builds the app bar with menu, title, and sync all buttons.
  AppBar _buildAppBar(List<SubscriptionItem> subs, String locale) {
    return AppBar(
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
            AppStrings.get("subscriptions", locale: locale),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      actions: [
        if (subs.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: _isUpdatingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.cyanAccent),
            tooltip: AppStrings.get("update_all_subs", locale: locale),
            onPressed: _isUpdatingAll ? null : _updateAllSubs,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Displays empty state when no subscriptions are configured.
  Widget _buildEmptyState(String locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rss_feed_rounded, size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text(
            AppStrings.get("no_subs", locale: locale),
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// Renders the subscription items list vertically with standard spacing.
  Widget _buildSubsList(List<SubscriptionItem> subs) {
    return ListView.separated(
      itemCount: subs.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sub = subs[index];
        final isUpdating = _updatingSubIds.contains(sub.id);
        return SubItemCard(
          sub: sub,
          isUpdating: isUpdating,
          onUpdate: () => _updateSub(sub),
        );
      },
    );
  }

  /// Updates a specific subscription and fetches its latest nodes from the server.
  Future<void> _updateSub(SubscriptionItem sub) async {
    if (_updatingSubIds.contains(sub.id)) return;
    setState(() => _updatingSubIds.add(sub.id));

    final count = await ref.read(subscriptionsProvider.notifier).updateSubscription(sub.id);

    if (mounted) {
      setState(() => _updatingSubIds.remove(sub.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${sub.name}: $count nodes updated")),
      );
    }
  }

  /// Concurrently updates all registered subscriptions in the application.
  Future<void> _updateAllSubs() async {
    final subs = ref.read(subscriptionsProvider);
    if (subs.isEmpty || _isUpdatingAll) return;

    setState(() => _isUpdatingAll = true);
    await ref.read(subscriptionsProvider.notifier).updateAll();

    if (mounted) {
      setState(() => _isUpdatingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All subscriptions updated successfully")),
      );
    }
  }
}