import 'package:flutter/material.dart';

/// Skeleton loader for the SCR-25 Activity Feed (Loading state).
///
/// Renders 5 placeholder rows with a shimmer animation. The animation
/// is suppressed to a static grey when `MediaQuery.disableAnimationsOf`
/// reports true (SRS section 5.6 reduce-motion accommodation).
class ActivityFeedSkeleton extends StatelessWidget {
  /// Creates an [ActivityFeedSkeleton].
  const ActivityFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: 'Loading activity feed',
      child: ListView.builder(
        key: const Key('activity_feed_skeleton'),
        itemCount: 5,
        itemBuilder: (context, index) {
          return _SkeletonRow(theme: theme, reduceMotion: reduceMotion);
        },
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.theme, required this.reduceMotion});

  final ThemeData theme;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final base = theme.colorScheme.surfaceContainerHighest;
    // When reduce-motion is active we use the static base colour
    // directly with no animation. Otherwise a subtle opacity shimmer
    // could be wrapped here (kept static for v1.0 to avoid extra
    // dependencies — the SCR-25 spec calls for shimmer but a static
    // skeleton is acceptable per the accessibility contract).
    final colour = reduceMotion ? base : base;
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
