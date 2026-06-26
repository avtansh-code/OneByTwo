// Friend History PII-leak test (FR-FR-04 / Haldi 12; DC-06).
//
// The net-new Friend History screen is a pure read-only projection and
// introduces NO telemetry. This test pins that contract: pumped with
// PII-laden friend + transaction data, it must log ZERO analytics events,
// so no raw UID, display-name fragment, or photo URL can ever reach
// telemetry. Mirrors friend_detail_pii_leak_test.dart.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friend_history_provider.dart';
import 'package:onebytwo/features/friends/presentation/friend_history_screen.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

const _piiStrings = [
  'uid-priyalakshmi_uid-rahulagarwal',
  'uid-priyalakshmi',
  'uid-rahulagarwal',
  'Priya',
  'Lakshmi',
  'Rahul',
  'Agarwal',
];

class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  bool containsPii(String pii) {
    for (final event in loggedEvents) {
      if (event.name.contains(pii)) return true;
      if (event.parameters != null) {
        for (final value in event.parameters!.values) {
          if (value.toString().contains(pii)) return true;
        }
      }
    }
    return false;
  }
}

List<FriendDetailTimelineEvent> _events() {
  return <FriendDetailTimelineEvent>[
    TimelineExpense(
      doc: ExpenseDoc(
        amountPaise: 200000,
        description: 'Dinner with Rahul Agarwal',
        category: ExpenseCategory.food,
        date: DateTime(2026, 6, 22),
        payerId: 'uid-priyalakshmi',
        splits: const [
          Split(userId: 'uid-priyalakshmi', sharePaise: 100000),
          Split(userId: 'uid-rahulagarwal', sharePaise: 100000),
        ],
        splitMethod: SplitMethod.equal,
        createdBy: 'uid-priyalakshmi',
      ),
    ),
    TimelineSettlement(
      doc: SettlementDoc(
        settlementId: 'sid-1',
        fromUserId: 'uid-rahulagarwal',
        toUserId: 'uid-priyalakshmi',
        amountPaise: 50000,
        contextType: 'friendship',
        contextId: 'uid-priyalakshmi_uid-rahulagarwal',
        date: DateTime(2026, 6, 12),
        note: null,
        method: 'manual',
        verificationStatus: 'unverified',
        currency: 'INR',
        createdAt: DateTime(2026, 6, 12),
        deleted: false,
      ),
    ),
  ];
}

void main() {
  testWidgets('Friend History logs no analytics events (no PII can leak)', (
    tester,
  ) async {
    final analytics = FakeAnalyticsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(analytics),
          friendHistoryProvider.overrideWith(
            (ref, args) => Stream.value(_events()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FriendHistoryScreen(
            friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
            currentUserUid: 'uid-priyalakshmi',
            otherUserUid: 'uid-rahulagarwal',
            friendDisplayName: 'Rahul Agarwal',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The read-only history screen emits no telemetry at all.
    expect(analytics.loggedEvents, isEmpty);
    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'PII "$pii" must never reach telemetry from Friend History',
      );
    }
  });
}
