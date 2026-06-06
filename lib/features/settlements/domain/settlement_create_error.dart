import 'package:flutter/foundation.dart';

/// Typed classification of settlement-creation failures (Architect Notes
/// §2.1). The Settle Up controller catches a [SettlementCreateError]
/// from the repository, fires `settle_up_error { error_code,
/// context_type, friendship_id_hash }` with the matching error code,
/// and transitions to the `SettleUpError` state with the user-facing
/// message.
enum SettlementCreateErrorType {
  /// Firestore returned `permission-denied` (the user is not a member
  /// of the context, fromUserId != request.auth.uid, or any other
  /// predicate in `firestore.rules` lines 379–489 rejected the doc).
  permissionDenied,

  /// Firestore returned `unavailable` (no network connectivity, or
  /// the backend is temporarily unreachable). Firestore's offline
  /// persistence still queues the write; the snackbar is informational.
  network,

  /// The simplified balance changed between the time the sheet opened
  /// and the time the user tapped Save — reserved for a future
  /// optimistic-concurrency check. PR #43 does NOT raise this yet; it
  /// is enumerated so the controller / snackbar / telemetry surface
  /// can be extended without an enum change.
  balanceChanged,

  /// The submitted amount fails the rules' `amountPaise > 0` predicate.
  /// Reserved for the defence-in-depth path; the client validator
  /// blocks Save first, so this branch should only fire if a future
  /// code path bypasses the validator.
  invalidAmount,

  /// Any other Firestore failure (`cancelled`, `aborted`, etc.) or a
  /// non-`FirebaseException` thrown from the write path.
  unknown,
}

/// Extension methods on [SettlementCreateErrorType] for UI + telemetry
/// mapping. Centralised here so the controller never has to
/// `switch` on the enum directly.
extension SettlementCreateErrorTypeX on SettlementCreateErrorType {
  /// The user-facing snackbar message rendered when the controller
  /// transitions Saving → SettleUpError.
  String get userFacingMessage {
    switch (this) {
      case SettlementCreateErrorType.permissionDenied:
        return "Couldn't record the settlement. Please try again.";
      case SettlementCreateErrorType.network:
        return "You're offline. The settlement will be recorded when "
            'you reconnect.';
      case SettlementCreateErrorType.balanceChanged:
        return 'The outstanding balance has changed. Please reopen '
            'Settle Up.';
      case SettlementCreateErrorType.invalidAmount:
        return 'The settlement amount is invalid. Please re-enter it.';
      case SettlementCreateErrorType.unknown:
        return "Couldn't record the settlement. Please try again.";
    }
  }

  /// The `error_code` parameter value on the `settle_up_error`
  /// analytics event. Mirrors the snake_case convention used by
  /// `expense_save_failed { error_type }`.
  String get telemetryErrorCode {
    switch (this) {
      case SettlementCreateErrorType.permissionDenied:
        return 'permission_denied';
      case SettlementCreateErrorType.network:
        return 'network';
      case SettlementCreateErrorType.balanceChanged:
        return 'balance_changed';
      case SettlementCreateErrorType.invalidAmount:
        return 'invalid_amount';
      case SettlementCreateErrorType.unknown:
        return 'unknown';
    }
  }
}

/// Exception thrown by [SettlementRepository.createSettlement] on
/// failure. Mirrors `ExpenseCreateError` (PR #38) 1:1.
///
/// Carries the typed [type] for the controller to classify the user
/// experience and the original [underlying] error / [stackTrace] for
/// observability. The repository wraps every Firestore failure in
/// this class so the controller never has to interpret
/// `FirebaseException` codes directly.
@immutable
class SettlementCreateError implements Exception {
  /// Creates a [SettlementCreateError].
  const SettlementCreateError({
    required this.type,
    this.underlying,
    this.stackTrace,
  });

  /// Classification used by the controller to drive the snackbar and
  /// the `error_code` telemetry parameter.
  final SettlementCreateErrorType type;

  /// The original error (typically a `FirebaseException`).
  final Object? underlying;

  /// The stack trace captured at the throw site.
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'SettlementCreateError(type: ${type.name}, '
        'underlying: $underlying)';
  }
}
