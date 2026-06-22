import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/providers/firebase_providers.dart'
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

  /// FR-EX-05: pre-allocates a new (unwritten) document ID at
  /// `friendships/{friendshipId}/expenses/{auto-id}`. Used by the
  /// receipt-attach create flow so the controller can upload the
  /// receipt to `receipts/friendships/{fid}/{eid}` BEFORE the
  /// Firestore write commits.
  String newExpenseId({required String friendshipId});

  /// FR-EX-05: writes [data] at
  /// `friendships/{friendshipId}/expenses/{expenseId}` using `.set(...)`.
  /// Pair with [newExpenseId] to seed the document at the
  /// pre-allocated path so a previously-uploaded receipt at
  /// `receipts/friendships/{fid}/{eid}` is correctly referenced by
  /// the expense's `receiptUrl` field on first write.
  Future<void> setExpense({
    required String friendshipId,
    required String expenseId,
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

  /// FR-HD-03: one-shot read of [friendshipId]'s non-deleted expenses
  /// dated on or after [monthStartUtc], ordered by `date` descending.
  /// Powers the Home dashboard's cross-friendship monthly-spend fan-out.
  ///
  /// The `deleted == false` equality plus the `date` range and
  /// descending `orderBy` reuse the existing `deleted ASC + date DESC`
  /// composite index (ADR-0017 section 6) — no new index is required.
  /// The reducer applies the upper month bound; soft-deleted expenses
  /// are excluded here by the query filter and never reach the reducer.
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
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
  String newExpenseId({required String friendshipId}) {
    return _expensesCollection(friendshipId).doc().id;
  }

  @override
  Future<void> setExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> data,
  }) async {
    await _expensesCollection(friendshipId).doc(expenseId).set(data);
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

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async {
    // Bound the IST month on both ends server-side, so future-dated
    // expenses are never fetched. The caller passes the IST calendar-month
    // start as a UTC instant; the next IST month start is one calendar
    // month later. A two-sided range on `date` alongside the `deleted`
    // equality is still served by the existing `deleted ASC + date DESC`
    // composite index, so no new index is required (ADR-0017 section 6).
    const istShift = Duration(hours: 5, minutes: 30);
    final istMonthStart = monthStartUtc.add(istShift);
    final nextMonthStartUtc = DateTime.utc(
      istMonthStart.year,
      istMonthStart.month + 1,
    ).subtract(istShift);

    final snapshot = await _expensesCollection(friendshipId)
        .where('deleted', isEqualTo: false)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStartUtc),
        )
        .where('date', isLessThan: Timestamp.fromDate(nextMonthStartUtc))
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map(_parseExpense)
        .whereType<ExpenseDoc>()
        .toList(growable: false);
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

  /// FR-EX-05: pre-allocates a new (unwritten) expense ID under
  /// `friendships/{friendshipId}/expenses/`. The controller uses this
  /// to upload the receipt to `receipts/friendships/{fid}/{eid}`
  /// BEFORE the corresponding Firestore write commits, so the
  /// `receiptUrl` field in the create-map points at an existing
  /// Storage object on first write.
  String newExpenseId({required String friendshipId}) {
    return _store.newExpenseId(friendshipId: friendshipId);
  }

  /// FR-EX-05: writes [doc] at
  /// `friendships/{friendshipId}/expenses/{expenseId}` using `.set(...)`.
  /// Pair with [newExpenseId] for the create-with-receipt flow. Maps
  /// [FirebaseException]s to [ExpenseCreateError] (same posture as
  /// [createExpense]).
  Future<void> createExpenseAtId({
    required String friendshipId,
    required String expenseId,
    required ExpenseDoc doc,
  }) async {
    try {
      await _store.setExpense(
        friendshipId: friendshipId,
        expenseId: expenseId,
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

  /// FR-HD-03: one-shot read of [friendshipId]'s non-deleted,
  /// current-month expenses (dated on or after [monthStartUtc], `date`
  /// descending) for the Home dashboard's monthly-spend fan-out.
  ///
  /// A read delegates directly to the store: there is no typed-error
  /// mapping (unlike the writes above) — a failure surfaces as the raw
  /// rejection, which the `monthlySpendBreakdownProvider` `Future.wait`
  /// turns into an `AsyncError` for the card's error sub-state, mirroring
  /// how [watchExpensesByFriendship]'s stream errors propagate.
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) {
    return _store.fetchExpensesInMonth(
      friendshipId: friendshipId,
      monthStartUtc: monthStartUtc,
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
