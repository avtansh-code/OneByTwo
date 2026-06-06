import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/balances/net_balance.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Family argument tuple identifying a single Friend Detail screen
/// instance. Three-field constructor matches the call site preserved
/// from PR #38 (the FAB in the placeholder screen).
@immutable
class FriendDetailArgs {
  /// Creates a [FriendDetailArgs].
  const FriendDetailArgs({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendDetailArgs &&
        other.friendshipId == friendshipId &&
        other.currentUserUid == currentUserUid &&
        other.otherUserUid == otherUserUid;
  }

  @override
  int get hashCode => Object.hash(friendshipId, currentUserUid, otherUserUid);
}

/// Balance-direction discriminator surfaced by [FriendDetailHeader].
/// The telemetry event `friend_detail_viewed` carries the snake-case
/// name (`owed`, `owes`, `settled`) as the `balance_state` parameter.
enum BalanceState {
  /// The other user owes the current user (positive net balance).
  owed,

  /// The current user owes the other user (negative net balance).
  owes,

  /// Settled up (zero net balance).
  settled,
}

/// Header projection rendered above the timeline.
@immutable
class FriendDetailHeader {
  /// Creates a [FriendDetailHeader].
  const FriendDetailHeader({
    required this.displayName,
    required this.photoUrl,
    required this.netBalancePaise,
    required this.balanceState,
  });

  /// Resolved friend display name (or `'Unknown'` if the profile
  /// lookup returned null).
  final String displayName;

  /// Friend's avatar URL, if any.
  final String? photoUrl;

  /// Signed net balance in paise from the current user's perspective
  /// (positive ⇒ the other user owes me; negative ⇒ I owe the other
  /// user; zero ⇒ settled up). Always int (Invariant 1).
  final int netBalancePaise;

  /// Convenience discriminator derived from [netBalancePaise].
  final BalanceState balanceState;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendDetailHeader &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.netBalancePaise == netBalancePaise &&
        other.balanceState == balanceState;
  }

  @override
  int get hashCode =>
      Object.hash(displayName, photoUrl, netBalancePaise, balanceState);
}

/// One event row in the intermixed Friend Detail timeline. Sealed so
/// the widget can pattern-match exhaustively.
@immutable
sealed class FriendDetailTimelineEvent {
  const FriendDetailTimelineEvent();

  /// Primary timestamp used to order the timeline.
  DateTime get timelineTimestamp;
}

/// Timeline row backed by an [ExpenseDoc].
class TimelineExpense extends FriendDetailTimelineEvent {
  /// Creates a [TimelineExpense].
  const TimelineExpense({required this.doc});

  /// The underlying expense document.
  final ExpenseDoc doc;

  @override
  DateTime get timelineTimestamp => doc.date;

  @override
  bool operator ==(Object other) {
    return other is TimelineExpense && other.doc == doc;
  }

  @override
  int get hashCode => doc.hashCode;
}

/// Timeline row backed by a [SettlementDoc].
class TimelineSettlement extends FriendDetailTimelineEvent {
  /// Creates a [TimelineSettlement].
  const TimelineSettlement({required this.doc});

  /// The underlying settlement document.
  final SettlementDoc doc;

  @override
  DateTime get timelineTimestamp => doc.date;

  @override
  bool operator ==(Object other) {
    return other is TimelineSettlement && other.doc == doc;
  }

  @override
  int get hashCode => doc.hashCode;
}

/// Discriminated union of states the Friend Detail screen can render.
@immutable
sealed class FriendDetailState {
  const FriendDetailState();
}

/// Empty state — header is resolved, but both the expense stream and
/// the settlement stream are empty.
class FriendDetailStateEmpty extends FriendDetailState {
  /// Creates a [FriendDetailStateEmpty].
  const FriendDetailStateEmpty({required this.header});

  /// The resolved header.
  final FriendDetailHeader header;

  @override
  bool operator ==(Object other) {
    return other is FriendDetailStateEmpty && other.header == header;
  }

  @override
  int get hashCode => header.hashCode;
}

/// Populated state — header + at least one timeline event.
class FriendDetailStatePopulated extends FriendDetailState {
  /// Creates a [FriendDetailStatePopulated].
  const FriendDetailStatePopulated({
    required this.header,
    required this.timeline,
  });

  /// The resolved header.
  final FriendDetailHeader header;

  /// Combined timeline ordered by `timelineTimestamp` desc, capped at
  /// 5 events.
  final List<FriendDetailTimelineEvent> timeline;
}

