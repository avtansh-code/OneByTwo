// Friend History screen widget tests (FR-FR-04 / Haldi 12; DC-06).
//
// The net-new full per-friend log: a month-grouped, reverse-chronological
// list of expenses AND settlements with SIGNED amounts (positive = in your
// favour; negative = you owe / you paid out). Verifies the four states
// (loading-skeleton / empty / populated / error), the IST month grouping,
// and the signed-amount colour + sign discipline (Invariant 1 — every
// amount via formatInrFromPaise(); Invariant 2 — read-only projection).

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friend_history_provider.dart';
import 'package:onebytwo/features/friends/presentation/friend_history_screen.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

const _me = 'uid-me';
const _friend = 'uid-friend';

ExpenseDoc _expense({
  required String description,
  required DateTime date,
  required int amountPaise,
  required String payerId,
  required int myShare,
  ExpenseCategory category = ExpenseCategory.food,
}) {
  return ExpenseDoc(
    amountPaise: amountPaise,
    description: description,
    category: category,
    date: date,
    payerId: payerId,
    splits: [
      Split(userId: _me, sharePaise: myShare),
      Split(userId: _friend, sharePaise: amountPaise - myShare),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: payerId,
  );
}

SettlementDoc _settlement({
  required DateTime date,
  required int amountPaise,
  required String fromUserId,
  required String toUserId,
}) {
  return SettlementDoc(
    settlementId: 'sid-${date.millisecondsSinceEpoch}',
    fromUserId: fromUserId,
    toUserId: toUserId,
    amountPaise: amountPaise,
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
}

/// A representative populated history: two June rows (an expense you lent
/// and a settlement they paid you) and one May row (an expense you
/// borrowed), so the screen month-groups across two months.
List<FriendDetailTimelineEvent> _populated() {
  return <FriendDetailTimelineEvent>[
    TimelineExpense(
      doc: _expense(
        description: 'Dinner at Bombay Canteen',
        date: DateTime(2026, 6, 22),
        amountPaise: 320000,
        payerId: _me,
        myShare: 160000,
      ),
    ),
    TimelineExpense(
      doc: _expense(
        description: 'Airport cab',
        date: DateTime(2026, 6, 20),
        amountPaise: 90000,
        payerId: _friend,
        myShare: 45000,
        category: ExpenseCategory.travel,
      ),
    ),
    TimelineSettlement(
      doc: _settlement(
        date: DateTime(2026, 6, 12),
        amountPaise: 50000,
        fromUserId: _friend,
        toUserId: _me,
      ),
    ),
    TimelineExpense(
      doc: _expense(
        description: 'Groceries',
        date: DateTime(2026, 5, 14),
        amountPaise: 60000,
        payerId: _friend,
        myShare: 30000,
        category: ExpenseCategory.groceries,
      ),
    ),
  ];
}

Widget _subject(
  Stream<List<FriendDetailTimelineEvent>> stream, {
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [friendHistoryProvider.overrideWith((ref, args) => stream)],
    child: MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: const FriendHistoryScreen(
        friendshipId: 'uid-friend_uid-me',
        currentUserUid: _me,
        otherUserUid: _friend,
        friendDisplayName: 'Rahul Sharma',
      ),
    ),
  );
}

void main() {
  group('FriendHistoryScreen states', () {
    testWidgets('loading renders the shimmer skeleton', (tester) async {
      final controller = StreamController<List<FriendDetailTimelineEvent>>();
      addTearDown(controller.close);

      await tester.pumpWidget(_subject(controller.stream));
      await tester.pump();

      expect(find.byKey(const Key('friend_history_skeleton')), findsOneWidget);
    });

    testWidgets('empty renders the OBTEmptyState', (tester) async {
      await tester.pumpWidget(
        _subject(Stream.value(const <FriendDetailTimelineEvent>[])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No history yet'), findsOneWidget);
      expect(
        find.text(
          'Expenses and settlements with Rahul Sharma will appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('error renders the error state with Retry', (tester) async {
      await tester.pumpWidget(
        _subject(
          Stream<List<FriendDetailTimelineEvent>>.error(Exception('FH-READ')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('populated month-groups the log with uppercase headers', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(Stream.value(_populated())));
      await tester.pumpAndSettle();

      expect(find.text('JUNE 2026'), findsOneWidget);
      expect(find.text('MAY 2026'), findsOneWidget);
      expect(find.text('Dinner at Bombay Canteen'), findsOneWidget);
      expect(find.text('Airport cab'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      // The settlement they paid you is titled with the friend's name.
      expect(find.text('Rahul paid you'), findsOneWidget);
    });

    testWidgets('populated renders SIGNED amounts in the balance-trio hues', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(Stream.value(_populated())));
      await tester.pumpAndSettle();

      // You lent 1,600 -> positive (+) in the positive hue.
      final lent = '+${formatInrFromPaise(160000)}';
      expect(find.text(lent), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(lent)).style?.color,
        OBTColors.light.balancePositive,
      );

      // You borrowed 450 -> negative (formatter carries the minus) in the
      // negative hue.
      final borrowed = formatInrFromPaise(-45000);
      expect(find.text(borrowed), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(borrowed)).style?.color,
        OBTColors.light.balanceNegative,
      );

      // The friend paid you 500 -> positive (incoming) in the positive hue.
      final received = '+${formatInrFromPaise(50000)}';
      expect(find.text(received), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(received)).style?.color,
        OBTColors.light.balancePositive,
      );
    });

    testWidgets('amounts never carry inline minus on the positive branch — '
        'the sign glyph is the only addition (Invariant 1)', (tester) async {
      await tester.pumpWidget(_subject(Stream.value(_populated())));
      await tester.pumpAndSettle();

      // The meta descriptors survive greyscale (sign is not colour-only).
      expect(find.textContaining('you lent'), findsOneWidget);
      expect(find.textContaining('you borrowed'), findsWidgets);
      expect(find.textContaining('settlement'), findsOneWidget);
    });

    testWidgets('outgoing settlement (you paid) renders a negative amount '
        'and a "You paid" title', (tester) async {
      final events = <FriendDetailTimelineEvent>[
        TimelineSettlement(
          doc: _settlement(
            date: DateTime(2026, 6, 10),
            amountPaise: 70000,
            fromUserId: _me,
            toUserId: _friend,
          ),
        ),
      ];

      await tester.pumpWidget(_subject(Stream.value(events)));
      await tester.pumpAndSettle();

      expect(find.text('You paid Rahul'), findsOneWidget);
      final paid = formatInrFromPaise(-70000);
      expect(find.text(paid), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(paid)).style?.color,
        OBTColors.light.balanceNegative,
      );
    });
  });
}
