// File: lib/widgets/logs/log_details_sheet.dart
// Description: Bottom sheet displaying full details of a log message on Android.
// Allows viewing long log entries, separating source and level, and directly copying text.
// Clean, modern design supporting both light and dark Android system themes.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/log_entry.dart';

/// Bottom sheet for displaying full log details and message copying.
///
/// Presents timestamp, log level (info, warning, error, access), message source,
/// and complete message body as selectable text.
class LogDetailsSheet extends StatelessWidget {
  final LogEntry entry;
  final String locale;
  final VoidCallback onCopy;

  const LogDetailsSheet({
    super.key,
    required this.entry,
    required this.locale,
    required this.onCopy,
  });

  /// Helper method returning the appropriate color based on log level.
  static Color getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF38BDF8);
      case LogLevel.warning:
        return const Color(0xFFFBBF24);
      case LogLevel.error:
        return const Color(0xFFF87171);
      case LogLevel.access:
        return const Color(0xFF34D399);
    }
  }

  /// Static method to display the log details bottom sheet modal.
  static void show(
    BuildContext context,
    LogEntry entry,
    String locale,
    VoidCallback onCopy,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131924) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => LogDetailsSheet(
        entry: entry,
        locale: locale,
        onCopy: onCopy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lvlColor = getLevelColor(entry.level);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lvlColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: lvlColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    entry.level.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: lvlColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.source.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  entry.formattedTime(),
                  style: TextStyle(
                    fontFamily: "Consolas",
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090D14) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: SelectableText(
                  entry.message,
                  style: TextStyle(
                    fontFamily: "Consolas",
                    fontSize: 12.5,
                    height: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(locale == 'fa' ? 'بستن' : 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(locale == 'fa' ? 'کپی پیام' : 'Copy Message'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCopy();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