/// Combined provider that powers the Friend Detail screen (FR-FR-04 /
/// SCR-11).
///
/// Pipeline:
/// 1. Watch the friendship document (`watchFriendship(friendshipId)`)
///    — provides `memberIds` and `simplifiedBalances` in real-time.
///    A `null` emission ⇒ the document does not exist / inaccessible;
///    surfaced as an error.
/// 2. Resolve the other user's profile via `userProfileProvider`
///    (one-shot, cached per uid).
/// 3. Subscribe to the expense subcollection stream
///    (`watchExpensesByFriendship`) and the settlements top-level
///    stream (`watchByContext`); fold their latest emissions into a
///    single timeline ordered by `timelineTimestamp` descending,
///    capped at 5 events.
/// 4. Compute the signed integer paise via `netBalancePaise()` — the
///    same helper the friends list uses, so the friends-list chip and
///    the friend-detail header always agree.
/// 5. Yield one of `FriendDetailStateEmpty` or
///    `FriendDetailStatePopulated`. Stream errors propagate as
///    `AsyncError` to the screen.
///
/// **Invariant 2 (`simplifiedBalances` server-maintained).** This
/// provider READS `simplifiedBalances` via the shared helper; it never
/// writes the field.
final friendDetailProvider =
    StreamProvider.family<FriendDetailState, FriendDetailArgs>((ref, args) {
      final friendshipRepository = ref.watch(friendshipRepositoryProvider);
      final expenseRepository = ref.watch(expenseRepositoryProvider);
      final settlementRepository = ref.watch(settlementRepositoryProvider);

      return _friendDetailStream(
        args: args,
        friendshipStream: friendshipRepository.watchFriendship(
          args.friendshipId,
        ),
        expenseStream: expenseRepository.watchExpensesByFriendship(
          friendshipId: args.friendshipId,
        ),
        settlementStream: settlementRepository.watchByContext(
          contextType: 'friendship',
          contextId: args.friendshipId,
        ),
        profileLookup: () async {
          try {
            return await ref.read(
              userProfileProvider(args.otherUserUid).future,
            );
          } on Object {
            return null;
          }
        },
      );
    });

/// Returns the combined Friend Detail stream. Extracted to top level so
/// the unit tests can exercise the join logic without a full Riverpod
/// container if needed.
Stream<FriendDetailState> _friendDetailStream({
  required FriendDetailArgs args,
  required Stream<FriendshipDoc?> friendshipStream,
  required Stream<List<ExpenseDoc>> expenseStream,
  required Stream<List<SettlementDoc>> settlementStream,
  required Future<UserModel?> Function() profileLookup,
}) {
  // Cache the resolved profile after the first lookup; if the lookup
  // fails or returns null we fall back to "Unknown".
  UserModel? profile;
  var profileLoaded = false;

  Future<UserModel?> resolveProfile() async {
    if (profileLoaded) return profile;
    profileLoaded = true;
    return profile = await profileLookup();
  }

  final controller = StreamController<FriendDetailState>();

  FriendshipDoc? latestFriendship;
  List<ExpenseDoc>? latestExpenses;
  List<SettlementDoc>? latestSettlements;
  var emittedFirst = false;

  Future<void> emitIfReady() async {
    if (latestFriendship == null) return;
    if (latestExpenses == null) return;
    if (latestSettlements == null) return;
    if (controller.isClosed) return;

    final resolvedProfile = await resolveProfile();
    if (controller.isClosed) return;

    final netPaise = netBalancePaise(
      simplifiedBalances: latestFriendship!.simplifiedBalances,
      currentUserId: args.currentUserUid,
      otherUserId: args.otherUserUid,
    );
    final header = FriendDetailHeader(
      displayName: resolvedProfile?.displayName ?? 'Unknown',
      photoUrl: resolvedProfile?.photoUrl,
      netBalancePaise: netPaise,
      balanceState: _balanceStateOf(netPaise),
    );

    final timeline = _buildTimeline(latestExpenses!, latestSettlements!);
    final state = timeline.isEmpty
        ? FriendDetailStateEmpty(header: header)
        : FriendDetailStatePopulated(header: header, timeline: timeline);

    controller.add(state);
    emittedFirst = true;
  }

  final friendshipSub = friendshipStream.listen(
    (doc) {
      if (doc == null) {
        if (!controller.isClosed && !emittedFirst) {
          controller.addError(
            StateError(
              'friendship ${args.friendshipId}: document does not exist or '
              'is inaccessible',
            ),
          );
        }
        return;
      }
      latestFriendship = doc;
      unawaited(emitIfReady());
    },
    onError: (Object error, StackTrace _) {
      if (!controller.isClosed) controller.addError(error);
    },
  );

  final expenseSub = expenseStream.listen(
    (docs) {
      latestExpenses = docs;
      unawaited(emitIfReady());
    },
    onError: (Object error, StackTrace _) {
      if (!controller.isClosed) controller.addError(error);
    },
  );

  final settlementSub = settlementStream.listen(
    (docs) {
      latestSettlements = docs;
      unawaited(emitIfReady());
    },
    onError: (Object error, StackTrace _) {
      if (!controller.isClosed) controller.addError(error);
    },
  );

  controller.onCancel = () async {
    await friendshipSub.cancel();
    await expenseSub.cancel();
    await settlementSub.cancel();
  };

  return controller.stream;
}

List<FriendDetailTimelineEvent> _buildTimeline(
  List<ExpenseDoc> expenses,
  List<SettlementDoc> settlements,
) {
  final events = <FriendDetailTimelineEvent>[
    ...expenses.map((e) => TimelineExpense(doc: e)),
    ...settlements.map((s) => TimelineSettlement(doc: s)),
  ]..sort((a, b) => b.timelineTimestamp.compareTo(a.timelineTimestamp));
  return events.take(5).toList(growable: false);
}

BalanceState _balanceStateOf(int netPaise) {
  if (netPaise > 0) return BalanceState.owed;
  if (netPaise < 0) return BalanceState.owes;
  return BalanceState.settled;
}
