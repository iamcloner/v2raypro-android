// Logs Console Window Widget
// Renders the stylized dark terminal console container with macOS-inspired window controls.
// Displays scrollable log entry tiles with alternating row backgrounds and empty search states.
// Formatted with high-contrast monospace typography for terminal debugging.

import 'package:flutter/material.dart';
import '../../models/log_entry.dart';
import 'log_entry_tile.dart';

/// Terminal console window widget for log presentation.
/// Manages decorative window header, log line counter, and the scrollable list of recorded logs.
class LogsConsoleWindow extends StatelessWidget {
  final ScrollController scrollController;
  final List<LogEntry> displayedLogs;
  final int totalCount;
  final bool showLast100Only;
  final String searchQuery;
  final String selectedCategory;
  final String locale;
  final void Function(LogEntry entry) onTapEntry;
  final void Function(LogEntry entry) onLongPressEntry;

  const LogsConsoleWindow({
    super.key,
    required this.scrollController,
    required this.displayedLogs,
    required this.totalCount,
    required this.showLast100Only,
    required this.searchQuery,
    required this.selectedCategory,
    required this.locale,
    required this.onTapEntry,
    required this.onLongPressEntry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D14) : const Color(0xFF131924),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF00D2FF).withValues(alpha: 0.18) : Colors.blueGrey.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildTerminalHeader(isDark),
            Expanded(
              child: displayedLogs.isEmpty
                  ? _buildEmptyTerminal()
                  : Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        itemCount: displayedLogs.length,
                        itemBuilder: (context, index) {
                          final entry = displayedLogs[index];
                          return LogEntryTile(
                            entry: entry,
                            isEven: index % 2 == 0,
                            onTap: () => onTapEntry(entry),
                            onLongPress: () => onLongPressEntry(entry),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1522) : const Color(0xFF1A2232),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5F56))),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFBD2E))),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF27C93F))),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            "CONSOLE • XRAY & SYSTEM",
            style: TextStyle(
              fontFamily: "Consolas",
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.blueGrey.shade300,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              showLast100Only && totalCount > 100 ? "100 / $totalCount" : "$totalCount",
              style: const TextStyle(
                fontFamily: "Consolas",
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D2FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTerminal() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D2FF).withValues(alpha: 0.08),
              ),
              child: Icon(
                searchQuery.isNotEmpty || selectedCategory != 'all'
                    ? Icons.search_off_rounded
                    : Icons.terminal_rounded,
                size: 40,
                color: const Color(0xFF00D2FF).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              searchQuery.isNotEmpty || selectedCategory != 'all'
                  ? (locale == 'fa' ? 'هیچ لاگی با این فیلتر یا جستجو یافت نشد.' : 'No matching logs found.')
                  : (locale == 'fa' ? 'هنوز لاگی ثبت نشده است.' : 'No logs recorded yet.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
