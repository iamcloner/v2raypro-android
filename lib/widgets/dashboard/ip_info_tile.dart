// Dashboard Info Item & Ping Tile Widgets
// Renders individual labeled metric blocks for IP addresses, duration timers, and latency pings.
// Supports clipboard copying with haptic/snack feedback and live retest progress animations.
// Formatted with monospace typography and responsive touch targets for mobile.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Information display tile widget with clipboard copying capability.
class IpInfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool copyable;
  final String? copyValue;

  const IpInfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.copyable = false,
    this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF192030)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (copyable)
                InkWell(
                  onTap: () {
                    final textToCopy = copyValue ?? value;
                    Clipboard.setData(ClipboardData(text: textToCopy));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$textToCopy copied'), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(Icons.copy_rounded, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Ping latency display tile with instant retest button and color-coded latency indicator.
class IpPingTile extends StatelessWidget {
  final String title;
  final int? latency;
  final bool isTesting;
  final VoidCallback? onRetest;

  const IpPingTile({
    super.key,
    required this.title,
    required this.latency,
    required this.isTesting,
    this.onRetest,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (latency != null) {
      if (latency! < 150) {
        color = AppTheme.successColor;
      } else if (latency! < 300) {
        color = Colors.amber;
      } else {
        color = AppTheme.errorColor;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF192030)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onRetest != null)
                InkWell(
                  onTap: isTesting ? null : onRetest,
                  child: isTesting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryAccent),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(Icons.refresh_rounded, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            latency != null ? '$latency ms' : '--',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
