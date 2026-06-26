import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Read-only provider powering the net-new Friend History screen
/// (FR-FR-04 / Haldi 12; DC-06).
///
/// It consumes the **same** friendship expense + settlement sources the
/// Friend Detail timeline reads (`watchExpensesByFriendship` +
/// `watchByContext`), but yields the **full** reverse-chronological list of
/// [FriendDetailTimelineEvent] (no top-5 cap) so the screen can month-group
/// it. The Friend Detail timeline keeps its own capped preview.
///
/// **Invariant 1 (integer paise).** This is a pure projection of the
/// underlying `int` paise documents; it performs no rupee arithmetic.
/// **Invariant 2 (`simplifiedBalances` server-maintained).** This provider
/// READS expense + settlement documents only; it never reads, computes
/// from, or writes the `simplifiedBalances` field, and introduces no write
/// path of any kind.
final friendHistoryProvider =
    StreamProvider.family<List<FriendDetailTimelineEvent>, FriendDetailArgs>((
      ref,
      args,
    ) {
      final expenseRepository = ref.watch(expenseRepositoryProvider);
      final settlementRepository = ref.watch(settlementRepositoryProvider);

      return friendHistoryStream(
        expenseStream: expenseRepository.watchExpensesByFriendship(
          friendshipId: args.friendshipId,
        ),
        settlementStream: settlementRepository.watchByContext(
          contextType: 'friendship',
          contextId: args.friendshipId,
        ),
      );
    });

/// Folds the expense + settlement streams into a single
/// reverse-chronological [FriendDetailTimelineEvent] list. Extracted to
/// top level so the unit tests can exercise the join logic directly.
///
/// Waits for the first emission of BOTH streams before emitting, so the
/// screen never shows a premature empty state while one source is still
/// resolving.
Stream<List<FriendDetailTimelineEvent>> friendHistoryStream({
  required Stream<List<ExpenseDoc>> expenseStream,
  required Stream<List<SettlementDoc>> settlementStream,
}) {
  final controller = StreamController<List<FriendDetailTimelineEvent>>();

  List<ExpenseDoc>? latestExpenses;
  List<SettlementDoc>? latestSettlements;

  void emitIfReady() {
    if (latestExpenses == null || latestSettlements == null) return;
    if (controller.isClosed) return;
    final events = <FriendDetailTimelineEvent>[
      ...latestExpenses!.map((e) => TimelineExpense(doc: e)),
      ...latestSettlements!.map((s) => TimelineSettlement(doc: s)),
    ]..sort((a, b) => b.timelineTimestamp.compareTo(a.timelineTimestamp));
    controller.add(List<FriendDetailTimelineEvent>.unmodifiable(events));
  }

  final expenseSub = expenseStream.listen(
    (docs) {
      latestExpenses = docs;
      emitIfReady();
    },
    onError: (Object error, StackTrace _) {
      if (!controller.isClosed) controller.addError(error);
    },
  );

  final settlementSub = settlementStream.listen(
    (docs) {
      latestSettlements = docs;
      emitIfReady();
    },
    onError: (Object error, StackTrace _) {
      if (!controller.isClosed) controller.addError(error);
    },
  );

  controller.onCancel = () async {
    await expenseSub.cancel();
    await settlementSub.cancel();
  };

  return controller.stream;
}
