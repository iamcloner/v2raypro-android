// Startup Update Dialog Widget
// Displays a modal alert dialog when a new version of V2Ray Pro is detected on launch.
// Provides live progress tracking during update download and installation trigger on Android.
// Designed with a dark modern aesthetic and clear localization support.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/update_service.dart';

/// Displays an update notification modal dialog on application startup.
/// Manages new release details, download links, and installation progress status.
Future<void> showStartupUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  UpdateInfo info,
) async {
  final locale = ref.read(currentLocaleProvider);
  bool downloading = false;
  double progress = 0.0;
  String status = '';

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Colors.tealAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locale == 'fa' ? 'به‌روزرسانی جدید موجود است' : 'New Update Available',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale == 'fa'
                    ? 'نسخه جدید (${info.latestVersion}) در گیت‌هاب منتشر شده است.\nنسخه فعلی شما: ${UpdateService.currentAppVersion}\n\nآیا مایل به دانلود و نصب آخرین نسخه هستید؟'
                    : 'A new version (${info.latestVersion}) is published.\nYour current version: ${UpdateService.currentAppVersion}\n\nWould you like to update now?',
                style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white70),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(status, style: const TextStyle(fontSize: 12, color: Colors.tealAccent)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ],
            ],
          ),
          actions: [
            if (!downloading)
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(locale == 'fa' ? 'بعداً' : 'Later', style: const TextStyle(color: Colors.grey)),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.downloading_rounded, size: 18),
              label: Text(
                downloading
                    ? (locale == 'fa' ? 'در حال دانلود...' : 'Downloading...')
                    : (locale == 'fa' ? 'دانلود و نصب' : 'Download and Install'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: downloading
                  ? null
                  : () async {
                      setDialogState(() {
                        downloading = true;
                        progress = 0.0;
                        status = locale == 'fa' ? 'در حال دانلود بسته آپدیت...' : 'Downloading update package...';
                      });

                      try {
                        final success = await UpdateService.instance.downloadAndApplyAppUpdate(
                          info.downloadUrl ?? "https://github.com/iamcloner/v2raypro-android/releases",
                          onProgress: (phase, p) {
                            setDialogState(() {
                              progress = p;
                              if (phase == 'downloading') {
                                status = locale == 'fa'
                                    ? 'در حال دریافت بسته به‌روزرسانی (${(p * 100).toInt()}%)'
                                    : 'Downloading update package (${(p * 100).toInt()}%)';
                              } else if (phase == 'installing') {
                                status = locale == 'fa'
                                    ? 'در حال باز کردن نصب‌کننده اندروید...'
                                    : 'Opening Android Package Installer...';
                              } else if (phase == 'extracting') {
                                status = locale == 'fa' ? 'در حال استخراج فایل‌ها...' : 'Extracting files...';
                              } else if (phase == 'applying') {
                                status = locale == 'fa' ? 'در حال جایگزینی و ریستارت برنامه...' : 'Applying update and restarting...';
                              }
                            });
                          },
                        );
                        if (dialogCtx.mounted && Platform.isAndroid && success) {
                          Navigator.of(dialogCtx).pop();
                        } else if (!success) {
                          setDialogState(() {
                            downloading = false;
                            status = locale == 'fa' ? 'خطا در اعمال به‌روزرسانی.' : 'Failed to apply update.';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          downloading = false;
                          status = 'Error: $e';
                        });
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
}
