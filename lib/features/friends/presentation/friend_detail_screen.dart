import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_header.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_states.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_timeline.dart';
import 'package:onebytwo/features/friends/presentation/widgets/obt_settle_up_card.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';

/// Friend Detail screen (SCR-11 / FR-FR-04).
///
/// Renders the per-friend transaction history by composing:
/// - [FriendDetailHeaderWidget] — avatar + name + large balance pill.
/// - [FriendDetailTimelineWidget] — intermixed expense + settlement
///   timeline (top 5).
/// - [FriendDetailEmptyState] / [FriendDetailLoadingState] /
///   [FriendDetailErrorState] for the non-populated states.
/// - A FAB that opens [AddExpenseBottomSheet] (the PR #38 wiring
///   preserved verbatim).
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: every monetary value flows through
///   `formatInrFromPaise()`; no inline `/100` math. The boundary
///   contract grep enforces.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: the header pill
///   derives from `simplifiedBalances` via `netBalancePaise()` in the
///   provider; this widget never writes to the field.
///
/// Replaces the original `FriendDetailPlaceholderScreen` (PR #35) and
/// preserves the same three-field constructor so the call site in
/// `FriendsListScreen._onRowTapped` needs no change.
class FriendDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [FriendDetailScreen].
  const FriendDetailScreen({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    super.key,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  @override
  ConsumerState<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  bool _loggedView = false;

  FriendDetailArgs get _args => FriendDetailArgs(
    friendshipId: widget.friendshipId,
    currentUserUid: widget.currentUserUid,
    otherUserUid: widget.otherUserUid,
  );

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(friendDetailProvider(_args));

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle(asyncState))),
      body: asyncState.when(
        loading: () => const FriendDetailLoadingState(),
        error: (error, stack) => FriendDetailErrorState(
          onRetry: () => ref.invalidate(friendDetailProvider(_args)),
        ),
        data: (state) {
          _logViewedOnce(state);
          switch (state) {
            case FriendDetailStateEmpty():
              return Column(
                children: [
                  FriendDetailHeaderWidget(header: state.header),
                  Expanded(
                    child: FriendDetailEmptyState(
                      friendDisplayName: state.header.displayName,
                    ),
                  ),
                ],
              );
            case FriendDetailStatePopulated():
              return SingleChildScrollView(
                child: Column(
                  children: [
                    FriendDetailHeaderWidget(header: state.header),
                    if (state.header.balanceState == BalanceState.owes)
                      OBTSettleUpCard(
                        payerDisplayName: 'You',
                        payerPhotoUrl: null,
                        payeeDisplayName: state.header.displayName,
                        payeePhotoUrl: state.header.photoUrl,
                        suggestedAmountPaise: state.header.netBalancePaise
                            .abs(),
                        onSettleUp: () => _onSettleUpTapped(context, state),
                      ),
                    FriendDetailTimelineWidget(
                      timeline: state.timeline,
                      friendshipId: widget.friendshipId,
                      currentUserUid: widget.currentUserUid,
                      otherUserUid: widget.otherUserUid,
                      friendDisplayName: state.header.displayName,
                    ),
                  ],
                ),
              );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add expense',
        onPressed: () => _openAddExpenseSheet(context),
        child: const Icon(Icons.add, semanticLabel: 'Add expense'),
      ),
    );
  }

  String _appBarTitle(AsyncValue<FriendDetailState> async) {
    return async.maybeWhen(
      data: (state) {
        switch (state) {
          case FriendDetailStateEmpty():
            return state.header.displayName;
          case FriendDetailStatePopulated():
            return state.header.displayName;
        }
      },
      orElse: () => 'Friend',
    );
  }

  void _logViewedOnce(FriendDetailState state) {
    if (_loggedView) return;
    _loggedView = true;
    final balanceState = switch (state) {
      FriendDetailStateEmpty(:final header) => header.balanceState,
      FriendDetailStatePopulated(:final header) => header.balanceState,
    };
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'friend_detail_viewed',
            parameters: {
              'friendship_id_hash': hashFriendshipId(widget.friendshipId),
              'balance_state': _balanceStateLabel(balanceState),
            },
          ),
    );
  }

  String _balanceStateLabel(BalanceState s) {
    switch (s) {
      case BalanceState.owed:
        return 'owed';
      case BalanceState.owes:
        return 'owes';
      case BalanceState.settled:
        return 'settled';
    }
  }

  Future<void> _openAddExpenseSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => AddExpenseBottomSheet(
        friendshipId: widget.friendshipId,
        currentUserUid: widget.currentUserUid,
        otherUserUid: widget.otherUserUid,
      ),
    );
  }

  Future<void> _onSettleUpTapped(
    BuildContext context,
    FriendDetailStatePopulated state,
  ) async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: SettleUpTelemetry.settleUpTapped,
            parameters: <String, Object>{
              SettleUpTelemetry.paramSource: 'friend_detail',
              SettleUpTelemetry.paramFriendshipIdHash: hashFriendshipId(
                widget.friendshipId,
              ),
            },
          ),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => SettleUpBottomSheet(
        friendshipId: widget.friendshipId,
        currentUserUid: widget.currentUserUid,
        otherUserUid: widget.otherUserUid,
        otherDisplayName: state.header.displayName,
        otherUserPhotoUrl: state.header.photoUrl,
        suggestedAmountPaise: state.header.netBalancePaise.abs(),
      ),
    );
  }
}
