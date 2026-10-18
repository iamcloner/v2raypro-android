// File: lib/widgets/configs/add_config_sheet.dart
// Description: Bottom sheet for selecting how to add a new proxy configuration on Android.
// Offers options for manual entry (advanced form), clipboard import, and QR code scanning.
// Styled for light/dark themes with easy bottom-sheet access.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Bottom sheet widget for choosing a method to add a proxy configuration.
///
/// Provides three input options to the user:
/// 1. Manual Form, 2. Import from Clipboard, 3. Scan QR Code via camera.
class AddConfigSheet extends StatelessWidget {
  final String locale;
  final VoidCallback onManual;
  final VoidCallback onClipboard;
  final VoidCallback onQrScan;

  const AddConfigSheet({
    super.key,
    required this.locale,
    required this.onManual,
    required this.onClipboard,
    required this.onQrScan,
  });

  /// Displays the add configuration bottom sheet modal.
  static void show(
    BuildContext context, {
    required String locale,
    required VoidCallback onManual,
    required VoidCallback onClipboard,
    required VoidCallback onQrScan,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddConfigSheet(
        locale: locale,
        onManual: () {
          Navigator.pop(ctx);
          onManual();
        },
        onClipboard: () {
          Navigator.pop(ctx);
          onClipboard();
        },
        onQrScan: () {
          Navigator.pop(ctx);
          onQrScan();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              locale == 'fa' ? 'افزودن کانفیگ جدید' : 'Add New Config',
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
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryAccent),
              ),
              title: Text(locale == 'fa' ? 'افزودن دستی (Add Config)' : 'Add Config Manually'),
              subtitle: Text(
                locale == 'fa' ? 'ساخت کانفیگ سفارشی با وارد کردن پارامترها' : 'Build custom configuration manually',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: onManual,
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
              title: Text(locale == 'fa' ? 'از کلیپ‌بورد (Import from Clipboard)' : 'Import from Clipboard'),
              subtitle: Text(
                locale == 'fa' ? 'خواندن لینک‌های vless، vmess و trojan کپی‌شده' : 'Paste copied vless, vmess, trojan configs',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: onClipboard,
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.amber),
              ),
              title: Text(locale == 'fa' ? 'اسکن بارکد (Scan QR Code)' : 'Scan QR Code'),
              subtitle: Text(
                locale == 'fa' ? 'اسکن بارکد QR از طریق دوربین گوشی' : 'Scan QR image with camera',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: onQrScan,
            ),
          ],
        ),
      ),
    );
  }
}
