import 'package:flutter/foundation.dart';

/// Typed classification of expense-update failures (Architect Notes
/// §2.3). The controller catches an [ExpenseUpdateError] from the
/// repository, fires `expense_edit_failed { error_code }` with the
/// matching code, and transitions to the `AddExpenseError` state with
/// the user-facing message.
///
/// `concurrentEdit` is enumerated for forward compatibility per
/// architect §2.4 but is NEVER produced in v1.0 — full transactional
/// concurrent-edit detection is deferred to a follow-up PR.
enum ExpenseUpdateErrorType {
  /// Firestore returned `permission-denied` (the user is not a member
  /// of the friendship, OR the merged document shape is rejected by
  /// the rules at `firestore.rules` lines 275-302).
  permissionDenied,

  /// Firestore returned `not-found` (the expense document was deleted
  /// between the edit-open and the save).
  notFound,

  /// Firestore returned `unavailable` (no network connectivity, or
  /// the backend is temporarily unreachable).
  network,

  /// Firestore returned `invalid-argument` or `failed-precondition`
  /// (the merged document shape failed a rules-side predicate that
  /// the client did not pre-validate).
  validationFailed,

  /// **Reserved for future use.** A `runTransaction()`-based check
  /// detected that the server document advanced between read and
  /// write. Not produced in v1.0 per architect §2.4.
  concurrentEdit,

  /// Any other failure (cancelled, aborted, etc.) or a
  /// non-`FirebaseException` thrown from the update path.
  unknown,
}

/// Exception thrown by `ExpenseRepository.updateExpense` on failure.
///
/// Sibling of `ExpenseCreateError` and `ExpenseDeleteError` per
/// architect §2.3 Option (a): three discriminated unions, not a
/// shared parent. The shape mirrors `ExpenseCreateError` verbatim so
/// the controller can pattern-match on either.
@immutable
class ExpenseUpdateError implements Exception {
  /// Creates an [ExpenseUpdateError].
  const ExpenseUpdateError({
    required this.type,
    this.underlying,
    this.stackTrace,
  });

  /// Classification used by the controller to drive the snackbar and
  /// the `error_code` telemetry parameter.
  final ExpenseUpdateErrorType type;

  /// The original error (typically a `FirebaseException`).
  final Object? underlying;

  /// The stack trace captured at the throw site.
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'ExpenseUpdateError(type: ${type.name}, underlying: $underlying)';
  }
}
