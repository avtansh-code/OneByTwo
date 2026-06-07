// Tap-on-expense timeline test (FR-EX-06).
//
// Verifies that tapping an expense row in the FriendDetailTimelineWidget
// pushes an ExpenseDetailScreen via Navigator.push, threading the
// friendship + expense IDs.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/application/expense_detail_provider.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_timeline.dart';

const _friendshipId = 'fid-abc_xyz';
const _expenseId = 'eid-row-1';
const _currentUid = 'uid-current';
const _friendUid = 'uid-friend';

ExpenseDoc _buildExpense({String? id = _expenseId}) {
  return ExpenseDoc(
    id: id,
    amountPaise: 30000,
    description: 'Movie night',
    category: ExpenseCategory.entertainment,
    date: DateTime(2025, 7, 4),
    payerId: _currentUid,
    splits: const [
      Split(userId: _currentUid, sharePaise: 15000),
      Split(userId: _friendUid, sharePaise: 15000),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: _currentUid,
  );
}

Widget _buildHost(List<FriendDetailTimelineEvent> events) {
  return ProviderScope(
    overrides: [
      // Stub the detail provider so the pushed screen doesn't try to
      // hit Firebase from the test environment.
      expenseDetailProvider.overrideWith((ref, args) async => null),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: FriendDetailTimelineWidget(
          timeline: events,
          friendshipId: _friendshipId,
          currentUserUid: _currentUid,
          otherUserUid: _friendUid,
          friendDisplayName: 'Priya Lakshmi',
        ),
      ),
    ),
  );
}

void main() {
  group('FriendDetailTimelineWidget — tap-on-expense', () {
    testWidgets(
      'tapping an expense row pushes ExpenseDetailScreen with the right ids',
      (tester) async {
        await tester.pumpWidget(
          _buildHost([TimelineExpense(doc: _buildExpense())]),
        );
        await tester.pumpAndSettle();

        // Tap the expense row's description label.
        await tester.tap(find.text('Movie night'));
        await tester.pumpAndSettle();

        // The screen pushed should be an ExpenseDetailScreen with our ids.
        final screen = tester.widget<ExpenseDetailScreen>(
          find.byType(ExpenseDetailScreen),
        );
        expect(screen.friendshipId, _friendshipId);
        expect(screen.expenseId, _expenseId);
        expect(screen.currentUserUid, _currentUid);
        expect(screen.otherUserUid, _friendUid);
      },
    );

    testWidgets('an expense row with null id is not tappable (defensive)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost([TimelineExpense(doc: _buildExpense(id: null))]),
      );
      await tester.pumpAndSettle();

      // Tapping should not navigate.
      await tester.tap(find.text('Movie night'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseDetailScreen), findsNothing);
    });
  });
}
