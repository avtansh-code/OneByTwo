import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';

/// Loading skeleton rendered while the friendship doc + the two snapshot
/// streams resolve their first emission (SCR-11 / Haldi 11), reskinned to
/// the shimmer `OBTSkeleton` set (DC-06). Freezes under reduced motion.
class FriendDetailLoadingState extends StatelessWidget {
  /// Creates a [FriendDetailLoadingState].
  const FriendDetailLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('friend_detail_skeleton'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: <Widget>[
        Column(
          children: <Widget>[
            const OBTSkeletonCircle(diameter: 80),
            const SizedBox(height: 16),
            OBTSkeleton(
              width: 160,
              height: 20,
              borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
            ),
            const SizedBox(height: 12),
            OBTSkeleton(
              width: 200,
              height: 36,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const OBTSkeletonList(itemCount: 3),
      ],
    );
  }
}

/// Empty-state placeholder rendered when the friendship has zero expenses
/// AND zero settlements (SCR-11 / Haldi 11), reskinned to `OBTEmptyState`.
class FriendDetailEmptyState extends StatelessWidget {
  /// Creates a [FriendDetailEmptyState].
  const FriendDetailEmptyState({required this.friendDisplayName, super.key});

  /// The friend's display name — interpolated into the subtitle.
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OBTEmptyState(
      illustration: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.receipt_long_outlined,
          size: 52,
          color: colors.primary,
        ),
      ),
      headline: 'No expenses yet',
      supportingText:
          'Add an expense with $friendDisplayName to start tracking.',
    );
  }
}

/// Error placeholder rendered when the friendship doc or either stream
/// fails. Tapping Retry invokes [onRetry], which the screen wires to
/// `ref.invalidate(friendDetailProvider(args))` so all three sources
/// re-resolve.
class FriendDetailErrorState extends StatelessWidget {
  /// Creates a [FriendDetailErrorState].
  const FriendDetailErrorState({required this.onRetry, super.key});

  /// Callback invoked when the user taps Retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't load this friend's details. Please try again.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: OBTColors.metaText(theme),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
