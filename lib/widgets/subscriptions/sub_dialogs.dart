// Subscriptions Dialogs & Bottom Sheet Helpers
// Provides user interface modals for adding new subscriptions via URL or clipboard,
// editing existing subscription metadata, and selecting subscription import methods.
// Designed specifically for the Android client workflow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/subscription_item.dart';
import '../../providers/app_providers.dart';

/// Helper class for displaying dialogs and bottom sheets for subscription management.
/// Provides static methods for manual addition, clipboard import, and editing.
class SubDialogs {
  /// Displays the bottom sheet to select subscription import method (manual or clipboard).
  /// Navigates the user to the corresponding action or dialog upon selection.
  static void showAddSubBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String locale,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.get("add_subscription", locale: locale),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_link_rounded, color: AppTheme.primaryAccent),
                ),
                title: Text(locale == 'fa' ? 'افزودن لینک سابسکریپشن' : 'Add Subscription URL'),
                subtitle: Text(
                  locale == 'fa' ? 'وارد کردن نام و لینک اشتراک' : 'Enter subscription name and URL',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddDialog(context: context, ref: ref, locale: locale);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.content_paste_rounded, color: Colors.tealAccent),
                ),
                title: Text(locale == 'fa' ? 'از کلیپ‌بورد (Paste from Clipboard)' : 'Import from Clipboard'),
                subtitle: Text(
                  locale == 'fa' ? 'خواندن خودکار لینک ساب کپی شده' : 'Auto import copied subscription link',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  pasteSubFromClipboard(context: context, ref: ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays the dialog to manually enter a subscription title and link.
  /// Automatically fetches and imports subscription configs into the list upon confirmation.
  static void showAddDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String locale,
  }) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get("add_subscription", locale: locale)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.get("sub_name", locale: locale),
                  hintText: "e.g. My Premium Configs",
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: AppStrings.get("sub_url", locale: locale),
                  hintText: "https://example.com/api/v1/client/subscribe?token=...",
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: const Text("Add & Update"),
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text("Fetching subscription nodes...")),
                );
                final count = await ref
                    .read(subscriptionsProvider.notifier)
                    .addSubscription(nameController.text.trim(), url);
                messenger.showSnackBar(
                  SnackBar(content: Text("$count nodes imported from subscription.")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Displays the dialog for editing an existing subscription name and URL.
  /// Updates and triggers a re-fetch of all subscription nodes upon saving.
  static void showEditSubDialog({
    required BuildContext context,
    required WidgetRef ref,
    required SubscriptionItem sub,
    required String locale,
  }) {
    final nameCtrl = TextEditingController(text: sub.name);
    final urlCtrl = TextEditingController(text: sub.url);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppTheme.primaryAccent),
            const SizedBox(width: 8),
            Text("${AppStrings.get('edit_config', locale: locale)} (Sub)"),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: AppStrings.get("sub_name", locale: locale),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: AppStrings.get("sub_url", locale: locale),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            child: const Text("Save & Refresh"),
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newUrl = urlCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                ref.read(subscriptionsProvider.notifier).editSubscription(sub.id, newName, newUrl);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Subscription updated and refreshing...")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Inspects and imports a subscription link from the device clipboard.
  /// Automatically imports configurations if the clipboard contains a valid HTTP/HTTPS URL.
  static Future<void> pasteSubFromClipboard({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;

    if (text.startsWith("http://") || text.startsWith("https://")) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text("Adding subscription from clipboard URL...")),
      );
      final count = await ref
          .read(subscriptionsProvider.notifier)
          .addSubscription("Sub ${ref.read(subscriptionsProvider).length + 1}", text);
      messenger.showSnackBar(
        SnackBar(content: Text("$count nodes imported from subscription.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clipboard does not contain a valid subscription URL (http/https).")),
      );
    }
  }
}
