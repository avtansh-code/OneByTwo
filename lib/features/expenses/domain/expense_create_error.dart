import 'package:flutter/foundation.dart';

/// Typed classification of expense-creation failures (Architect Notes
/// §2.4). The controller catches an [ExpenseCreateError] from the
/// repository, fires `expense_save_failed { error_type, is_offline }`
/// with the matching `error_type` parameter, and transitions to the
/// `AddExpenseError` state with the user-facing message.
enum ExpenseCreateErrorType {
  /// Firestore returned `permission-denied` (the user is not a member
  /// of the friendship, or the document shape is rejected by the
  /// rules in `firestore.rules` lines 153–302).
  permissionDenied,

  /// Firestore returned `unavailable` (no network connectivity, or
  /// the backend is temporarily unreachable).
  network,

  /// Any other Firestore failure (`cancelled`, `aborted`, etc.) or a
  /// non-`FirebaseException` thrown from the write path.
  unknown,
}

/// Exception thrown by `ExpenseRepository.createExpense` on failure.
///
/// Carries the typed [type] for the controller to classify the user
/// experience and the original [underlying] error / [stackTrace] for
/// observability. The repository wraps every Firestore failure in
/// this class so the controller never has to interpret
/// `FirebaseException` codes directly.
@immutable
class ExpenseCreateError implements Exception {
  /// Creates an [ExpenseCreateError].
  const ExpenseCreateError({
    required this.type,
    this.underlying,
    this.stackTrace,
  });

  /// Classification used by the controller to drive the snackbar and
  /// the `error_type` telemetry parameter.
  final ExpenseCreateErrorType type;

  /// The original error (typically a `FirebaseException`).
  final Object? underlying;

  /// The stack trace captured at the throw site.
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'ExpenseCreateError(type: ${type.name}, underlying: $underlying)';
  }
}
