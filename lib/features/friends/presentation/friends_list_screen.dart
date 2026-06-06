import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_screen.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_list_tile.dart';

/// Friends list screen (SCR-09 / FR-FR-03).
///
/// Renders the four states defined by SCR-09:
///
/// - **Loading**: shimmer placeholders while the Firestore snapshot
///   stream resolves the first emission.
/// - **Populated**: a list of `FriendListTile` rows with the
///   server-maintained simplified net balance per friend, ordered by
///   `lastActivityAt` desc.
/// - **Empty**: the empty-state illustration and Add Friend CTA when
///   the user has zero friendships.
/// - **Error**: a generic error message with a Retry button.
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: balance values reach this widget as `int`
///   on `FriendListItem.netBalancePaise`; the trailing `BalancePill`
///   formats via `formatInrFromPaise()`.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this screen
///   reads the field via the repository stream but never writes back.
///   A separate Firestore Security Rules test guards the boundary.
class FriendsListScreen extends ConsumerStatefulWidget {
  /// Creates a [FriendsListScreen].
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  bool _loggedView = false;

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add friend',
            onPressed: _onAddFriendTapped,
          ),
        ],
      ),
      body: friendsAsync.when(
        loading: () => const _LoadingState(),
        error: (error, stack) =>
            _ErrorState(onRetry: () => ref.invalidate(friendsListProvider)),
        data: (items) {
          _logViewedOnce(items.length);
          if (items.isEmpty) {
            return _EmptyState(onAddFriend: _onEmptyAddTapped);
          }
          return _PopulatedState(items: items, onRowTap: _onRowTapped);
        },
      ),
    );
  }

  void _logViewedOnce(int friendCount) {
    if (_loggedView) return;
    _loggedView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'friends_list_viewed',
            parameters: {'friend_count': friendCount},
          ),
    );
  }

  void _onAddFriendTapped() {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'friend_add_button_tapped'),
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddFriendScreen()),
    );
  }

  void _onEmptyAddTapped() {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'friends_empty_add_tapped'),
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddFriendScreen()),
    );
  }

  void _onRowTapped(FriendListItem item) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'friend_row_tapped',
            parameters: {
              'friendship_id_hash': hashFriendshipId(item.friendshipId),
            },
          ),
    );
    final currentUid = ref.read(currentUserIdProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendDetailScreen(
          friendshipId: item.friendshipId,
          currentUserUid: currentUid,
          otherUserUid: item.otherUserId,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      key: const Key('friends_list_skeleton'),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PopulatedState extends StatelessWidget {
  const _PopulatedState({required this.items, required this.onRowTap});

  final List<FriendListItem> items;
  final void Function(FriendListItem item) onRowTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return FriendListTile(item: item, onTap: () => onRowTap(item));
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddFriend});

  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a friend and start sharing expenses.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddFriend,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Friend'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

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
              'We could not load your friends list. Please try again.',
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
