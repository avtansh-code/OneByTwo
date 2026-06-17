// FriendDetailProvider unit tests (FR-FR-04).
//
// Tests the Riverpod combined provider that powers the Friend Detail
// screen. The provider fans out three reads — the friendship document,
// the expense subcollection stream, the settlements top-level stream
// filtered by (contextType: friendship, contextId: friendshipId) — and
// folds them into a `FriendDetailState` discriminated union.
//
// Patterns mirror friends_list_provider_test.dart (PR #35) and
// add_expense_controller_test.dart (PR #38).
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

class FakeFriendshipStore implements FriendshipStore {
  final Map<String, Map<String, dynamic>> documents = {};
  final StreamController<FriendshipDoc?> _watchController =
      StreamController<FriendshipDoc?>.broadcast();
  Object? watchError;
  String? lastWatchedFriendshipId;

  void emit(FriendshipDoc? doc) => _watchController.add(doc);
  void emitError(Object error) => _watchController.addError(error);

  Future<void> close() => _watchController.close();

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    documents[path] = data;
  }

  @override
  Future<bool> exists(String path) async => documents.containsKey(path);

  @override
  Future<Map<String, dynamic>?> get(String path) async => documents[path];

  @override
  Stream<List<FriendshipDoc>> watchByMember(String userId) {
    throw UnimplementedError('not exercised in friend_detail_provider tests');
  }

  @override
  Stream<FriendshipDoc?> watchById(String friendshipId) {
    lastWatchedFriendshipId = friendshipId;
    if (watchError != null) {
      // ignore: only_throw_errors
      return Stream<FriendshipDoc?>.error(watchError!);
    }
    // Synthesise an initial emission from the seeded documents map.
    if (documents.containsKey(friendshipId)) {
      final data = documents[friendshipId]!;
      final doc = FriendshipDoc.fromFirestore(id: friendshipId, data: data);
      return Stream<FriendshipDoc?>.value(doc).asyncExpand((first) async* {
        yield first;
        yield* _watchController.stream;
      });
    }
    // No seeded doc — emit null followed by any explicit emits.
    return Stream<FriendshipDoc?>.value(null).asyncExpand((first) async* {
      yield first;
      yield* _watchController.stream;
    });
  }
}

class FakeExpenseStore implements ExpenseStore {
  final StreamController<List<ExpenseDoc>> controller =
      StreamController<List<ExpenseDoc>>.broadcast();
  String? lastWatchedFriendshipId;
  int? lastWatchedLimit;

  @override
  Future<String> addExpense({
    required String friendshipId,
    required Map<String, dynamic> data,
  }) async {
    throw UnimplementedError('write path not exercised here');
  }

  @override
  String newExpenseId({required String friendshipId}) =>
      throw UnimplementedError('write path not exercised here');

  @override
  Future<void> setExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> data,
  }) async {
    throw UnimplementedError('write path not exercised here');
  }

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    throw UnimplementedError('update path not exercised here');
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    throw UnimplementedError('delete path not exercised here');
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    required int limit,
  }) {
    lastWatchedFriendshipId = friendshipId;
    lastWatchedLimit = limit;
    return controller.stream;
  }

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async => const [];
}

class FakeSettlementStore implements SettlementStore {
  final StreamController<List<SettlementDoc>> controller =
      StreamController<List<SettlementDoc>>.broadcast();
  String? lastWatchedContextType;
  String? lastWatchedContextId;

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    lastWatchedContextType = contextType;
    lastWatchedContextId = contextId;
    return controller.stream;
  }

  @override
  Future<String> createSettlement({required Map<String, dynamic> data}) async {
    // Read-side fake; the provider tests never call createSettlement.
    return 'sid-fake-friend-detail-provider';
  }
}

