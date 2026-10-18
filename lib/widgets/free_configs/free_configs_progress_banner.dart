// Free Configs Progress Banner Widget
// Displays live progress indicators, candidate counts, and status labels during background scanning.
// Shows animated circular spinners and percentage bars with amber accents.
// Adapts cleanly to dark and light Android interface themes.

import 'package:flutter/material.dart';
import '../../providers/app_providers.dart';

/// Progress banner for background scanning and automatic testing of free configs.
/// Displays tested config counts and overall progress percentage.
class FreeConfigsProgressBanner extends StatelessWidget {
  final FreeConfigsState state;
  final String locale;

  const FreeConfigsProgressBanner({
    super.key,
    required this.state,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.status == 'fetching'
                        ? (locale == 'fa' ? 'درحال دریافت...' : 'Fetching...')
                        : (locale == 'fa' ? 'درحال تست...' : 'Testing...'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              Text(
                '${state.testedCandidates} / ${state.totalUnique} (${(state.progress * 100).toInt()}%)',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              minHeight: 5,
              backgroundColor: Colors.white10,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }
}
