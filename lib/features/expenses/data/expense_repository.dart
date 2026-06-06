import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_create_error.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

// Re-export the typed error from the domain layer so callers may
// import either path. The architect notes group the error type with
// the repository file; the domain location is the canonical
// definition.
export 'package:onebytwo/features/expenses/domain/expense_create_error.dart';

// ---------------------------------------------------------------------------
// Store interface
// ---------------------------------------------------------------------------

/// Thin abstraction over Firestore reads and writes for expense
/// documents. Mirrors the [`FriendshipStore`](../../friends/data/friendship_repository.dart)
/// and [`SettlementStore`](../../settlements/data/settlement_repository.dart)
/// patterns: the production implementation hits the real Firestore SDK;
/// tests inject a recording fake (no `fake_cloud_firestore` dependency
/// in `pubspec.yaml`).
abstract class ExpenseStore {
  /// Adds the expense document at
  /// `friendships/{friendshipId}/expenses/{auto-id}` and returns the
  /// generated document ID.
  Future<String> addExpense({
    required String friendshipId,
    required Map<String, dynamic> data,
  });

  /// Watches the most-recent non-deleted expenses for [friendshipId],
  /// ordered by `date` descending and capped at [limit] entries. Used
  /// by the Friend Detail screen (FR-FR-04).
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    required int limit,
  });
}

/// Production [ExpenseStore] backed by [FirebaseFirestore].
class FirestoreExpenseStore implements ExpenseStore {
  /// Creates a [FirestoreExpenseStore].
  FirestoreExpenseStore({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _expensesCollection(
    String friendshipId,
  ) {
    return _firestore
        .collection('friendships')
        .doc(friendshipId)
        .collection('expenses');
  }

  @override
  Future<String> addExpense({
    required String friendshipId,
    required Map<String, dynamic> data,
  }) async {
    final ref = await _expensesCollection(friendshipId).add(data);
    return ref.id;
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    required int limit,
  }) {
    return _expensesCollection(friendshipId)
        .where('deleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(_parseExpense)
              .whereType<ExpenseDoc>()
              .toList(growable: false),
        );
  }

  static ExpenseDoc? _parseExpense(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final amountPaise = data['amountPaise'];
    final description = data['description'];
    final categoryName = data['category'];
    final dateRaw = data['date'];
    final payerId = data['payerId'];
    final splitsRaw = data['splits'];
    final splitMethodName = data['splitMethod'];
    final createdBy = data['createdBy'];

    if (amountPaise is! int ||
        description is! String ||
        categoryName is! String ||
        payerId is! String ||
        splitsRaw is! List ||
        splitMethodName is! String ||
        createdBy is! String) {
      return null;
    }

    DateTime? date;
    if (dateRaw is Timestamp) {
      date = dateRaw.toDate();
    } else if (dateRaw is DateTime) {
      date = dateRaw;
    } else {
      return null;
    }

    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => ExpenseCategory.other,
    );

    final splitMethod = SplitMethod.values.firstWhere(
      (m) => m.name == splitMethodName,
      orElse: () => SplitMethod.equal,
    );

    final splits = <Split>[];
    for (final raw in splitsRaw) {
      if (raw is! Map) return null;
      final userId = raw['userId'];
      final sharePaise = raw['sharePaise'];
      if (userId is! String || sharePaise is! int) return null;
      splits.add(Split(userId: userId, sharePaise: sharePaise));
    }

    return ExpenseDoc(
      amountPaise: amountPaise,
      description: description,
      category: category,
      date: date,
      payerId: payerId,
      splits: splits,
      splitMethod: splitMethod,
      createdBy: createdBy,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Repository for the expense feature. The controller depends on this
/// concrete class via constructor injection; tests inject a fake that
/// `implements ExpenseRepository`.
///
/// Sole client-side producer of writes to
/// `friendships/{fid}/expenses/{eid}`. Never touches
/// `simplifiedBalances` (invariant 2) — that field is server-maintained
/// by the `onExpenseWriteFriendship` Cloud Function.
///
/// FR-FR-04 added the read-side [watchExpensesByFriendship] which powers
/// the Friend Detail screen's timeline.
class ExpenseRepository {
  /// Creates an [ExpenseRepository].
  ExpenseRepository({required ExpenseStore store}) : _store = store;

  final ExpenseStore _store;

  /// Persists the expense document and returns the generated ID.
  /// Translates [FirebaseException]s into [ExpenseCreateError] with a
  /// typed [ExpenseCreateErrorType] so the controller never has to
  /// interpret raw Firebase codes.
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async {
    try {
      return await _store.addExpense(
        friendshipId: friendshipId,
        data: doc.toCreateMap(),
      );
    } on FirebaseException catch (e, st) {
      throw ExpenseCreateError(
        type: _mapFirebaseCode(e.code),
        underlying: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw ExpenseCreateError(
        type: ExpenseCreateErrorType.unknown,
        underlying: e,
        stackTrace: st,
      );
    }
  }

  /// Watches the most-recent non-deleted expenses for [friendshipId],
  /// ordered by `date` descending and capped at [limit] (default 5).
  /// Powers the Friend Detail screen's timeline.
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    int limit = 5,
  }) {
    return _store.watchExpensesByFriendship(
      friendshipId: friendshipId,
      limit: limit,
    );
  }

  ExpenseCreateErrorType _mapFirebaseCode(String code) {
    switch (code) {
      case 'permission-denied':
        return ExpenseCreateErrorType.permissionDenied;
      case 'unavailable':
        return ExpenseCreateErrorType.network;
      default:
        return ExpenseCreateErrorType.unknown;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Production binding: wraps a [FirestoreExpenseStore] around the
/// app-wide [firebaseFirestoreProvider]. Tests override this provider
/// with a fake.
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return ExpenseRepository(store: FirestoreExpenseStore(firestore: firestore));
});
