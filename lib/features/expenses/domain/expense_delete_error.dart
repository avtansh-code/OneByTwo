import 'package:flutter/foundation.dart';

/// Typed classification of expense soft-delete failures (Architect
/// Notes §2.3). The controller catches an [ExpenseDeleteError] from
/// the repository, fires `expense_delete_failed { error_code }` with
/// the matching code, and transitions to the `AddExpenseError` state
/// with the user-facing message.
enum ExpenseDeleteErrorType {
  /// Firestore returned `permission-denied` (the user is not a member
  /// of the friendship, OR the rules at `firestore.rules` lines
  /// 275-302 rejected the soft-delete update).
  permissionDenied,

  /// Firestore returned `not-found` (the expense document was
  /// already deleted by another client).
  notFound,

  /// Firestore returned `unavailable` (no network connectivity, or
  /// the backend is temporarily unreachable).
  network,

  /// Any other failure (cancelled, aborted, etc.) or a
  /// non-`FirebaseException` thrown from the delete path.
  unknown,
}

/// Exception thrown by `ExpenseRepository.softDeleteExpense` on
/// failure.
///
/// Sibling of `ExpenseCreateError` and `ExpenseUpdateError` per
/// architect §2.3 Option (a): three discriminated unions, not a
/// shared parent.
@immutable
class ExpenseDeleteError implements Exception {
  /// Creates an [ExpenseDeleteError].
  const ExpenseDeleteError({
    required this.type,
    this.underlying,
    this.stackTrace,
  });

  /// Classification used by the controller to drive the snackbar and
  /// the `error_code` telemetry parameter.
  final ExpenseDeleteErrorType type;

  /// The original error (typically a `FirebaseException`).
  final Object? underlying;

  /// The stack trace captured at the throw site.
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'ExpenseDeleteError(type: ${type.name}, underlying: $underlying)';
  }
}
