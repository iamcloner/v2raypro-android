// File: lib/logs_view.dart
// Description: Live console display for Xray core and system logs in Android.
// Supports filtering by source, log level, and query text, along with auto-scroll
// and quick copy functionality for troubleshooting VPN connections.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/translations.dart';
import 'core/theme/app_theme.dart';
import 'models/log_entry.dart';
import 'providers/app_providers.dart';
import 'services/xray_process_service.dart';
import 'widgets/logs/log_details_sheet.dart';
import 'widgets/logs/log_entry_tile.dart';
import 'widgets/logs/log_filter_bar.dart';
import 'widgets/logs/logs_console_window.dart';

/// Console log screen widget for v2raypro.
///
/// Handles Android native log synchronization, terminal-style text output,
/// auto-scrolling to the latest entries, and log filtering.
class LogsView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  const LogsView({super.key, this.onOpenDrawer});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'all';
  bool _autoScroll = true;
  bool _showLast100Only = true;
  bool _showScrollToBottomFab = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.offset;
      final shouldShow = offsetFromBottom > 250;
      if (shouldShow != _showScrollToBottomFab) {
        setState(() {
          _showScrollToBottomFab = shouldShow;
        });
      }
    });

    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        XrayProcessService.instance.syncAndroidLogs();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Smoothly scrolls the log list to the bottom.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Copies all currently filtered logs to clipboard.
  void _copyAllLogs(List<LogEntry> filteredLogs, String locale) {
    if (filteredLogs.isEmpty) return;
    final text = filteredLogs
        .map((e) => "[${e.formattedTime()}] [${e.level.name.toUpperCase()}] [${e.source.toUpperCase()}] ${e.message}")
        .join("\n");

    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 20),
            const SizedBox(width: 8),
            Text(locale == 'fa' ? '${filteredLogs.length} خط لاگ کپی شد' : '${filteredLogs.length} log lines copied'),
          ],
        ),
        backgroundColor: const Color(0xFF1E2638),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Copies a single log entry to clipboard.
  void _copySingleLog(LogEntry entry, String locale) {
    final text = "[${entry.formattedTime()}] [${entry.level.name.toUpperCase()}] [${entry.source.toUpperCase()}] ${entry.message}";
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_rounded, color: Colors.tealAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locale == 'fa' ? 'پیام لاگ کپی شد' : 'Log entry copied',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E2638),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(currentLocaleProvider);
    final allLogs = ref.watch(logsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredLogs = allLogs.where((entry) {
      if (_selectedCategory == 'xray' && entry.source != 'xray') return false;
      if (_selectedCategory == 'system' && entry.source != 'system') return false;
      if (_selectedCategory == 'test' && entry.source != 'test') return false;
      if (_selectedCategory == 'info' && entry.level != LogLevel.info) return false;
      if (_selectedCategory == 'warning' && entry.level != LogLevel.warning) return false;
      if (_selectedCategory == 'error' && entry.level != LogLevel.error) return false;
      if (_selectedCategory == 'access' && entry.level != LogLevel.access) return false;

      if (_searchQuery.isNotEmpty) {
        final content = "${entry.message} ${entry.source} ${entry.level.name}".toLowerCase();
        if (!content.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();

    final displayedLogs = (_showLast100Only && filteredLogs.length > 100)
        ? filteredLogs.sublist(filteredLogs.length - 100)
        : filteredLogs;

    final totalCount = allLogs.length;
    final xrayCount = allLogs.where((e) => e.source == 'xray').length;
    final sysCount = allLogs.where((e) => e.source == 'system').length;
    final testCount = allLogs.where((e) => e.source == 'test').length;
    final infoCount = allLogs.where((e) => e.level == LogLevel.info).length;
    final warnCount = allLogs.where((e) => e.level == LogLevel.warning).length;
    final errCount = allLogs.where((e) => e.level == LogLevel.error).length;
    final accessCount = allLogs.where((e) => e.level == LogLevel.access).length;

    ref.listen<List<LogEntry>>(logsProvider, (_, __) {
      if (_autoScroll) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
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
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF0072FF)],
                ),
              ),
              child: const Icon(Icons.terminal_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.get('logs', locale: locale),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: _autoScroll ? const Color(0x2210B981) : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _autoScroll ? const Color(0xFF10B981) : Colors.grey,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _autoScroll ? const Color(0xFF10B981) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _autoScroll ? (locale == 'fa' ? 'زنده' : 'LIVE') : (locale == 'fa' ? 'مکث' : 'PAUSED'),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _autoScroll ? const Color(0xFF10B981) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _autoScroll
                ? (locale == 'fa' ? 'توقف اسکرول خودکار' : 'Pause Auto-scroll')
                : (locale == 'fa' ? 'فعال‌سازی اسکرول خودکار' : 'Enable Auto-scroll'),
            icon: Icon(
              Icons.arrow_downward_rounded,
              size: 20,
              color: _autoScroll ? AppTheme.primaryAccent : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
                if (_autoScroll) _scrollToBottom();
              });
            },
          ),
          IconButton(
            tooltip: AppStrings.get("copy_logs", locale: locale),
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: filteredLogs.isEmpty ? null : () => _copyAllLogs(filteredLogs, locale),
          ),
          IconButton(
            tooltip: AppStrings.get("clear_logs", locale: locale),
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
            onPressed: allLogs.isEmpty ? null : () => ref.read(logsProvider.notifier).clear(),
          ),
        ],
      ),
      floatingActionButton: _showScrollToBottomFab
          ? FloatingActionButton.extended(
              onPressed: () {
                _scrollToBottom();
                setState(() => _autoScroll = true);
              },
              backgroundColor: AppTheme.primaryAccent,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.keyboard_double_arrow_down_rounded, size: 20),
              label: Text(
                locale == 'fa' ? 'جدیدترین لاگ‌ها' : 'Jump to Bottom',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LogFilterBar(
              searchController: _searchController,
              searchQuery: _searchQuery,
              selectedCategory: _selectedCategory,
              showLast100Only: _showLast100Only,
              locale: locale,
              totalCount: totalCount,
              xrayCount: xrayCount,
              sysCount: sysCount,
              testCount: testCount,
              infoCount: infoCount,
              warnCount: warnCount,
              errCount: errCount,
              accessCount: accessCount,
              onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
              onToggleShow100: (val) => setState(() => _showLast100Only = val),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LogsConsoleWindow(
                scrollController: _scrollController,
                displayedLogs: displayedLogs,
                totalCount: filteredLogs.length,
                showLast100Only: _showLast100Only,
                searchQuery: _searchQuery,
                selectedCategory: _selectedCategory,
                locale: locale,
                onTapEntry: (entry) => LogDetailsSheet.show(context, entry, locale, () => _copySingleLog(entry, locale)),
                onLongPressEntry: (entry) => _copySingleLog(entry, locale),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
