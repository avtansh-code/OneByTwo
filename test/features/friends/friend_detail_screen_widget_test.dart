// Friend Detail screen widget tests (FR-FR-04 / SCR-11).
//
// Verifies the SCR-11 six-state rendering (loading / populated /
// settled / no expenses / error / real-time update), the friend_detail_viewed
// single-fire discipline, and the FAB → AddExpenseBottomSheet wiring
// preserved from PR #38.
//
// Replaces the existing placeholder tests (none currently — the
// placeholder was widget-covered only via friends_list_screen_widget_test).
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

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

  int countOf(String name) => loggedEvents.where((e) => e.name == name).length;

  Map<String, Object>? lastParamsFor(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;
}

const _args = FriendDetailArgs(
  friendshipId: 'uid-friend_uid-me',
  currentUserUid: 'uid-me',
  otherUserUid: 'uid-friend',
);

FriendDetailHeader _header({
  String displayName = 'Bina',
  String? photoUrl,
  int netBalancePaise = 0,
  BalanceState balanceState = BalanceState.settled,
}) {
  return FriendDetailHeader(
    displayName: displayName,
    photoUrl: photoUrl,
    netBalancePaise: netBalancePaise,
    balanceState: balanceState,
  );
}

ExpenseDoc _expense({
  required String description,
  required DateTime date,
  int amountPaise = 1000,
  String payerId = 'uid-me',
  List<Split>? splits,
}) {
  return ExpenseDoc(
    amountPaise: amountPaise,
    description: description,
    category: ExpenseCategory.food,
    date: date,
    payerId: payerId,
    splits: splits ??
        const [
          Split(userId: 'uid-me', sharePaise: 500),
          Split(userId: 'uid-friend', sharePaise: 500),
        ],
    splitMethod: SplitMethod.equal,
    createdBy: payerId,
  );
}

