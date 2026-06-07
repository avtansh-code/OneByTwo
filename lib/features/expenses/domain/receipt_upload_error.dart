import 'package:flutter/foundation.dart';

/// Typed classification of receipt-upload failures (Architect Notes
/// §2.3). The controller catches a [ReceiptUploadError] from the
/// storage service, maps it to the surrounding state-machine error
/// surface, and surfaces a user-facing message via the snackbar.
///
/// On `permissionDenied`, the user is not a member of the friendship
/// — should be impossible in practice because the UI already gates
/// access by membership, but the typed branch is included as a
/// defence-in-depth signal.
enum ReceiptUploadErrorType {
  /// Firebase Storage returned `unauthorized` — the caller failed the
  /// `firestore.get()` membership predicate in `storage.rules`. Should
  /// not occur in practice; the client-side membership check upstream
  /// catches it first.
  permissionDenied,

  /// Client-side or server-side rejection of an oversize file
  /// (> 10 MB per SRS schema doc line 303). The client SHOULD reject
  /// this before the upload starts (AC-4); if it slips through, the
  /// Storage rules at `storage.rules` reject with this code.
  oversize,

  /// Client-side or server-side rejection of a non-JPEG/non-PNG file
  /// (per SRS schema doc line 304). The client SHOULD reject this
  /// before the upload starts (AC-5); if it slips through, the
  /// Storage rules at `storage.rules` reject with this code.
  unsupportedType,

  /// Firebase Storage returned `retry-limit-exceeded` or otherwise
  /// failed due to network conditions.
  network,

  /// Any other failure (cancelled, unknown Firebase code, or a
  /// non-`FirebaseException` thrown from the upload path).
  unknown,
}

/// Exception thrown by `ReceiptStorageService.uploadFriendshipReceipt`
/// (and the symmetric `deleteFriendshipReceipt`) on failure.
///
/// Sibling of `ExpenseCreateError`, `ExpenseUpdateError`, and
/// `ExpenseDeleteError` per architect §2.3 — three discriminated
/// unions, not a shared parent. The controller pattern-matches on
/// [type] to drive the user-facing message; the underlying error and
/// stack trace are carried for Crashlytics.
@immutable
class ReceiptUploadError implements Exception {
  /// Creates a [ReceiptUploadError].
  const ReceiptUploadError({
    required this.type,
    this.underlying,
    this.stackTrace,
  });

  /// Classification used by the controller to drive the snackbar and
  /// the `error_type` telemetry parameter on `expense_save_failed`.
  final ReceiptUploadErrorType type;

  /// The original error (typically a `FirebaseException`).
  final Object? underlying;

  /// The stack trace captured at the throw site.
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'ReceiptUploadError(type: ${type.name}, underlying: $underlying)';
  }
}
