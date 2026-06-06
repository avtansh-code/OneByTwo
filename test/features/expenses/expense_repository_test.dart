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
}