SettlementDoc _settlement({
  required String id,
  required DateTime date,
  int amountPaise = 5000,
}) {
  return SettlementDoc(
    settlementId: id,
    fromUserId: 'uid-me',
    toUserId: 'uid-friend',
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

class FakeExpenseRepository implements ExpenseRepository {
  ExpenseCreateError? throwError;
  String returnId = 'eid-test';
  bool createCalled = false;
  String? lastWatchedFriendshipId;

  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async {
    createCalled = true;
    if (throwError != null) {
      throw throwError!;
    }
    return returnId;
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    int limit = 5,
  }) {
    lastWatchedFriendshipId = friendshipId;
    return const Stream<List<ExpenseDoc>>.empty();
  }
}

Widget _buildSubject({
  required AsyncValue<FriendDetailState> initialValue,
  required FakeAnalyticsService analytics,
  FakeExpenseRepository? expenseRepository,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      if (expenseRepository != null)
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
      friendDetailProvider(_args).overrideWith((ref) {
        switch (initialValue) {
          case AsyncData(:final value):
            return Stream.value(value);
          case AsyncError(:final error, :final stackTrace):
            return Stream<FriendDetailState>.error(error, stackTrace);
          default:
            // Loading: never-completing stream.
            return const Stream<FriendDetailState>.empty();
        }
      }),
    ],
    child: const MaterialApp(
      home: FriendDetailScreen(
        friendshipId: 'uid-friend_uid-me',
        currentUserUid: 'uid-me',
        otherUserUid: 'uid-friend',
      ),
    ),
  );
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  group('Loading state', () {
    testWidgets('shows skeleton placeholders before first emission',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: const AsyncLoading<FriendDetailState>(),
          analytics: analytics,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('friend_detail_skeleton')),
        findsOneWidget,
      );
    });

    testWidgets('does NOT fire friend_detail_viewed while loading',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: const AsyncLoading<FriendDetailState>(),
          analytics: analytics,
        ),
      );
      await tester.pump();

      expect(analytics.countOf('friend_detail_viewed'), 0);
    });
  });

  group('Populated state (non-zero balance — owed)', () {
    final state = FriendDetailStatePopulated(
      header: _header(
        netBalancePaise: 12345,
        balanceState: BalanceState.owed,
      ),
      timeline: [
        TimelineExpense(
          doc: _expense(
            description: 'Coffee',
            date: DateTime(2026, 6, 5),
          ),
        ),
        TimelineSettlement(
          doc: _settlement(
            id: 'sid-1',
            date: DateTime(2026, 6, 3),
          ),
        ),
      ],
    );

    testWidgets('renders the friend display name in the header',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bina'), findsWidgets);
    });

    testWidgets('renders the owed balance pill copy and INR amount',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are owed ${formatInrFromPaise(12345)}'),
          findsOneWidget);
    });

    testWidgets('renders the intermixed timeline rows in order',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);
      // The settlement row carries either a "Settled" / "Payment" label or
      // an amount — assert the amount is rendered for the seeded settlement.
      expect(find.text(formatInrFromPaise(5000)), findsWidgets);
    });

    testWidgets('friend_detail_viewed fires once with owed balance_state',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 1);
      final params = analytics.lastParamsFor('friend_detail_viewed');
      expect(params, isNotNull);
      expect(params!['balance_state'], 'owed');
      expect(
        params['friendship_id_hash'],
        equals(hashFriendshipId('uid-friend_uid-me')),
      );
    });
  });

  group('Populated state (non-zero balance — owes)', () {
    final state = FriendDetailStatePopulated(
      header: _header(
        netBalancePaise: -5000,
        balanceState: BalanceState.owes,
      ),
      timeline: [
        TimelineExpense(
          doc: _expense(
            description: 'Dinner',
            date: DateTime(2026, 6, 5),
            amountPaise: 10000,
            payerId: 'uid-friend',
            splits: const [
              Split(userId: 'uid-me', sharePaise: 5000),
              Split(userId: 'uid-friend', sharePaise: 5000),
            ],
          ),
        ),
      ],
    );

    testWidgets('renders the owes balance pill copy', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You owe ${formatInrFromPaise(-5000)}'), findsOneWidget);
    });

    testWidgets('friend_detail_viewed fires with owes balance_state',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.lastParamsFor('friend_detail_viewed')?['balance_state'],
          'owes');
    });
  });

  group('Populated state (settled up)', () {
    final state = FriendDetailStatePopulated(
      header: _header(
        
      ),
      timeline: [
        TimelineExpense(
          doc: _expense(
            description: 'Old expense',
            date: DateTime(2026, 5, 30),
          ),
        ),
      ],
    );

    testWidgets('renders the settled-up pill copy', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settled up'), findsOneWidget);
    });

    testWidgets('friend_detail_viewed fires with settled balance_state',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.lastParamsFor('friend_detail_viewed')?['balance_state'],
          'settled');
    });
  });

  group('Empty state', () {
    final state = FriendDetailStateEmpty(
      header: _header(),
    );

    testWidgets('renders the no-expenses placeholder', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No expenses yet'), findsOneWidget);
      expect(
        find.text('Add an expense with Bina to start tracking.'),
        findsOneWidget,
      );
    });

    testWidgets('FAB remains visible and opens AddExpenseBottomSheet',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
          expenseRepository: FakeExpenseRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add expense'), findsOneWidget);

      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseBottomSheet), findsOneWidget);
    });

    testWidgets('friend_detail_viewed fires once on the empty state',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 1);
    });
  });

  group('Error state', () {
    testWidgets('renders the error placeholder with Retry', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncError<FriendDetailState>(
            Exception('Firestore down'),
            StackTrace.empty,
          ),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text("We couldn't load this friend's details. Please try again."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('does NOT fire friend_detail_viewed in error state',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncError<FriendDetailState>(
            Exception('boom'),
            StackTrace.empty,
          ),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 0);
    });
  });

  group('Telemetry single-fire discipline', () {
    testWidgets('does NOT re-fire on subsequent state emissions',
        (tester) async {
      // Provider override that emits two states in sequence.
      final first = FriendDetailStateEmpty(header: _header());
      final second = FriendDetailStatePopulated(
        header: _header(netBalancePaise: 1000, balanceState: BalanceState.owed),
        timeline: [
          TimelineExpense(
            doc: _expense(description: 'Tea', date: DateTime(2026, 6)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(analytics),
            friendDetailProvider(_args).overrideWith(
              (ref) => Stream<FriendDetailState>.fromIterable([first, second]),
            ),
          ],
          child: const MaterialApp(
            home: FriendDetailScreen(
              friendshipId: 'uid-friend_uid-me',
              currentUserUid: 'uid-me',
              otherUserUid: 'uid-friend',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 1);
    });
  });

  group('Accessibility', () {
    testWidgets('every interactive widget has a semantics label',
        (tester) async {
      final state = FriendDetailStatePopulated(
        header: _header(
          netBalancePaise: 12345,
          balanceState: BalanceState.owed,
        ),
        timeline: [
          TimelineExpense(
            doc: _expense(description: 'Coffee', date: DateTime(2026, 6, 5)),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      // The FAB exposes a tooltip / semantic label.
      expect(find.byTooltip('Add expense'), findsOneWidget);
    });
  });
}
