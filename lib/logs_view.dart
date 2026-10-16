import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/l10n/translations.dart";
import "core/theme/app_theme.dart";
import "models/log_entry.dart";
import "providers/app_providers.dart";
import "services/xray_process_service.dart";

class LogsView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenDrawer;
  const LogsView({super.key, this.onOpenDrawer});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'all'; // 'all', 'xray', 'system', 'test', 'info', 'warning', 'error', 'access'
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

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF38BDF8); // Electric Sky Blue
      case LogLevel.warning:
        return const Color(0xFFFBBF24); // Amber
      case LogLevel.error:
        return const Color(0xFFF87171); // Coral Red
      case LogLevel.access:
        return const Color(0xFF34D399); // Emerald
    }
  }

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

  void _showLogDetailsSheet(LogEntry entry, String locale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lvlColor = _levelColor(entry.level);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131924) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                        onPressed: () => Navigator.of(ctx).pop(),
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
                          Navigator.of(ctx).pop();
                          _copySingleLog(entry, locale);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(currentLocaleProvider);
    final allLogs = ref.watch(logsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Apply category & search filters
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
        if (!content.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    final displayedLogs = (_showLast100Only && filteredLogs.length > 100)
        ? filteredLogs.sublist(filteredLogs.length - 100)
        : filteredLogs;

    // Counts for categorized filter badges
    final totalCount = allLogs.length;
    final xrayCount = allLogs.where((e) => e.source == 'xray').length;
    final sysCount = allLogs.where((e) => e.source == 'system').length;
    final testCount = allLogs.where((e) => e.source == 'test').length;
    final infoCount = allLogs.where((e) => e.level == LogLevel.info).length;
    final warnCount = allLogs.where((e) => e.level == LogLevel.warning).length;
    final errCount = allLogs.where((e) => e.level == LogLevel.error).length;
    final accessCount = allLogs.where((e) => e.level == LogLevel.access).length;

    // Trigger auto-scroll if enabled and new logs arrived
    ref.listen<List<LogEntry>>(logsProvider, (_, __) {
      if (_autoScroll) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: Platform.isAndroid
          ? AppBar(
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.terminal_rounded, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.get('logs', locale: locale),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  // Live Pulse Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: _autoScroll
                          ? const Color(0x2210B981)
                          : Colors.grey.withValues(alpha: 0.15),
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
                          _autoScroll
                              ? (locale == 'fa' ? 'زنده' : 'LIVE')
                              : (locale == 'fa' ? 'مکث' : 'PAUSED'),
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
                  onPressed: allLogs.isEmpty
                      ? null
                      : () {
                          ref.read(logsProvider.notifier).clear();
                        },
                ),
              ],
            )
          : null,
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
            if (!Platform.isAndroid) ...[
              // Desktop Top Bar: Title, Live Status, Action buttons
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D2FF), Color(0xFF0072FF)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.terminal_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.get("logs", locale: locale),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        const SizedBox(width: 5),
                        Text(
                          _autoScroll
                              ? (locale == 'fa' ? 'اسکرول زنده' : 'LIVE')
                              : (locale == 'fa' ? 'مکث' : 'PAUSED'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _autoScroll ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Auto-scroll toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _autoScroll = !_autoScroll;
                        if (_autoScroll) _scrollToBottom();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _autoScroll
                            ? AppTheme.primaryAccent.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _autoScroll ? AppTheme.primaryAccent : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: _autoScroll ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.get("autoscroll", locale: locale),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _autoScroll ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Copy all button
                  IconButton(
                    tooltip: AppStrings.get("copy_logs", locale: locale),
                    icon: Icon(Icons.copy_rounded, size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: filteredLogs.isEmpty ? null : () => _copyAllLogs(filteredLogs, locale),
                  ),
                  const SizedBox(width: 8),
                  // Clear logs button
                  IconButton(
                    tooltip: AppStrings.get("clear_logs", locale: locale),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: allLogs.isEmpty
                        ? null
                        : () {
                            ref.read(logsProvider.notifier).clear();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 1. Sleek Search and 100/All Toggle Bar
            Row(
              children: [
                // Modern Search Field
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141A26) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: locale == 'fa' ? 'جستجو در متن لاگ‌ها...' : 'Search logs...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryAccent),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Compact Segmented Pill Toggle
                Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A26) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPillToggleItem(
                        selected: _showLast100Only,
                        label: locale == 'fa' ? '۱۰۰ لاگ' : '100 Logs',
                        icon: Icons.filter_1_rounded,
                        onTap: () => setState(() => _showLast100Only = true),
                      ),
                      _buildPillToggleItem(
                        selected: !_showLast100Only,
                        label: locale == 'fa' ? 'همه' : 'All',
                        icon: Icons.all_inclusive_rounded,
                        onTap: () => setState(() => _showLast100Only = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. Horizontal Scrollable Category Capsules with Icons & Live Counts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCategoryCapsule(
                    id: 'all',
                    label: locale == 'fa' ? 'همه' : 'All',
                    count: totalCount,
                    icon: Icons.bubble_chart_rounded,
                    color: AppTheme.primaryAccent,
                  ),
                  const SizedBox(width: 6),
                  _buildCategoryCapsule(
                    id: 'xray',
                    label: locale == 'fa' ? 'هسته Xray' : 'Xray Core',
                    count: xrayCount,
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF00D2FF),
                  ),
                  const SizedBox(width: 6),
                  _buildCategoryCapsule(
                    id: 'system',
                    label: locale == 'fa' ? 'سیستم' : 'System',
                    count: sysCount,
                    icon: Icons.memory_rounded,
                    color: const Color(0xFFA855F7),
                  ),
                  if (testCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildCategoryCapsule(
                      id: 'test',
                      label: locale == 'fa' ? 'تست تاخیر' : 'Delay Test',
                      count: testCount,
                      icon: Icons.speed_rounded,
                      color: const Color(0xFFFB923C),
                    ),
                  ],
                  const SizedBox(width: 6),
                  _buildCategoryCapsule(
                    id: 'info',
                    label: locale == 'fa' ? 'اطلاعات' : 'Info',
                    count: infoCount,
                    icon: Icons.info_outline_rounded,
                    color: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 6),
                  _buildCategoryCapsule(
                    id: 'warning',
                    label: locale == 'fa' ? 'هشدار' : 'Warning',
                    count: warnCount,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 6),
                  _buildCategoryCapsule(
                    id: 'error',
                    label: locale == 'fa' ? 'خطا' : 'Error',
                    count: errCount,
                    icon: Icons.error_outline_rounded,
                    color: const Color(0xFFF87171),
                  ),
                  const SizedBox(width: 6),
                  _buildCategoryCapsule(
                    id: 'access',
                    label: locale == 'fa' ? 'شبکه' : 'Access',
                    count: accessCount,
                    icon: Icons.swap_horiz_rounded,
                    color: const Color(0xFF34D399),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Main Modern Terminal Window Console
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF090D14) : const Color(0xFF131924),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF00D2FF).withValues(alpha: 0.18)
                        : Colors.blueGrey.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // macOS / Cyber Terminal Window Header
                      Container(
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
                            // Window traffic lights
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
                            // Console Title
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
                            // Log Counter Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _showLast100Only && filteredLogs.length > 100
                                    ? "100 / ${filteredLogs.length}"
                                    : "${filteredLogs.length}",
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
                      ),

                      // Console Log Stream List
                      Expanded(
                        child: displayedLogs.isEmpty
                            ? Center(
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
                                          _searchQuery.isNotEmpty || _selectedCategory != 'all'
                                              ? Icons.search_off_rounded
                                              : Icons.terminal_rounded,
                                          size: 40,
                                          color: const Color(0xFF00D2FF).withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty || _selectedCategory != 'all'
                                            ? (locale == 'fa' ? 'هیچ لاگی با این فیلتر یا جستجو یافت نشد.' : 'No matching logs found.')
                                            : (locale == 'fa' ? 'هنوز لاگی ثبت نشده است.' : 'No logs recorded yet.'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_searchQuery.isEmpty && _selectedCategory == 'all') ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          locale == 'fa'
                                              ? 'با برقراری اتصال، فعالیت هسته Xray در این ترمینال نمایش داده می‌شود.'
                                              : 'Live core routing and proxy activities will appear here.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade400,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  itemCount: displayedLogs.length,
                                  itemBuilder: (context, index) {
                                    final entry = displayedLogs[index];
                                    final lvlColor = _levelColor(entry.level);
                                    final isEven = index % 2 == 0;

                                    return InkWell(
                                      onTap: () => _showLogDetailsSheet(entry, locale),
                                      onLongPress: () => _copySingleLog(entry, locale),
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
                                            // Timestamp in mono font
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
                                            // Level Badge
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
                                            // Source Tag
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
                                            // Message
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
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillToggleItem({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCapsule({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedCategory == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = id);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.22)
              : (isDark ? const Color(0xFF141A26) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.35)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
