/// Base exception class for all app-specific errors in OneByTwo.
///
/// This is a sealed class hierarchy that provides exhaustive pattern matching
/// for error handling throughout the application. Each subclass represents
/// a specific category of error that can occur during app operation.
///
/// Example usage:
/// ```dart
/// switch (exception) {
///   case NetworkException():
///     showOfflineBanner();
///   case AuthException():
///     redirectToLogin();
///   case FirestoreException():
///     logAndRetry();
///   // ... handle all cases
/// }
/// ```
sealed class AppException implements Exception {
  /// Creates an [AppException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const AppException(this.message, {this.code, this.stackTrace});

  /// A human-readable description of the error.
  final String message;

  /// An optional error code for programmatic identification.
  ///
  /// Typically maps to Firebase error codes (e.g., 'permission-denied',
  /// 'unavailable') or custom app error codes.
  final String? code;

  /// The stack trace captured when the exception was created.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Exception thrown when a network operation fails.
///
/// This includes cases like no internet connectivity, DNS resolution failures,
/// or server-side HTTP errors.
class NetworkException extends AppException {
  /// Creates a [NetworkException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const NetworkException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when an authentication operation fails.
///
/// This includes cases like invalid credentials, expired tokens,
/// or user-not-found errors from Firebase Auth.
class AuthException extends AppException {
  /// Creates an [AuthException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const AuthException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a Firestore operation fails.
///
/// This wraps Firebase Firestore errors such as 'unavailable' (offline),
/// 'permission-denied', 'not-found', or 'aborted' (concurrency conflict).
class FirestoreException extends AppException {
  /// Creates a [FirestoreException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const FirestoreException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when input validation fails.
///
/// Used for client-side validation errors such as invalid phone numbers,
/// empty required fields, or amounts that are out of range.
class ValidationException extends AppException {
  /// Creates a [ValidationException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const ValidationException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a requested resource is not found.
///
/// This maps to Firestore 'not-found' errors or cases where a document
/// reference points to a deleted or non-existent record.
class NotFoundException extends AppException {
  /// Creates a [NotFoundException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const NotFoundException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a user lacks permission for an operation.
///
/// Maps to Firestore 'permission-denied' errors or app-level role checks
/// (e.g., only group admins can delete a group).
class PermissionException extends AppException {
  /// Creates a [PermissionException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const PermissionException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown when a Firebase Storage operation fails.
///
/// Includes upload/download failures, file-not-found, or quota exceeded errors.
class StorageException extends AppException {
  /// Creates a [StorageException] with the given [message], optional [code],
  /// and optional [stackTrace].
  const StorageException(super.message, {super.code, super.stackTrace});
}

/// Exception thrown for unexpected or unclassified errors.
///
/// This is the catch-all for errors that don't fit into other categories.
/// The original [originalError] is preserved for debugging.
class UnknownException extends AppException {
  /// Creates an [UnknownException] with the given [message], optional
  /// [originalError], optional [code], and optional [stackTrace].
  const UnknownException(
    super.message, {
    this.originalError,
    super.code,
    super.stackTrace,
  });

  /// The original error object that caused this exception.
  final Object? originalError;

  @override
  String toString() =>
      'UnknownException(message: $message, code: $code, originalError: $originalError)';
}
