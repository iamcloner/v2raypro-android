// File: lib/widgets/logs/log_entry_tile.dart
// Description: Row displaying a log record in the simulated terminal log view.
// Features monospaced font formatting, color-coded level badges, source tags, and event messages.
// Optimized for fast, low-overhead scrolling on Android devices.

import 'package:flutter/material.dart';
import '../../models/log_entry.dart';
import 'log_details_sheet.dart';

/// Log entry row widget in the terminal console environment.
///
/// Displays event timestamp, message severity level (Info, Warn, Error, Access),
/// source tag (Xray, System), and formatted message text.
class LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  final bool isEven;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const LogEntryTile({
    super.key,
    required this.entry,
    required this.isEven,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final lvlColor = LogDetailsSheet.getLevelColor(entry.level);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isEven ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.formattedTime(),
              style: TextStyle(
                fontFamily: "Consolas",
                fontSize: 11.5,
                color: Colors.blueGrey.shade400,
                height: 1.4,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 0.5),
              decoration: BoxDecoration(
                color: lvlColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: lvlColor.withValues(alpha: 0.35),
                  width: 0.6,
                ),
              ),
              child: Text(
                entry.level.name.toUpperCase().padRight(4),
                style: TextStyle(
                  fontFamily: "Consolas",
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: lvlColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "[${entry.source.toUpperCase()}]",
              style: TextStyle(
                fontFamily: "Consolas",
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: entry.source == 'xray'
                    ? const Color(0xFF67E8F9)
                    : (entry.source == 'system' ? const Color(0xFFC084FC) : const Color(0xFFFDBA74)),
                height: 1.4,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                entry.message,
                style: TextStyle(
                  fontFamily: "Consolas",
                  fontSize: 12,
                  height: 1.4,
                  color: entry.level == LogLevel.error
                      ? const Color(0xFFFCA5A5)
                      : (entry.level == LogLevel.warning
                          ? const Color(0xFFFDE047)
                          : const Color(0xFFF8FAFC)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
