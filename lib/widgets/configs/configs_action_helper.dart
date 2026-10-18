// File: lib/widgets/configs/configs_action_helper.dart
// Description: Helper functions for batch operations on configurations on Android.
// Handles clipboard import, dead node removal, deleting all configs, and QR scanning.
// Extracted to maintain readability, improve modularity, and reduce UI file size.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/proxy_node.dart';
import '../../providers/app_providers.dart';
import '../../utils/config_parser.dart';
import '../qr_scanner_dialog.dart';

/// Helper class providing operational methods and management dialogs for the configs screen.
///
/// Modularly handles clipboard imports, camera QR scanning,
/// and batch node deletion confirmations.
class ConfigsActionHelper {
  /// Imports configs copied to the clipboard (protocol links or JSON format).
  static Future<void> pasteFromClipboard(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;

    final nodes = await ConfigParser.parseBatchAsync(text);
    if (nodes.isNotEmpty) {
      ref.read(nodesProvider.notifier).addNodes(nodes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${nodes.length} configuration(s) imported from clipboard.')),
        );
      }
      return;
    }

    try {
      final decoded = jsonDecode(text);
      final List<ProxyNode> jsonNodes = [];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            jsonNodes.add(ProxyNode.fromJson(item));
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('address') || decoded.containsKey('server')) {
          jsonNodes.add(ProxyNode.fromJson(decoded));
        } else if (decoded.containsKey('outbounds')) {
          final outbounds = decoded['outbounds'] as List?;
          if (outbounds != null) {
            for (final out in outbounds) {
              if (out is Map<String, dynamic>) {
                final protoStr = (out['protocol'] ?? '').toString().toLowerCase();
                final proto = ProtocolType.values.firstWhere(
                  (p) => p.name.toLowerCase() == protoStr,
                  orElse: () => ProtocolType.vless,
                );
                final tag = out['tag'] ?? 'JSON Config';
                final settings = out['settings'] as Map<String, dynamic>? ?? {};
                final vnext = settings['vnext'] as List?;
                if (vnext != null && vnext.isNotEmpty) {
                  final first = vnext[0] as Map<String, dynamic>;
                  final addr = first['address'] ?? '127.0.0.1';
                  final port = (first['port'] as num?)?.toInt() ?? 443;
                  final users = first['users'] as List?;
                  final uuid = (users != null && users.isNotEmpty) ? (users[0]['id'] ?? '') : '';
                  jsonNodes.add(ProxyNode(
                    id: const Uuid().v4(),
                    name: tag,
                    protocol: proto,
                    address: addr,
                    port: port,
                    uuidOrPassword: uuid,
                  ));
                }
              }
            }
          }
        } else {
          jsonNodes.add(ProxyNode.fromJson(decoded));
        }
      }

      if (jsonNodes.isNotEmpty) {
        ref.read(nodesProvider.notifier).addNodes(jsonNodes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${jsonNodes.length} configuration(s) imported from clipboard JSON.')),
          );
        }
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid proxy configuration found in clipboard.')),
      );
    }
  }

  /// Deletes configurations that timed out during ping testing.
  static Future<void> deleteDeadNodes(
    BuildContext context,
    WidgetRef ref,
    List<ProxyNode> customNodes,
    String locale,
  ) async {
    final deadNodes = customNodes.where((n) => n.hasTimedOut).toList();
    if (deadNodes.isEmpty) {
      final untestedCount = customNodes.where((n) => n.isUntested).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            untestedCount > 0
                ? (locale == 'fa'
                    ? 'ابتدا با دکمه «تست پینگ همه» کانفیگ‌ها را بررسی کنید تا بی‌پاسخ‌ها مشخص شوند.'
                    : 'Run "Test All Ping" first to check and mark timed-out configs.')
                : AppStrings.get('delete_dead_none', locale: locale),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(AppStrings.get('confirm_delete_dead_title', locale: locale)),
          ],
        ),
        content: Text(
          AppStrings.get('confirm_delete_dead_msg', locale: locale)
              .replaceAll('{count}', deadNodes.length.toString()),
        ),
        actions: [
          TextButton(
            child: Text(AppStrings.get('cancel_scan', locale: locale)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppStrings.get('delete_dead_configs', locale: locale)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final removed = ref.read(nodesProvider.notifier).removeDeadNodes(onlyCustom: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.get('delete_dead_success', locale: locale).replaceAll('{count}', removed.toString()),
          ),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    }
  }

  /// Completely deletes all user custom configurations after obtaining confirmation.
  static Future<void> deleteAllNodes(BuildContext context, WidgetRef ref, String locale) async {
    final nodes = ref.read(nodesProvider).where((n) => n.subscriptionId == null && !n.isFree).toList();
    if (nodes.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(locale == 'fa' ? 'حذف همه کانفیگ‌ها' : 'Delete All Configs'),
          ],
        ),
        content: Text(
          locale == 'fa'
              ? 'آیا از حذف تمامی ${nodes.length} کانفیگ این بخش اطمینان دارید؟'
              : 'Are you sure you want to delete all ${nodes.length} configs in this section?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.get('cancel', locale: locale)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.get('delete', locale: locale)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(nodesProvider.notifier).clearCustomNodes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale == 'fa' ? 'تمامی کانفیگ‌های این بخش حذف شدند.' : 'All section configs deleted.'),
        ),
      );
    }
  }

  /// Scans a QR code via the Android camera and automatically imports parsed configs.
  static Future<void> scanQrCode(BuildContext context, WidgetRef ref, String locale) async {
    final code = await QrScannerDialog.show(context, locale: locale);
    if (code != null && code.isNotEmpty && context.mounted) {
      final nodes = await ConfigParser.parseBatchAsync(code);
      if (nodes.isNotEmpty && context.mounted) {
        ref.read(nodesProvider.notifier).addNodes(nodes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale == 'fa'
                ? '${nodes.length} کانفیگ با موفقیت اضافه شد.'
                : '${nodes.length} configuration(s) added successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale == 'fa'
                ? 'کانفیگ معتبری در بارکد اسکن شده یافت نشد.'
                : 'No valid proxy config found in QR code.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }
}
