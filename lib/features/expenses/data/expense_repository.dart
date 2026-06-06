import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/expenses/domain/expense_create_error.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';

// Re-export the typed error from the domain layer so callers may
// import either path. The architect notes group the error type with
// the repository file; the domain location is the canonical
// definition.
export 'package:onebytwo/features/expenses/domain/expense_create_error.dart';

// ---------------------------------------------------------------------------
// Store interface
// ---------------------------------------------------------------------------

/// Thin abstraction over Firestore writes for expense documents.
/// Mirrors the [`FriendshipStore`](../../friends/data/friendship_repository.dart)
/// pattern: the production implementation hits the real Firestore SDK;
/// tests inject a recording fake (no `fake_cloud_firestore` dependency
/// in `pubspec.yaml`).
// ignore: one_member_abstracts
abstract class ExpenseStore {
  /// Adds the expense document at
  /// `friendships/{friendshipId}/expenses/{auto-id}` and returns the
  /// generated document ID.
  Future<String> addExpense({
    required String friendshipId,
    required Map<String, dynamic> data,
  });
}

/// Production [ExpenseStore] backed by [FirebaseFirestore].
class FirestoreExpenseStore implements ExpenseStore {
  /// Creates a [FirestoreExpenseStore].
  FirestoreExpenseStore({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<String> addExpense({
    required String friendshipId,
    required Map<String, dynamic> data,
  }) async {
    final ref = await _firestore
        .collection('friendships')
        .doc(friendshipId)
        .collection('expenses')
        .add(data);
    return ref.id;
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
