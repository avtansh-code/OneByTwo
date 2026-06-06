import 'package:flutter/material.dart';

/// Loading skeleton rendered while the friendship doc + the two
/// snapshot streams resolve their first emission.
class FriendDetailLoadingState extends StatelessWidget {
  /// Creates a [FriendDetailLoadingState].
  const FriendDetailLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = theme.colorScheme.surfaceContainerHighest;
    return ListView(
      key: const Key('friend_detail_skeleton'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        Column(
          children: [
            CircleAvatar(radius: 40, backgroundColor: shimmerColor),
            const SizedBox(height: 16),
            Container(
              width: 160,
              height: 20,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 200,
              height: 36,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: shimmerColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Empty-state placeholder rendered when the friendship has zero
/// expenses AND zero settlements.
class FriendDetailEmptyState extends StatelessWidget {
  /// Creates a [FriendDetailEmptyState].
  const FriendDetailEmptyState({required this.friendDisplayName, super.key});

  /// The friend's display name — interpolated into the subtitle.
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add an expense with $friendDisplayName to start tracking.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          children: [
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
