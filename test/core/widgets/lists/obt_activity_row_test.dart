// OBTActivityRow widget tests (FR-AC-01, components.md section 14).
//
// Covers all four event types shipped in PR #52 (expenseAdded,
// expenseEdited, expenseDeleted, settlementRecorded) across:
//   - icon rendering per the SCR-25 Event Type Mapping table
//   - primary text derivation with the other-party display name
//   - settlement directional copy ("You settled up with X" vs
//     "X settled up with you")
//   - trailing amount via formatInrFromPaise (no inline /100)
//   - semantic label format
//   - onTap callback firing

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/widgets/lists/obt_activity_row.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';

ActivityFeedItem _expenseItem({
  required String id,
  required ActivityEventType type,
  int amountPaise = 12345,
  String authorUid = 'uidA',
  String description = 'Dinner',
}) {
  return ActivityFeedItem(
    id: id,
    type: type,
    payload: <String, dynamic>{
      'expenseId': 'exp-1',
      'friendshipId': 'uidA_uidB',
      'description': description,
      'amountPaise': amountPaise,
      'category': 'food',
      'payerId': authorUid,
      'authorUid': authorUid,
      'splits': const <Map<String, dynamic>>[],
      'splitMethod': 'equal',
      'hasReceipt': false,
    },
    createdAt: DateTime.utc(2026, 6, 8, 12),
  );
}

ActivityFeedItem _settlementItem({
  required String id,
  required String fromUid,
  required String toUid,
  int amountPaise = 5000,
}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.settlementRecorded,
    payload: <String, dynamic>{
      'settlementId': 'set-1',
      'fromUserId': fromUid,
      'toUserId': toUid,
      'amountPaise': amountPaise,
      'contextType': 'friendship',
      'contextId': 'uidA_uidB',
      'authorUid': fromUid,
    },
    createdAt: DateTime.utc(2026, 6, 8, 12),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: ListView(children: [child])));
}

void main() {
  group('OBTActivityRow — icon and colour per event type', () {
    testWidgets('expenseAdded renders receipt_long icon', (tester) async {
      final item = _expenseItem(id: '1', type: ActivityEventType.expenseAdded);
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });

    testWidgets('expenseEdited renders edit icon', (tester) async {
      final item = _expenseItem(id: '1', type: ActivityEventType.expenseEdited);
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('expenseDeleted renders delete icon', (tester) async {
      final item = _expenseItem(
        id: '1',
        type: ActivityEventType.expenseDeleted,
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('settlementRecorded renders check_circle icon', (tester) async {
      final item = _settlementItem(
        id: '1',
        fromUid: 'uidA',
        toUid: 'uidB',
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Rahul',
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('OBTActivityRow — primary text derivation', () {
    testWidgets('expense_added by other party: "Priya added Dinner"', (
      tester,
    ) async {
      final item = _expenseItem(
        id: '1',
        type: ActivityEventType.expenseAdded,
        authorUid: 'uidB',
        description: 'Dinner',
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('Priya'), findsOneWidget);
      expect(find.textContaining('Dinner'), findsOneWidget);
    });

    testWidgets('expense_added by current user: "You added Dinner"', (
      tester,
    ) async {
      final item = _expenseItem(
        id: '1',
        type: ActivityEventType.expenseAdded,
        authorUid: 'uidA',
        description: 'Dinner',
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('You'), findsOneWidget);
      expect(find.textContaining('Dinner'), findsOneWidget);
    });

    testWidgets('settlement by current user: "You settled up with Rahul"', (
      tester,
    ) async {
      final item = _settlementItem(
        id: '1',
        fromUid: 'uidA',
        toUid: 'uidB',
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Rahul',
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('You settled up with Rahul'), findsOneWidget);
    });

    testWidgets('settlement to current user: "Rahul settled up with you"', (
      tester,
    ) async {
      final item = _settlementItem(
        id: '1',
        fromUid: 'uidB',
        toUid: 'uidA',
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Rahul',
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('Rahul settled up with you'), findsOneWidget);
    });
  });

  group('OBTActivityRow — trailing amount via formatInrFromPaise', () {
    testWidgets('renders the formatted INR amount', (tester) async {
      final item = _expenseItem(
        id: '1',
        type: ActivityEventType.expenseAdded,
        amountPaise: 100000,
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );
      expect(find.text(formatInrFromPaise(100000)), findsOneWidget);
    });

    testWidgets('settlement amount uses formatInrFromPaise', (tester) async {
      final item = _settlementItem(
        id: '1',
        fromUid: 'uidA',
        toUid: 'uidB',
        amountPaise: 5000,
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Rahul',
            onTap: () {},
          ),
        ),
      );
      expect(find.text(formatInrFromPaise(5000)), findsOneWidget);
    });
  });

  group('OBTActivityRow — onTap fires', () {
    testWidgets('tapping the row fires the onTap callback', (tester) async {
      var tapped = 0;
      final item = _expenseItem(
        id: '1',
        type: ActivityEventType.expenseAdded,
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () => tapped++,
          ),
        ),
      );
      await tester.tap(find.byType(OBTActivityRow));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('OBTActivityRow — accessibility', () {
    testWidgets('exposes a semantic label including primary + secondary text', (
      tester,
    ) async {
      final item = _expenseItem(
        id: '1',
        type: ActivityEventType.expenseAdded,
        amountPaise: 100000,
        description: 'Dinner',
        authorUid: 'uidB',
      );
      await tester.pumpWidget(
        _wrap(
          OBTActivityRow(
            item: item,
            currentUserUid: 'uidA',
            otherPartyDisplayName: 'Priya',
            onTap: () {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(OBTActivityRow));
      // The label combines primary + secondary + amount + tap hint
      // per SCR-25 line 361. Concretely: contains primary, the amount,
      // and "Tap to view details.".
      expect(semantics.label, contains('Priya'));
      expect(semantics.label, contains('Dinner'));
      expect(semantics.label, contains('Tap to view details'));
    });
  });
}
