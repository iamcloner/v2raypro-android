// File: lib/widgets/logs/log_filter_bar.dart
// Description: Search bar and category filter pills for logs on Android.
// Allows filtering by source, severity, live text query, and toggling last 100 logs.
// Responsive layout with tactile touch effects optimized for mobile devices.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Log filter and search bar widget.
///
/// Controls live search input, last-100-versus-all log toggle,
/// and horizontal scrollable category pills (Xray, System, Errors, etc.).
class LogFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategory;
  final bool showLast100Only;
  final String locale;
  final int totalCount;
  final int xrayCount;
  final int sysCount;
  final int testCount;
  final int infoCount;
  final int warnCount;
  final int errCount;
  final int accessCount;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<bool> onToggleShow100;

  const LogFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.showLast100Only,
    required this.locale,
    required this.totalCount,
    required this.xrayCount,
    required this.sysCount,
    required this.testCount,
    required this.infoCount,
    required this.warnCount,
    required this.errCount,
    required this.accessCount,
    required this.onCategorySelected,
    required this.onToggleShow100,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
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
                  controller: searchController,
                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: locale == 'fa' ? 'جستجو در متن لاگ‌ها...' : 'Search logs...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryAccent),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () => searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                    selected: showLast100Only,
                    label: locale == 'fa' ? '۱۰۰ لاگ' : '100 Logs',
                    icon: Icons.filter_1_rounded,
                    onTap: () => onToggleShow100(true),
                  ),
                  _buildPillToggleItem(
                    selected: !showLast100Only,
                    label: locale == 'fa' ? 'همه' : 'All',
                    icon: Icons.all_inclusive_rounded,
                    onTap: () => onToggleShow100(false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildCategoryCapsule(
                context: context,
                id: 'all',
                label: locale == 'fa' ? 'همه' : 'All',
                count: totalCount,
                icon: Icons.bubble_chart_rounded,
                color: AppTheme.primaryAccent,
              ),
              const SizedBox(width: 6),
              _buildCategoryCapsule(
                context: context,
                id: 'xray',
                label: locale == 'fa' ? 'هسته Xray' : 'Xray Core',
                count: xrayCount,
                icon: Icons.bolt_rounded,
                color: const Color(0xFF00D2FF),
              ),
              const SizedBox(width: 6),
              _buildCategoryCapsule(
                context: context,
                id: 'system',
                label: locale == 'fa' ? 'سیستم' : 'System',
                count: sysCount,
                icon: Icons.memory_rounded,
                color: const Color(0xFFA855F7),
              ),
              if (testCount > 0) ...[
                const SizedBox(width: 6),
                _buildCategoryCapsule(
                  context: context,
                  id: 'test',
                  label: locale == 'fa' ? 'تست تاخیر' : 'Delay Test',
                  count: testCount,
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFFB923C),
                ),
              ],
              const SizedBox(width: 6),
              _buildCategoryCapsule(
                context: context,
                id: 'info',
                label: locale == 'fa' ? 'اطلاعات' : 'Info',
                count: infoCount,
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 6),
              _buildCategoryCapsule(
                context: context,
                id: 'warning',
                label: locale == 'fa' ? 'هشدار' : 'Warning',
                count: warnCount,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFBBF24),
              ),
              const SizedBox(width: 6),
              _buildCategoryCapsule(
                context: context,
                id: 'error',
                label: locale == 'fa' ? 'خطا' : 'Error',
                count: errCount,
                icon: Icons.error_outline_rounded,
                color: const Color(0xFFF87171),
              ),
              const SizedBox(width: 6),
              _buildCategoryCapsule(
                context: context,
                id: 'access',
                label: locale == 'fa' ? 'شبکه' : 'Access',
                count: accessCount,
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFF34D399),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the toggle button for filtering between last 100 logs and all logs.
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

  /// Builds a category pill badge with live entry counts.
  Widget _buildCategoryCapsule({
    required BuildContext context,
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedCategory == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onCategorySelected(id);
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
