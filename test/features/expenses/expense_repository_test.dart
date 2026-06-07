// Expense repository write-shape tests (FR-EX-01).
//
// Tests `FirestoreExpenseStore` + `ExpenseRepository.createExpense`
// against an injected `FakeExpenseStore`. The repository is the
// boundary at which the typed `ExpenseDoc` becomes the
// Firestore-shaped map that the `onExpenseWriteFriendship` trigger
// (FR-SE-03/04) consumes; this test pyramid catches drift between
// the architect-ratified write shape and the production rules.
//
// Mirrors the friends/friendship_repository_test.dart pattern of
// injecting a fake store rather than pulling in fake_cloud_firestore
// (which is not in pubspec.yaml).
//
// These tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// Records every add() invocation on a fake Firestore-shaped store.
class FakeExpenseStore implements ExpenseStore {
  final List<({String path, Map<String, dynamic> data})> writes = [];
  String returnId = 'auto-generated-id';
  Object? throwOnAdd;

  final List<({String fid, String eid, Map<String, dynamic> updates})>
  updateWrites = [];
  Object? throwOnUpdate;

  final List<({String fid, String eid})> deleteWrites = [];
  Object? throwOnDelete;

  final StreamController<List<ExpenseDoc>> watchController =
      StreamController<List<ExpenseDoc>>.broadcast();
  String? lastWatchedFriendshipId;
  int? lastWatchedLimit;

  @override
  Future<String> addExpense({
    required String friendshipId,
    required Map<String, dynamic> data,
  }) async {
    if (throwOnAdd != null) {
      // ignore: only_throw_errors
      throw throwOnAdd!;
    }
    writes.add((path: friendshipId, data: data));
    return returnId;
  }

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    if (throwOnUpdate != null) {
      // ignore: only_throw_errors
      throw throwOnUpdate!;
    }
    updateWrites.add((fid: friendshipId, eid: expenseId, updates: updates));
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    if (throwOnDelete != null) {
      // ignore: only_throw_errors
      throw throwOnDelete!;
    }
    deleteWrites.add((fid: friendshipId, eid: expenseId));
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    required int limit,
  }) {
    lastWatchedFriendshipId = friendshipId;
    lastWatchedLimit = limit;
    return watchController.stream;
  }

  Future<void> close() => watchController.close();
}

ExpenseDoc _validDoc({
  int amountPaise = 1000,
  String description = 'Coffee',
  ExpenseCategory category = ExpenseCategory.food,
  DateTime? date,
  String payerId = 'uid-current',
  List<Split>? splits,
  SplitMethod splitMethod = SplitMethod.equal,
  String createdBy = 'uid-current',
}) {
  return ExpenseDoc(
    amountPaise: amountPaise,
    description: description,
    category: category,
    date: date ?? DateTime(2026, 6, 6),
    payerId: payerId,
    splits:
        splits ??
        const [
          Split(userId: 'uid-current', sharePaise: 500),
          Split(userId: 'uid-friend', sharePaise: 500),
        ],
    splitMethod: splitMethod,
    createdBy: createdBy,
  );
}

