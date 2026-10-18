// Subscription Information & Traffic Badges
// Renders metadata chips and indicators for a subscription item,
// including remaining traffic quota, expiration countdown, and last updated timestamp.
// Android optimized UI component.

import 'package:flutter/material.dart';
import '../../models/subscription_item.dart';

/// Renders complementary info badges for remaining traffic quota and subscription expiry.
/// Generates colored badges for displaying remaining bandwidth and expiration time.
class SubInfoBadges extends StatelessWidget {
  final SubscriptionItem sub;

  /// Creates the subscription info badges widget.
  const SubInfoBadges({
    super.key,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${sub.nodeCount} nodes  •  ${sub.lastUpdated != null ? 'Updated: ' + sub.lastUpdated!.toLocal().toString().substring(0, 16) : 'Never updated'}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        if (sub.formattedRemainingTraffic != null || sub.formattedRemainingTime != null) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (sub.formattedRemainingTraffic != null) _buildTrafficBadge(),
              if (sub.formattedRemainingTime != null) _buildExpiryBadge(),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds the graphical remaining traffic quota badge.
  Widget _buildTrafficBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.data_usage_rounded, size: 12, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text(
            sub.formattedRemainingTraffic!,
            style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Builds the subscription expiry badge with warning color if expired.
  Widget _buildExpiryBadge() {
    final isExpired = sub.expireDate != null && sub.expireDate!.isBefore(DateTime.now());
    final color = isExpired ? Colors.redAccent : Colors.orangeAccent;
    final bgColor = isExpired ? Colors.red.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            sub.formattedRemainingTime!,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
