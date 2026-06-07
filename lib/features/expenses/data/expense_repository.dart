import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/expenses/domain/expense_create_error.dart';
import 'package:onebytwo/features/expenses/domain/expense_delete_error.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/expense_update_error.dart';

// Re-export the typed errors from the domain layer so callers may
// import either path. The architect notes group the error types with
// the repository file; the domain location is the canonical
// definition.
export 'package:onebytwo/features/expenses/domain/expense_create_error.dart';
export 'package:onebytwo/features/expenses/domain/expense_delete_error.dart';
export 'package:onebytwo/features/expenses/domain/expense_update_error.dart';

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

  /// Applies a partial update at
  /// `friendships/{friendshipId}/expenses/{expenseId}`. The caller is
  /// responsible for shaping [updates] correctly (FR-EX-06 uses
  /// `ExpenseDoc.toUpdateMap` to produce the partial map).
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  });

  /// Marks the expense at
  /// `friendships/{friendshipId}/expenses/{expenseId}` as deleted by
  /// flipping `deleted: true` + refreshing `updatedAt`. Implemented as
  /// a convenience wrapper over [updateExpense].
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
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
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    await _expensesCollection(friendshipId).doc(expenseId).update(updates);
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    await updateExpense(
      friendshipId: friendshipId,
      expenseId: expenseId,
      updates: <String, dynamic>{
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
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

  /// Thin shim that adapts a [QueryDocumentSnapshot] to the shared
  /// [ExpenseDoc.fromMap] parser (architect §2.9 item 6). Both the
  /// watch stream and the new `expenseDetailProvider` consume the
  /// same parsing logic — typos in one path cannot diverge from the
  /// other.
  static ExpenseDoc? _parseExpense(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ExpenseDoc.fromMap(doc.id, doc.data());
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
/// the Friend Detail screen's timeline. FR-EX-06 adds [updateExpense]
/// and [softDeleteExpense] for the edit / delete flow.
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

  /// Applies a partial update to the expense at
  /// `friendships/{friendshipId}/expenses/{expenseId}`. [updates] is
  /// the partial map produced by `ExpenseDoc.toUpdateMap` (or the
  /// caller). Maps [FirebaseException]s to [ExpenseUpdateError] per
  /// architect §2.3.
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _store.updateExpense(
        friendshipId: friendshipId,
        expenseId: expenseId,
        updates: updates,
      );
    } on FirebaseException catch (e, st) {
      throw ExpenseUpdateError(
        type: _mapUpdateCode(e.code),
        underlying: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw ExpenseUpdateError(
        type: ExpenseUpdateErrorType.unknown,
        underlying: e,
        stackTrace: st,
      );
    }
  }

  /// Soft-deletes the expense at
  /// `friendships/{friendshipId}/expenses/{expenseId}` by setting
  /// `deleted: true` (the document remains for audit / undelete).
  /// Maps [FirebaseException]s to [ExpenseDeleteError] per architect
  /// §2.3.
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    try {
      await _store.softDeleteExpense(
        friendshipId: friendshipId,
        expenseId: expenseId,
      );
    } on FirebaseException catch (e, st) {
      throw ExpenseDeleteError(
        type: _mapDeleteCode(e.code),
        underlying: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw ExpenseDeleteError(
        type: ExpenseDeleteErrorType.unknown,
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

  ExpenseUpdateErrorType _mapUpdateCode(String code) {
    switch (code) {
      case 'permission-denied':
        return ExpenseUpdateErrorType.permissionDenied;
      case 'not-found':
        return ExpenseUpdateErrorType.notFound;
      case 'unavailable':
        return ExpenseUpdateErrorType.network;
      case 'invalid-argument':
      case 'failed-precondition':
        return ExpenseUpdateErrorType.validationFailed;
      default:
        return ExpenseUpdateErrorType.unknown;
    }
  }

  ExpenseDeleteErrorType _mapDeleteCode(String code) {
    switch (code) {
      case 'permission-denied':
        return ExpenseDeleteErrorType.permissionDenied;
      case 'not-found':
        return ExpenseDeleteErrorType.notFound;
      case 'unavailable':
        return ExpenseDeleteErrorType.network;
      default:
        return ExpenseDeleteErrorType.unknown;
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