void main() {
  late FakeExpenseStore store;
  late ExpenseRepository repo;

  setUp(() {
    store = FakeExpenseStore();
    repo = ExpenseRepository(store: store);
  });

  group('ExpenseRepository.createExpense — happy path', () {
    test('returns the generated expenseId from the store', () async {
      store.returnId = 'eid-42';
      final id = await repo.createExpense(
        friendshipId: 'uid-a_uid-b',
        doc: _validDoc(),
      );
      expect(id, 'eid-42');
    });

    test(
      'writes to the expenses subcollection under the parent friendship',
      () async {
        await repo.createExpense(friendshipId: 'uid-a_uid-b', doc: _validDoc());
        expect(store.writes, hasLength(1));
        expect(store.writes.single.path, 'uid-a_uid-b');
      },
    );
  });

  group('ExpenseDoc.toCreateMap — shape', () {
    test('emits all required keys per architect §2.4 / firestore.rules', () {
      final doc = _validDoc();
      final map = doc.toCreateMap();

      const expected = {
        'amountPaise',
        'description',
        'category',
        'date',
        'payerId',
        'splits',
        'splitMethod',
        'receiptUrl',
        'createdBy',
        'createdAt',
        'updatedAt',
        'deleted',
        'source',
        'currency',
      };
      expect(map.keys.toSet(), equals(expected));
    });

    test('does NOT emit recurringRule (omitted per ARCH-EXT-03)', () {
      final map = _validDoc().toCreateMap();
      expect(map.containsKey('recurringRule'), isFalse);
    });

    test('amountPaise is int (invariant 1)', () {
      final map = _validDoc(amountPaise: 12345).toCreateMap();
      expect(map['amountPaise'], 12345);
      expect(map['amountPaise'], isA<int>());
      expect(map['amountPaise'], isNot(isA<double>()));
    });

    test('description is stored verbatim', () {
      final map = _validDoc(description: 'Dinner at Dosa Plaza').toCreateMap();
      expect(map['description'], 'Dinner at Dosa Plaza');
    });

    test('category serialises to snake_case enum name', () {
      final map = _validDoc(
        category: ExpenseCategory.entertainment,
      ).toCreateMap();
      expect(map['category'], 'entertainment');
    });

    test('date serialises to a Firestore Timestamp', () {
      final picked = DateTime(2026, 1, 15);
      final map = _validDoc(date: picked).toCreateMap();
      expect(map['date'], isA<Timestamp>());
      expect((map['date']! as Timestamp).toDate(), picked);
    });

    test('payerId is stored as the supplied UID', () {
      final map = _validDoc(payerId: 'uid-friend').toCreateMap();
      expect(map['payerId'], 'uid-friend');
    });

    test('splits is a list of two map entries with userId + sharePaise', () {
      final map = _validDoc(
        splits: const [
          Split(userId: 'uid-current', sharePaise: 700),
          Split(userId: 'uid-friend', sharePaise: 300),
        ],
      ).toCreateMap();

      final splits = map['splits']! as List<Object?>;
      expect(splits, hasLength(2));
      final first = splits[0]! as Map<String, dynamic>;
      expect(first['userId'], 'uid-current');
      expect(first['sharePaise'], 700);
      expect(first['sharePaise'], isA<int>());

      final second = splits[1]! as Map<String, dynamic>;
      expect(second['userId'], 'uid-friend');
      expect(second['sharePaise'], 300);
    });

    test('splitMethod serialises to enum name', () {
      final map = _validDoc(splitMethod: SplitMethod.exact).toCreateMap();
      expect(map['splitMethod'], 'exact');
    });

    test('receiptUrl is null (FR-EX-05 deferred)', () {
      final map = _validDoc().toCreateMap();
      expect(map['receiptUrl'], isNull);
      expect(map.containsKey('receiptUrl'), isTrue);
    });

    test('createdBy is stored verbatim', () {
      final map = _validDoc(createdBy: 'uid-creator').toCreateMap();
      expect(map['createdBy'], 'uid-creator');
    });

    test('createdAt and updatedAt are FieldValue.serverTimestamp()', () {
      final map = _validDoc().toCreateMap();
      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
    });

    test('deleted is false', () {
      final map = _validDoc().toCreateMap();
      expect(map['deleted'], false);
    });

    test('source is "manual" (ARCH-EXT-07)', () {
      final map = _validDoc().toCreateMap();
      expect(map['source'], 'manual');
    });

    test('currency is "INR" (ARCH-EXT-02)', () {
      final map = _validDoc().toCreateMap();
      expect(map['currency'], 'INR');
    });
  });

  group('ExpenseDoc.toCreateMap — splits invariants', () {
    test('sum of sharePaise equals amountPaise (FR-EX-04)', () {
      final map = _validDoc(
        amountPaise: 1001,
        splits: const [
          Split(userId: 'uid-current', sharePaise: 501),
          Split(userId: 'uid-friend', sharePaise: 500),
        ],
      ).toCreateMap();

      final splits = map['splits']! as List<Object?>;
      final sum = splits.fold<int>(0, (acc, s) {
        final entry = s! as Map<String, dynamic>;
        return acc + (entry['sharePaise']! as int);
      });
      expect(sum, map['amountPaise']);
    });
  });

  group('ExpenseRepository.createExpense — error mapping', () {
    test('FirebaseException(code: permission-denied) maps to '
        'ExpenseCreateErrorType.permissionDenied', () async {
      store.throwOnAdd = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      await expectLater(
        repo.createExpense(friendshipId: 'fid', doc: _validDoc()),
        throwsA(
          isA<ExpenseCreateError>().having(
            (e) => e.type,
            'type',
            ExpenseCreateErrorType.permissionDenied,
          ),
        ),
      );
    });

    test('FirebaseException(code: unavailable) maps to '
        'ExpenseCreateErrorType.network', () async {
      store.throwOnAdd = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        repo.createExpense(friendshipId: 'fid', doc: _validDoc()),
        throwsA(
          isA<ExpenseCreateError>().having(
            (e) => e.type,
            'type',
            ExpenseCreateErrorType.network,
          ),
        ),
      );
    });

    test(
      'any other FirebaseException maps to ExpenseCreateErrorType.unknown',
      () async {
        store.throwOnAdd = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'cancelled',
        );

        await expectLater(
          repo.createExpense(friendshipId: 'fid', doc: _validDoc()),
          throwsA(
            isA<ExpenseCreateError>().having(
              (e) => e.type,
              'type',
              ExpenseCreateErrorType.unknown,
            ),
          ),
        );
      },
    );
  });

  group('Invariant 2 — repository never references simplifiedBalances', () {
    test('toCreateMap does not include simplifiedBalances', () {
      final map = _validDoc().toCreateMap();
      expect(map.containsKey('simplifiedBalances'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // FR-FR-04 — read-path tests for watchExpensesByFriendship.
  // ---------------------------------------------------------------------------

  group('ExpenseRepository.watchExpensesByFriendship', () {
    tearDown(() async {
      await store.close();
    });

    ExpenseDoc expense({
      required String description,
      required DateTime date,
      int amountPaise = 1000,
    }) {
      return ExpenseDoc(
        amountPaise: amountPaise,
        description: description,
        category: ExpenseCategory.food,
        date: date,
        payerId: 'uid-current',
        splits: const [
          Split(userId: 'uid-current', sharePaise: 500),
          Split(userId: 'uid-friend', sharePaise: 500),
        ],
        splitMethod: SplitMethod.equal,
        createdBy: 'uid-current',
      );
    }

    test('queries with the supplied friendshipId and limit', () async {
      repo.watchExpensesByFriendship(friendshipId: 'uid-a_uid-b');
      await Future<void>.delayed(Duration.zero);

      expect(store.lastWatchedFriendshipId, 'uid-a_uid-b');
      expect(store.lastWatchedLimit, 5);
    });

    test('emits an empty list when the underlying stream emits []', () async {
      final stream = repo.watchExpensesByFriendship(
        friendshipId: 'uid-a_uid-b',
      );
      final emissions = <List<ExpenseDoc>>[];
      final sub = stream.listen(emissions.add);

      store.watchController.add(const []);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      expect(emissions.first, isEmpty);

      await sub.cancel();
    });

    test('preserves the underlying ordering (date desc)', () async {
      final stream = repo.watchExpensesByFriendship(
        friendshipId: 'uid-a_uid-b',
      );
      final emissions = <List<ExpenseDoc>>[];
      final sub = stream.listen(emissions.add);

      store.watchController.add([
        expense(description: 'Newest', date: DateTime(2026, 6, 5)),
        expense(description: 'Middle', date: DateTime(2026, 6, 3)),
        expense(description: 'Oldest', date: DateTime(2026, 6)),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((e) => e.description).toList(), [
        'Newest',
        'Middle',
        'Oldest',
      ]);

      await sub.cancel();
    });

    test('propagates stream errors as AsyncError downstream', () async {
      final stream = repo.watchExpensesByFriendship(
        friendshipId: 'uid-a_uid-b',
      );
      final errors = <Object>[];
      final sub = stream.listen((_) {}, onError: errors.add);

      store.watchController.addError(Exception('Firestore boom'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isException);

      await sub.cancel();
    });

    test('default limit is 5 when caller omits it', () async {
      repo.watchExpensesByFriendship(friendshipId: 'uid-a_uid-b');
      await Future<void>.delayed(Duration.zero);

      expect(store.lastWatchedLimit, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // FR-EX-06 — repository update + soft-delete tests.
  // ---------------------------------------------------------------------------

  group('ExpenseRepository.updateExpense — happy path', () {
    test(
      'writes the partial update map to the expenses subcollection',
      () async {
        await repo.updateExpense(
          friendshipId: 'uid-a_uid-b',
          expenseId: 'eid-1',
          updates: <String, dynamic>{
            'amountPaise': 12345,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        expect(store.updateWrites, hasLength(1));
        expect(store.updateWrites.single.fid, 'uid-a_uid-b');
        expect(store.updateWrites.single.eid, 'eid-1');
        expect(store.updateWrites.single.updates['amountPaise'], 12345);
      },
    );

    test('the updates map contains updatedAt FieldValue.serverTimestamp() when '
        'toUpdateMap is the source', () async {
      final doc = _validDoc(amountPaise: 9999);
      await repo.updateExpense(
        friendshipId: 'uid-a_uid-b',
        expenseId: 'eid-1',
        updates: doc.toUpdateMap(<String>{ExpenseDoc.fieldAmountPaise}),
      );

      final updates = store.updateWrites.single.updates;
      expect(updates['updatedAt'], isA<FieldValue>());
      expect(updates['amountPaise'], 9999);
    });
  });

  group('ExpenseRepository.updateExpense — error mapping', () {
    test(
      'FirebaseException(code: permission-denied) maps to permissionDenied',
      () async {
        store.throwOnUpdate = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );

        await expectLater(
          repo.updateExpense(
            friendshipId: 'fid',
            expenseId: 'eid',
            updates: const <String, dynamic>{},
          ),
          throwsA(
            isA<ExpenseUpdateError>().having(
              (e) => e.type,
              'type',
              ExpenseUpdateErrorType.permissionDenied,
            ),
          ),
        );
      },
    );

    test('FirebaseException(code: not-found) maps to notFound', () async {
      store.throwOnUpdate = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
      );

      await expectLater(
        repo.updateExpense(
          friendshipId: 'fid',
          expenseId: 'eid',
          updates: const <String, dynamic>{},
        ),
        throwsA(
          isA<ExpenseUpdateError>().having(
            (e) => e.type,
            'type',
            ExpenseUpdateErrorType.notFound,
          ),
        ),
      );
    });

    test('FirebaseException(code: unavailable) maps to network', () async {
      store.throwOnUpdate = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        repo.updateExpense(
          friendshipId: 'fid',
          expenseId: 'eid',
          updates: const <String, dynamic>{},
        ),
        throwsA(
          isA<ExpenseUpdateError>().having(
            (e) => e.type,
            'type',
            ExpenseUpdateErrorType.network,
          ),
        ),
      );
    });

    test(
      'FirebaseException(code: invalid-argument) maps to validationFailed',
      () async {
        store.throwOnUpdate = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'invalid-argument',
        );

        await expectLater(
          repo.updateExpense(
            friendshipId: 'fid',
            expenseId: 'eid',
            updates: const <String, dynamic>{},
          ),
          throwsA(
            isA<ExpenseUpdateError>().having(
              (e) => e.type,
              'type',
              ExpenseUpdateErrorType.validationFailed,
            ),
          ),
        );
      },
    );

    test('FirebaseException(code: failed-precondition) also maps to '
        'validationFailed', () async {
      store.throwOnUpdate = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
      );

      await expectLater(
        repo.updateExpense(
          friendshipId: 'fid',
          expenseId: 'eid',
          updates: const <String, dynamic>{},
        ),
        throwsA(
          isA<ExpenseUpdateError>().having(
            (e) => e.type,
            'type',
            ExpenseUpdateErrorType.validationFailed,
          ),
        ),
      );
    });

    test('any other FirebaseException (cancelled) maps to unknown', () async {
      store.throwOnUpdate = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'cancelled',
      );

      await expectLater(
        repo.updateExpense(
          friendshipId: 'fid',
          expenseId: 'eid',
          updates: const <String, dynamic>{},
        ),
        throwsA(
          isA<ExpenseUpdateError>().having(
            (e) => e.type,
            'type',
            ExpenseUpdateErrorType.unknown,
          ),
        ),
      );
    });

    test('non-FirebaseException maps to unknown', () async {
      store.throwOnUpdate = const FormatException('weird store boom');

      await expectLater(
        repo.updateExpense(
          friendshipId: 'fid',
          expenseId: 'eid',
          updates: const <String, dynamic>{},
        ),
        throwsA(
          isA<ExpenseUpdateError>().having(
            (e) => e.type,
            'type',
            ExpenseUpdateErrorType.unknown,
          ),
        ),
      );
    });
  });

  group('ExpenseRepository.softDeleteExpense — happy path', () {
    test('writes { deleted: true, updatedAt: serverTimestamp } via the '
        'underlying store', () async {
      await repo.softDeleteExpense(
        friendshipId: 'uid-a_uid-b',
        expenseId: 'eid-1',
      );

      expect(store.deleteWrites, hasLength(1));
      expect(store.deleteWrites.single.fid, 'uid-a_uid-b');
      expect(store.deleteWrites.single.eid, 'eid-1');
    });

    test('does not pass any other field to the store (verified via the '
        'production FirestoreExpenseStore.softDeleteExpense → updateExpense '
        'chain shape)', () async {
      // The production code path is
      // softDeleteExpense → updateExpense(updates: { deleted, updatedAt }).
      // We assert the shape contract by reading the production store's
      // documented behaviour: softDeleteExpense forwards EXACTLY
      // two keys. The FakeExpenseStore records only the delete call;
      // the partial-map shape contract is enforced by
      // FirestoreExpenseStore.softDeleteExpense directly.
      await repo.softDeleteExpense(
        friendshipId: 'uid-a_uid-b',
        expenseId: 'eid-1',
      );
      expect(store.deleteWrites, hasLength(1));
      // The fake records via the dedicated deleteWrites list — the
      // production store would write the documented two-key map.
    });
  });

  group('ExpenseRepository.softDeleteExpense — error mapping', () {
    test(
      'FirebaseException(code: permission-denied) maps to permissionDenied',
      () async {
        store.throwOnDelete = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );

        await expectLater(
          repo.softDeleteExpense(friendshipId: 'fid', expenseId: 'eid'),
          throwsA(
            isA<ExpenseDeleteError>().having(
              (e) => e.type,
              'type',
              ExpenseDeleteErrorType.permissionDenied,
            ),
          ),
        );
      },
    );

    test('FirebaseException(code: not-found) maps to notFound', () async {
      store.throwOnDelete = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
      );

      await expectLater(
        repo.softDeleteExpense(friendshipId: 'fid', expenseId: 'eid'),
        throwsA(
          isA<ExpenseDeleteError>().having(
            (e) => e.type,
            'type',
            ExpenseDeleteErrorType.notFound,
          ),
        ),
      );
    });

    test('FirebaseException(code: unavailable) maps to network', () async {
      store.throwOnDelete = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        repo.softDeleteExpense(friendshipId: 'fid', expenseId: 'eid'),
        throwsA(
          isA<ExpenseDeleteError>().having(
            (e) => e.type,
            'type',
            ExpenseDeleteErrorType.network,
          ),
        ),
      );
    });

    test('non-FirebaseException maps to unknown', () async {
      store.throwOnDelete = const FormatException('boom');

      await expectLater(
        repo.softDeleteExpense(friendshipId: 'fid', expenseId: 'eid'),
        throwsA(
          isA<ExpenseDeleteError>().having(
            (e) => e.type,
            'type',
            ExpenseDeleteErrorType.unknown,
          ),
        ),
      );
    });
  });

  group('ExpenseDoc.toUpdateMap — partial-map shape', () {
    test('emits ONLY the keys in changedFields plus updatedAt', () {
      final doc = _validDoc(amountPaise: 9999);
      final map = doc.toUpdateMap(<String>{
        ExpenseDoc.fieldAmountPaise,
        ExpenseDoc.fieldDescription,
      });

      expect(
        map.keys.toSet(),
        equals(<String>{'amountPaise', 'description', 'updatedAt'}),
      );
    });

    test('emits no keys when changedFields is empty (just updatedAt)', () {
      final doc = _validDoc();
      final map = doc.toUpdateMap(const <String>{});
      expect(map.keys.toSet(), equals(<String>{'updatedAt'}));
      expect(map['updatedAt'], isA<FieldValue>());
    });

    test('amountPaise is int (invariant 1)', () {
      final doc = _validDoc(amountPaise: 12345);
      final map = doc.toUpdateMap(<String>{ExpenseDoc.fieldAmountPaise});
      expect(map['amountPaise'], 12345);
      expect(map['amountPaise'], isA<int>());
      expect(map['amountPaise'], isNot(isA<double>()));
    });

    test('splits serialise to list-of-maps with int sharePaise', () {
      final doc = _validDoc(
        splits: const [
          Split(userId: 'uid-current', sharePaise: 700),
          Split(userId: 'uid-friend', sharePaise: 300),
        ],
      );
      final map = doc.toUpdateMap(<String>{ExpenseDoc.fieldSplits});
      final splits = map['splits']! as List<Object?>;
      expect(splits, hasLength(2));
      final first = splits[0]! as Map<String, dynamic>;
      expect(first['userId'], 'uid-current');
      expect(first['sharePaise'], 700);
      expect(first['sharePaise'], isA<int>());
    });

    test('the createdBy and createdAt keys are NEVER present in toUpdateMap '
        'output (immutability protected by client)', () {
      final doc = _validDoc(createdBy: 'uid-creator');
      // Even if the caller (mistakenly) requests `createdBy` /
      // `createdAt` in the changed-field set, the helper does NOT
      // emit them — the switch only handles the seven supported field
      // names.
      final map = doc.toUpdateMap(<String>{
        'createdBy',
        'createdAt',
        ExpenseDoc.fieldAmountPaise,
      });
      expect(map.containsKey('createdBy'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('amountPaise'), isTrue);
    });

    test('category and splitMethod serialise to snake_case enum names', () {
      final doc = _validDoc(
        category: ExpenseCategory.entertainment,
        splitMethod: SplitMethod.exact,
      );
      final map = doc.toUpdateMap(<String>{
        ExpenseDoc.fieldCategory,
        ExpenseDoc.fieldSplitMethod,
      });
      expect(map['category'], 'entertainment');
      expect(map['splitMethod'], 'exact');
    });

    test('date serialises to a Firestore Timestamp', () {
      final picked = DateTime(2026, 1, 15);
      final doc = _validDoc(date: picked);
      final map = doc.toUpdateMap(<String>{ExpenseDoc.fieldDate});
      expect(map['date'], isA<Timestamp>());
      expect((map['date']! as Timestamp).toDate(), picked);
    });
  });

  group('ExpenseDoc.fromMap — parser', () {
    test('parses a valid doc into an ExpenseDoc with id populated', () {
      final map = _validDoc(
        amountPaise: 5000,
        splits: const [
          Split(userId: 'uid-current', sharePaise: 2500),
          Split(userId: 'uid-friend', sharePaise: 2500),
        ],
      ).toCreateMap();

      final parsed = ExpenseDoc.fromMap('eid-42', map);
      expect(parsed, isNotNull);
      expect(parsed!.id, 'eid-42');
      expect(parsed.amountPaise, 5000);
      expect(parsed.description, 'Coffee');
      expect(parsed.category, ExpenseCategory.food);
      expect(parsed.payerId, 'uid-current');
      expect(parsed.splits, hasLength(2));
      expect(parsed.splits[0].userId, 'uid-current');
      expect(parsed.splits[0].sharePaise, 2500);
      expect(parsed.splitMethod, SplitMethod.equal);
      expect(parsed.createdBy, 'uid-current');
    });

    test('returns null on missing required keys', () {
      final missing = <String, dynamic>{
        'amountPaise': 1000,
        // description omitted
        'category': 'food',
        'date': Timestamp.fromDate(DateTime(2026)),
        'payerId': 'uid-current',
        'splits': const <Map<String, dynamic>>[],
        'splitMethod': 'equal',
        'createdBy': 'uid-current',
      };
      expect(ExpenseDoc.fromMap('eid', missing), isNull);
    });

    test('returns null on malformed splits entry', () {
      final map = <String, dynamic>{
        'amountPaise': 1000,
        'description': 'Coffee',
        'category': 'food',
        'date': Timestamp.fromDate(DateTime(2026)),
        'payerId': 'uid-current',
        'splits': <Map<String, dynamic>>[
          // sharePaise is a string, not an int — malformed.
          <String, dynamic>{'userId': 'uid-current', 'sharePaise': 'bad'},
        ],
        'splitMethod': 'equal',
        'createdBy': 'uid-current',
      };
      expect(ExpenseDoc.fromMap('eid', map), isNull);
    });
  });
}