UserModel _user({required String displayName, String? photoUrl}) {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: displayName,
    photoUrl: photoUrl,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
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
    splits:
        splits ??
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
  String fromUserId = 'uid-me',
  String toUserId = 'uid-friend',
  int amountPaise = 5000,
}) {
  return SettlementDoc(
    settlementId: id,
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

const _args = FriendDetailArgs(
  friendshipId: 'uid-friend_uid-me',
  currentUserUid: 'uid-me',
  otherUserUid: 'uid-friend',
);

void main() {
  late FakeFriendshipStore friendshipStore;
  late FakeExpenseStore expenseStore;
  late FakeSettlementStore settlementStore;
  late ProviderContainer container;

  final profileBehaviour = <String, Future<UserModel?> Function()>{};

  setUp(() {
    friendshipStore = FakeFriendshipStore();
    expenseStore = FakeExpenseStore();
    settlementStore = FakeSettlementStore();
    profileBehaviour.clear();
    container = ProviderContainer(
      overrides: [
        friendshipRepositoryProvider.overrideWithValue(
          FriendshipRepository(store: friendshipStore),
        ),
        expenseRepositoryProvider.overrideWithValue(
          ExpenseRepository(store: expenseStore),
        ),
        settlementRepositoryProvider.overrideWithValue(
          SettlementRepository(store: settlementStore),
        ),
        userProfileProvider.overrideWith(
          (ref, uid) => (profileBehaviour[uid] ?? () async => null).call(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await friendshipStore.close();
    await expenseStore.controller.close();
    await settlementStore.controller.close();
  });

  group('friendDetailProvider', () {
    test(
      'queries the expense + settlement streams with the right arguments',
      () async {
        friendshipStore.documents['uid-friend_uid-me'] = {
          'memberIds': const ['uid-friend', 'uid-me'],
          'simplifiedBalances': const <String, dynamic>{},
          'lastActivityAt': null,
        };

        container.listen(friendDetailProvider(_args), (_, __) {});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(expenseStore.lastWatchedFriendshipId, 'uid-friend_uid-me');
        expect(expenseStore.lastWatchedLimit, 5);
        expect(settlementStore.lastWatchedContextType, 'friendship');
        expect(settlementStore.lastWatchedContextId, 'uid-friend_uid-me');
      },
    );

    test('emits loading initially', () async {
      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );

      final value = sub.read();
      expect(value, isA<AsyncLoading<FriendDetailState>>());
    });

    test('emits empty state when all three reads return empty', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{},
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );

      // Let the friendship doc resolve, then emit empty expense and
      // settlement streams.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expenseStore.controller.add(const []);
      settlementStore.controller.add(const []);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = sub.read().value;
      expect(state, isA<FriendDetailStateEmpty>());
      final empty = state! as FriendDetailStateEmpty;
      expect(empty.header.displayName, 'Bina');
      expect(empty.header.netBalancePaise, 0);
    });

    test('emits populated state with combined timeline (expenses + '
        'settlements) sorted by date desc', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{
          'uid-friend': {'uid-me': 12345},
        },
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final expense1 = _expense(
        description: 'Coffee',
        date: DateTime(2026, 6, 5),
      );
      final expense2 = _expense(description: 'Dinner', date: DateTime(2026, 6));
      expenseStore.controller.add([expense1, expense2]);
      final settlement1 = _settlement(id: 'sid-1', date: DateTime(2026, 6, 3));
      settlementStore.controller.add([settlement1]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = sub.read().value;
      expect(state, isA<FriendDetailStatePopulated>());
      final populated = state! as FriendDetailStatePopulated;

      expect(populated.header.displayName, 'Bina');
      expect(populated.header.netBalancePaise, 12345);
      expect(populated.header.balanceState, BalanceState.owed);

      // Combined timeline ordered: Coffee (6/5), Settlement (6/3), Dinner (6/1).
      expect(populated.timeline, hasLength(3));
      expect(populated.timeline[0], isA<TimelineExpense>());
      expect(
        (populated.timeline[0] as TimelineExpense).doc.description,
        'Coffee',
      );
      expect(populated.timeline[1], isA<TimelineSettlement>());
      expect(
        (populated.timeline[1] as TimelineSettlement).doc.settlementId,
        'sid-1',
      );
      expect(populated.timeline[2], isA<TimelineExpense>());
      expect(
        (populated.timeline[2] as TimelineExpense).doc.description,
        'Dinner',
      );
    });

    test(
      'caps the combined timeline at 5 events even when more exist',
      () async {
        friendshipStore.documents['uid-friend_uid-me'] = {
          'memberIds': const ['uid-friend', 'uid-me'],
          'simplifiedBalances': const <String, dynamic>{},
          'lastActivityAt': null,
        };
        profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

        final sub = container.listen(
          friendDetailProvider(_args),
          (_, __) {},
          fireImmediately: true,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expenseStore.controller.add([
          _expense(description: 'E1', date: DateTime(2026, 6, 10)),
          _expense(description: 'E2', date: DateTime(2026, 6, 9)),
          _expense(description: 'E3', date: DateTime(2026, 6, 8)),
          _expense(description: 'E4', date: DateTime(2026, 6, 7)),
          _expense(description: 'E5', date: DateTime(2026, 6, 6)),
        ]);
        settlementStore.controller.add([
          _settlement(id: 'sid-1', date: DateTime(2026, 6, 11)),
          _settlement(id: 'sid-2', date: DateTime(2026, 6, 5)),
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = sub.read().value! as FriendDetailStatePopulated;
        expect(state.timeline, hasLength(5));
        // Top is the most recent settlement.
        expect(state.timeline.first, isA<TimelineSettlement>());
        expect(
          (state.timeline.first as TimelineSettlement).doc.settlementId,
          'sid-1',
        );
      },
    );

    test('balanceState owes when current user is the debtor', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{
          'uid-me': {'uid-friend': 5000},
        },
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expenseStore.controller.add(const []);
      settlementStore.controller.add(const []);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = sub.read().value! as FriendDetailStateEmpty;
      expect(state.header.netBalancePaise, -5000);
      expect(state.header.balanceState, BalanceState.owes);
    });

    test('balanceState settled when net balance is zero', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{},
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expenseStore.controller.add(const []);
      settlementStore.controller.add(const []);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = sub.read().value! as FriendDetailStateEmpty;
      expect(state.header.netBalancePaise, 0);
      expect(state.header.balanceState, BalanceState.settled);
    });

    test(
      'falls back to "Unknown" when the user profile lookup returns null',
      () async {
        friendshipStore.documents['uid-friend_uid-me'] = {
          'memberIds': const ['uid-friend', 'uid-me'],
          'simplifiedBalances': const <String, dynamic>{},
          'lastActivityAt': null,
        };
        profileBehaviour['uid-friend'] = () async => null;

        final sub = container.listen(
          friendDetailProvider(_args),
          (_, __) {},
          fireImmediately: true,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expenseStore.controller.add(const []);
        settlementStore.controller.add(const []);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = sub.read().value! as FriendDetailStateEmpty;
        expect(state.header.displayName, 'Unknown');
      },
    );

    test('emits error when the friendship doc stream emits an error', () async {
      friendshipStore.watchError = Exception('boom');
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sub.read(), isA<AsyncError<FriendDetailState>>());
    });

    test('emits error when the expense stream errors', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{},
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expenseStore.controller.addError(Exception('expense boom'));
      await Future<void>.delayed(Duration.zero);

      expect(sub.read(), isA<AsyncError<FriendDetailState>>());
    });

    test('emits error when the settlement stream errors', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{},
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expenseStore.controller.add(const []);
      settlementStore.controller.addError(Exception('settle boom'));
      await Future<void>.delayed(Duration.zero);

      expect(sub.read(), isA<AsyncError<FriendDetailState>>());
    });

    test('emits error when the friendship document does not exist', () async {
      // friendshipStore.documents is empty — watchById emits null.
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sub.read(), isA<AsyncError<FriendDetailState>>());
    });

    test('balance pill updates when the friendship doc emits a new '
        'simplifiedBalances (AC-9 real-time behaviour)', () async {
      friendshipStore.documents['uid-friend_uid-me'] = {
        'memberIds': const ['uid-friend', 'uid-me'],
        'simplifiedBalances': const <String, dynamic>{},
        'lastActivityAt': null,
      };
      profileBehaviour['uid-friend'] = () async => _user(displayName: 'Bina');

      final sub = container.listen(
        friendDetailProvider(_args),
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expenseStore.controller.add(const []);
      settlementStore.controller.add(const []);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      var state = sub.read().value;
      expect(state, isA<FriendDetailStateEmpty>());
      expect((state! as FriendDetailStateEmpty).header.netBalancePaise, 0);

      // Server trigger writes a new simplifiedBalances after an
      // expense is added: the friend now owes the current user ₹50.
      friendshipStore.emit(
        const FriendshipDoc(
          friendshipId: 'uid-friend_uid-me',
          memberIds: ['uid-friend', 'uid-me'],
          simplifiedBalances: {
            'uid-friend': {'uid-me': 5000},
          },
          lastActivityAt: null,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      state = sub.read().value;
      expect(state, isA<FriendDetailStateEmpty>());
      final updated = state! as FriendDetailStateEmpty;
      expect(updated.header.netBalancePaise, 5000);
      expect(updated.header.balanceState, BalanceState.owed);
    });
  });
}
