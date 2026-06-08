import 'package:flutter/material.dart';

/// Static skeleton loader for the SCR-25 Activity Feed (Loading state).
///
/// Renders 5 placeholder rows as static grey blocks. The SCR-25 spec
/// calls for a shimmer animation; per architect §2.6 the shimmer is
/// deferred to a future PR rather than pulling in an extra dependency.
/// A static skeleton remains acceptable per the SRS section 5.6
/// accessibility contract (reduce-motion users would see this exact
/// presentation either way).
class ActivityFeedSkeleton extends StatelessWidget {
  /// Creates an [ActivityFeedSkeleton].
  const ActivityFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: 'Loading activity feed',
      child: ListView.builder(
        key: const Key('activity_feed_skeleton'),
        itemCount: 5,
        itemBuilder: (context, index) {
          return _SkeletonRow(theme: theme);
        },
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colour = theme.colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: colour),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 100,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 16,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
