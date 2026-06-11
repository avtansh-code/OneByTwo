import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/widgets/nav/obt_floating_action_button.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_header.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_states.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_timeline.dart';
import 'package:onebytwo/features/friends/presentation/widgets/obt_settle_up_card.dart';
import 'package:onebytwo/features/reminders/application/reminder_cooldown_provider.dart';
import 'package:onebytwo/features/reminders/application/send_reminder_controller.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_error.dart';
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
                      )
                    else if (state.header.balanceState == BalanceState.owed)
                      _ReceivingDirectionCard(
                        friendshipId: widget.friendshipId,
                        otherDisplayName: state.header.displayName,
                        otherPhotoUrl: state.header.photoUrl,
                        suggestedAmountPaise: state.header.netBalancePaise
                            .abs(),
                        otherUserUid: widget.otherUserUid,
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
      floatingActionButton: OBTFloatingActionButton(
        heroTag: 'friendDetailFab',
        onPressed: () => _openAddExpenseSheet(context),
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

/// FR-SE-09 receiving-direction host for the OBTSettleUpCard.
///
/// Owns its own [ConsumerState] so it can watch the per-friendship
/// `reminderCooldownProvider` (which drives the live disabled state +
/// countdown caption) AND listen for [SendReminderController] state
/// transitions to surface per-error-code snackbars without leaking
/// into the parent [FriendDetailScreen].
class _ReceivingDirectionCard extends ConsumerStatefulWidget {
  const _ReceivingDirectionCard({
    required this.friendshipId,
    required this.otherDisplayName,
    required this.otherPhotoUrl,
    required this.suggestedAmountPaise,
    required this.otherUserUid,
  });

  final String friendshipId;
  final String otherDisplayName;
  final String? otherPhotoUrl;
  final int suggestedAmountPaise;
  final String otherUserUid;

  @override
  ConsumerState<_ReceivingDirectionCard> createState() =>
      _ReceivingDirectionCardState();
}

class _ReceivingDirectionCardState
    extends ConsumerState<_ReceivingDirectionCard> {
  @override
  Widget build(BuildContext context) {
    final cooldown = ref.watch(reminderCooldownProvider(widget.friendshipId));

    ref.listen<SendReminderState>(
      sendReminderControllerProvider(widget.friendshipId),
      (previous, next) {
        if (!mounted) return;
        if (next is SendReminderError) {
          _surfaceErrorSnackbar(context, next.error);
        }
      },
    );

    return OBTSettleUpCard(
      payerDisplayName: widget.otherDisplayName,
      payerPhotoUrl: widget.otherPhotoUrl,
      payeeDisplayName: 'You',
      payeePhotoUrl: null,
      suggestedAmountPaise: widget.suggestedAmountPaise,
      onSettleUp: () {},
      isReceivingDirection: true,
      nextAllowedAt: cooldown,
      onSendReminder: () => _onSendReminderTapped(context),
    );
  }

  Future<void> _onSendReminderTapped(BuildContext context) async {
    final controller = ref.read(
      sendReminderControllerProvider(widget.friendshipId).notifier,
    );
    await controller.send(
      toUserId: widget.otherUserUid,
      contextType: 'friendship',
      contextId: widget.friendshipId,
    );
  }

  void _surfaceErrorSnackbar(BuildContext context, ReminderSendResult error) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final text = switch (error) {
      ReminderSendRateLimited(:final nextAllowedAt) => _rateLimitedSnackbar(
        nextAllowedAt,
      ),
      ReminderSendRecipientPrefsDisabled() =>
        '${widget.otherDisplayName} has notifications turned off.',
      ReminderSendRecipientNoTokens() =>
        "${widget.otherDisplayName} hasn't enabled push notifications yet.",
      ReminderSendRecipientDoesntOwe() =>
        "${widget.otherDisplayName}'s balance has changed. Pull to refresh.",
      ReminderSendFailed() => 'Reminder could not be sent. Please try again.',
      ReminderSendSuccess() => null,
    };

    if (text == null) return;
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  String _rateLimitedSnackbar(DateTime nextAllowedAt) {
    final remaining = nextAllowedAt.difference(DateTime.now());
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final hm = h > 0 ? '${h}h ${m}m' : '${m.clamp(1, 59)}m';
    return 'You can send another reminder to '
        '${widget.otherDisplayName} in $hm.';
  }
}
