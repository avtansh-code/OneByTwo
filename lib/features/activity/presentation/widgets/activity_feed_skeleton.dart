import 'package:flutter/material.dart';

import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';

/// Shimmer skeleton loader for the SCR-25 Activity Feed (Loading state).
///
/// Renders five placeholder rows on the shared Haldi [OBTSkeletonList]
/// (foundation "skeletons, not spinners"). DC-09 resolves the shimmer the
/// original static skeleton deferred: the shimmer sweeps under the shared
/// `OBTSkeleton` set and freezes to a static frame under reduced motion
/// ([MediaQueryData.disableAnimations]), so the reduce-motion presentation is
/// unchanged. The row geometry mirrors the populated `OBTActivityRow` (a 36 dp
/// leading circle + two text lines).
///
/// Keeps the `Key('activity_feed_skeleton')` the screen test targets and the
/// single `liveRegion` "Loading…" announcement [OBTSkeletonList] carries.
class ActivityFeedSkeleton extends StatelessWidget {
  /// Creates an [ActivityFeedSkeleton].
  const ActivityFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: OBTSkeletonList(
        key: Key('activity_feed_skeleton'),
        itemCount: 5,
        spec: OBTSkeletonRowSpec(leadingDiameter: 36),
      ),
    );
  }
}
