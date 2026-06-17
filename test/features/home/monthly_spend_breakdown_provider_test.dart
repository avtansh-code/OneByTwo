// FR-HD-03 monthlySpendBreakdownProvider fan-out tests (ADR-0017
// section 5).
//
// Exercises the provider over a recording `ExpenseStore` fake wrapped in
// a real `ExpenseRepository` (no `fake_cloud_firestore`), overriding
// `friendsListProvider` with canned items and `homeClockProvider` with a
// fixed `now` for a deterministic IST window. Asserts the per-friendship
// fan-out, the aggregate-equals-pure-reducer contract, the window passed
// to each read, and the AsyncData / AsyncError lifecycle.

// ignore_for_file: only_throw_errors

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/home/application/monthly_spend_breakdown_provider.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_aggregator.dart';

/// Recording fake `ExpenseStore`: returns canned per-friendship
/// expenses, optionally throws for a friendship, and records every
/// `fetchExpensesInMonth` call. Other store methods are unused here.
class _RecordingExpenseStore implements ExpenseStore {
  _RecordingExpenseStore({
    this.byFriendship = const {},
    this.errorFor = const {},
  });

  final Map<String, List<ExpenseDoc>> byFriendship;
  final Map<String, Object> errorFor;
  final List<({String friendshipId, DateTime monthStartUtc})> calls = [];

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async {
    calls.add((friendshipId: friendshipId, monthStartUtc: monthStartUtc));
    final error = errorFor[friendshipId];
    if (error != null) throw error;
    return byFriendship[friendshipId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FriendListItem _friend(String friendshipId, String otherUserId) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: 'Friend',
    photoUrl: null,
    netBalancePaise: 0,
  );
}

ExpenseDoc _expense({
  required ExpenseCategory category,
  required DateTime date,
  required int userSharePaise,
  required String userId,
  required String counterpartyId,
}) {
  return ExpenseDoc(
    amountPaise: userSharePaise * 2,
    description: 'expense',
    category: category,
    date: date,
    payerId: userId,
    splits: [
      Split(userId: userId, sharePaise: userSharePaise),
      Split(userId: counterpartyId, sharePaise: userSharePaise),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: userId,
  );
}

void main() {
  // Fixed June 2026 clock → window start 2026-05-31T18:30:00Z.
  DateTime fixedNow() => DateTime.utc(2026, 6, 15, 12);
  final window = currentMonthWindowIst(fixedNow());

  ProviderContainer makeContainer({
    required List<FriendListItem> friends,
    required _RecordingExpenseStore store,
  }) {
    return ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('uid-me'),
        friendsListProvider.overrideWith((ref) => Stream.value(friends)),
        expenseRepositoryProvider.overrideWithValue(
          ExpenseRepository(store: store),
        ),
        homeClockProvider.overrideWithValue(fixedNow),
      ],
    );
  }

  test('fans out one read per friendship and folds the user shares', () async {
    final store = _RecordingExpenseStore(
      byFriendship: {
        'fid-bob': [
          _expense(
            category: ExpenseCategory.food,
            date: DateTime.utc(2026, 6, 5),
            userSharePaise: 50000,
            userId: 'uid-me',
            counterpartyId: 'uid-bob',
          ),
          _expense(
            category: ExpenseCategory.travel,
            date: DateTime.utc(2026, 6, 6),
            userSharePaise: 30000,
            userId: 'uid-me',
            counterpartyId: 'uid-bob',
          ),
        ],
        'fid-carol': [
          _expense(
            category: ExpenseCategory.food,
            date: DateTime.utc(2026, 6, 7),
            userSharePaise: 20000,
            userId: 'uid-me',
            counterpartyId: 'uid-carol',
          ),
        ],
      },
    );
    final container = makeContainer(
      friends: [
        _friend('fid-bob', 'uid-bob'),
        _friend('fid-carol', 'uid-carol'),
      ],
      store: store,
    );
    addTearDown(container.dispose);

    final breakdown = await container.read(
      monthlySpendBreakdownProvider.future,
    );

    expect(breakdown.monthTotalPaise, 100000);
    expect(breakdown.categories, hasLength(2));
    expect(breakdown.categories[0].category, ExpenseCategory.food);
    expect(breakdown.categories[0].totalPaise, 70000);
    expect(breakdown.categories[1].category, ExpenseCategory.travel);
    expect(breakdown.categories[1].totalPaise, 30000);

    // One read per friendship, each with the fixed IST window start.
    expect(store.calls, hasLength(2));
    expect(store.calls.map((c) => c.friendshipId).toSet(), {
      'fid-bob',
      'fid-carol',
    });
    for (final call in store.calls) {
      expect(call.monthStartUtc, window.startUtc);
    }
  });

  test('the provider result equals the pure aggregator over the same '
      'fan-out', () async {
    final bobExpenses = [
      _expense(
        category: ExpenseCategory.groceries,
        date: DateTime.utc(2026, 6, 3),
        userSharePaise: 12345,
        userId: 'uid-me',
        counterpartyId: 'uid-bob',
      ),
    ];
    final store = _RecordingExpenseStore(
      byFriendship: {'fid-bob': bobExpenses},
    );
    final container = makeContainer(
      friends: [_friend('fid-bob', 'uid-bob')],
      store: store,
    );
    addTearDown(container.dispose);

    final actual = await container.read(monthlySpendBreakdownProvider.future);

    final expected = aggregateMonthlySpend(
      input: [(otherUserId: 'uid-bob', expenses: bobExpenses)],
      monthStartUtc: window.startUtc,
      nextMonthStartUtc: window.endUtc,
    );
    expect(actual, expected);
  });

  test('no friendships → an empty breakdown with no reads', () async {
    final store = _RecordingExpenseStore();
    final container = makeContainer(friends: const [], store: store);
    addTearDown(container.dispose);

    final breakdown = await container.read(
      monthlySpendBreakdownProvider.future,
    );

    expect(breakdown.isEmpty, isTrue);
    expect(breakdown.monthTotalPaise, 0);
    expect(store.calls, isEmpty);
  });

  test('friendships with no current-month spend → the empty state', () async {
    final store = _RecordingExpenseStore(byFriendship: const {'fid-bob': []});
    final container = makeContainer(
      friends: [_friend('fid-bob', 'uid-bob')],
      store: store,
    );
    addTearDown(container.dispose);

    final breakdown = await container.read(
      monthlySpendBreakdownProvider.future,
    );

    expect(breakdown.isEmpty, isTrue);
    expect(store.calls, hasLength(1));
  });

  test('a failed read surfaces as AsyncError', () async {
    final store = _RecordingExpenseStore(
      errorFor: {'fid-bob': Exception('Firestore read failed')},
    );
    final container = makeContainer(
      friends: [_friend('fid-bob', 'uid-bob')],
      store: store,
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(monthlySpendBreakdownProvider.future),
      throwsA(isA<Exception>()),
    );

    final state = container.read(monthlySpendBreakdownProvider);
    expect(state, isA<AsyncError<dynamic>>());
  });

  test('invalidation re-runs the fan-out (the Retry path)', () async {
    final store = _RecordingExpenseStore(byFriendship: const {'fid-bob': []});
    final container = makeContainer(
      friends: [_friend('fid-bob', 'uid-bob')],
      store: store,
    );
    addTearDown(container.dispose);

    await container.read(monthlySpendBreakdownProvider.future);
    expect(store.calls, hasLength(1));

    container.invalidate(monthlySpendBreakdownProvider);
    await container.read(monthlySpendBreakdownProvider.future);
    expect(store.calls, hasLength(2));
  });
}
