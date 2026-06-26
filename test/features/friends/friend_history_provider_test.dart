// friendHistoryStream join-logic unit tests (FR-FR-04 / Haldi 12; DC-06).
//
// Exercises the read-only fold of the expense + settlement streams into a
// single reverse-chronological FriendDetailTimelineEvent list directly (the
// widget tests override the provider, so this is the only coverage of the
// join, the "wait for both" gate, and the error propagation).

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friend_history_provider.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

ExpenseDoc _expense(DateTime date) => ExpenseDoc(
  amountPaise: 10000,
  description: 'e ${date.day}',
  category: ExpenseCategory.food,
  date: date,
  payerId: 'uid-me',
  splits: const [
    Split(userId: 'uid-me', sharePaise: 5000),
    Split(userId: 'uid-friend', sharePaise: 5000),
  ],
  splitMethod: SplitMethod.equal,
  createdBy: 'uid-me',
);

SettlementDoc _settlement(DateTime date) => SettlementDoc(
  settlementId: 's${date.day}',
  fromUserId: 'uid-friend',
  toUserId: 'uid-me',
  amountPaise: 5000,
  contextType: 'friendship',
  contextId: 'uid-friend_uid-me',
  date: date,
  note: null,
  method: 'manual',
  verificationStatus: 'unverified',
  currency: 'INR',
  createdAt: date,
  deleted: false,
);

void main() {
  group('friendHistoryStream', () {
    test('waits for both streams, then emits the combined reverse-chron '
        'list (no top-5 cap)', () async {
      final expenses = StreamController<List<ExpenseDoc>>();
      final settlements = StreamController<List<SettlementDoc>>();
      addTearDown(expenses.close);
      addTearDown(settlements.close);

      final emissions = <List<FriendDetailTimelineEvent>>[];
      final sub = friendHistoryStream(
        expenseStream: expenses.stream,
        settlementStream: settlements.stream,
      ).listen(emissions.add);
      addTearDown(sub.cancel);

      // Only the expense stream has emitted — nothing yet (waits for both).
      expenses.add(<ExpenseDoc>[
        _expense(DateTime(2026, 6, 5)),
        _expense(DateTime(2026, 6, 20)),
        _expense(DateTime(2026, 5)),
        _expense(DateTime(2026, 4)),
        _expense(DateTime(2026, 3)),
        _expense(DateTime(2026, 2)),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, isEmpty);

      settlements.add(<SettlementDoc>[_settlement(DateTime(2026, 6, 10))]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      final events = emissions.single;
      // Six expenses + one settlement, uncapped (the top-5 cap is the
      // Friend Detail timeline's, not the history's).
      expect(events, hasLength(7));
      // Reverse chronological by timestamp.
      expect(events.first.timelineTimestamp, DateTime(2026, 6, 20));
      expect(events[1].timelineTimestamp, DateTime(2026, 6, 10));
      expect(events.last.timelineTimestamp, DateTime(2026, 2));
    });

    test('propagates an expense-stream error', () async {
      final expenses = StreamController<List<ExpenseDoc>>();
      final settlements = StreamController<List<SettlementDoc>>();
      addTearDown(expenses.close);
      addTearDown(settlements.close);

      Object? error;
      final sub = friendHistoryStream(
        expenseStream: expenses.stream,
        settlementStream: settlements.stream,
      ).listen((_) {}, onError: (Object e, StackTrace _) => error = e);
      addTearDown(sub.cancel);

      expenses.addError(Exception('expense-read'));
      await Future<void>.delayed(Duration.zero);

      expect(error, isA<Exception>());
    });

    test('propagates a settlement-stream error', () async {
      final expenses = StreamController<List<ExpenseDoc>>();
      final settlements = StreamController<List<SettlementDoc>>();
      addTearDown(expenses.close);
      addTearDown(settlements.close);

      Object? error;
      final sub = friendHistoryStream(
        expenseStream: expenses.stream,
        settlementStream: settlements.stream,
      ).listen((_) {}, onError: (Object e, StackTrace _) => error = e);
      addTearDown(sub.cancel);

      settlements.addError(Exception('settlement-read'));
      await Future<void>.delayed(Duration.zero);

      expect(error, isA<Exception>());
    });
  });
}
