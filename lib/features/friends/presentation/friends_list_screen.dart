import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_flow.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_list_tile.dart';

/// Friends list screen (SCR-09 / FR-FR-03), Haldi 9 (DC-06).
///
/// Renders the four states defined by SCR-09:
///
/// - **Loading**: the shimmer `OBTSkeleton` set (the summary-band pair plus
///   five row silhouettes) while the Firestore snapshot stream resolves.
/// - **Populated**: an additive owed/owe summary band over a list of
///   `FriendListTile` rows, each carrying the server-maintained simplified
///   net balance via the shared `OBTBalancePill`.
/// - **Empty**: the `OBTEmptyState` illustration and Add Friend CTA when
///   the user has zero friendships.
/// - **Error**: a generic error message with a Retry button.
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: balance values reach this widget as `int`
///   on `FriendListItem.netBalancePaise`; the trailing `OBTBalancePill`
///   and the summary band format via `formatInrFromPaise()`.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this screen reads
///   the field via the repository stream but never writes back. A
///   separate Firestore Security Rules test guards the boundary.
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
        actions: <Widget>[
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
    unawaited(_openAddFriendFlow());
  }

  void _onEmptyAddTapped() {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'friends_empty_add_tapped'),
    );
    unawaited(_openAddFriendFlow());
  }

  /// Opens the add-friend journey (AddFriendScreen -> Match-and-Invite).
  /// Reads the signed-in identity synchronously before navigating so the
  /// flow has the values it needs even across async navigation gaps.
  Future<void> _openAddFriendFlow() {
    return openAddFriendFlow(
      context: context,
      currentUserId: ref.read(currentUserIdProvider),
      currentUserPhone: ref.read(currentUserPhoneProvider),
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

/// The additive owed/owe summary band shown above the friend rows (Haldi
/// 9). Two tonal cards: the total the current user is owed (positive
/// balances) and the total the current user owes (the magnitudes of the
/// negative balances). A pure UI projection of the already-loaded list —
/// no new read, no `simplifiedBalances` write (Invariant 2); every amount
/// goes through `formatInrFromPaise()` (Invariant 1).
class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.items});

  final List<FriendListItem> items;

  @override
  Widget build(BuildContext context) {
    final obtColors =
        Theme.of(context).extension<OBTColors>() ?? OBTColors.light;

    var owedToYou = 0;
    var youOwe = 0;
    for (final item in items) {
      if (item.netBalancePaise > 0) {
        owedToYou += item.netBalancePaise;
      } else if (item.netBalancePaise < 0) {
        youOwe += item.netBalancePaise.abs();
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryCard(
              label: 'You are owed',
              amountPaise: owedToYou,
              hue: obtColors.balancePositive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'You owe',
              amountPaise: youOwe,
              hue: obtColors.balanceNegative,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amountPaise,
    required this.hue,
  });

  final String label;
  final int amountPaise;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = formatInrFromPaise(amountPaise);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label $amount',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: hue),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: theme.textTheme.titleLarge?.copyWith(
                color: hue,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('friends_list_skeleton'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OBTSkeleton(
                  height: 64,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OBTSkeleton(
                  height: 64,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const OBTSkeletonList(itemCount: 5),
      ],
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
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SummaryBand(items: items);
        }
        final item = items[index - 1];
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
    return OBTEmptyState(
      illustration: const _FriendsEmptyIllustration(),
      headline: 'No friends yet',
      supportingText: 'Add a friend and start sharing expenses.',
      ctaLabel: 'Add Friend',
      onCta: onAddFriend,
    );
  }
}

/// Flat illustration bubble for the friends empty state (Haldi 9): a
/// marigold-tinted disc holding the people glyph.
class _FriendsEmptyIllustration extends StatelessWidget {
  const _FriendsEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.group_outlined, size: 52, color: colors.primary),
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
              'We could not load your friends list. Please try again.',
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
