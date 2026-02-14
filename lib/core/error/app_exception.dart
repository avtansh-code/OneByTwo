import 'package:meta/meta.dart';

/// Base exception class for all app-specific exceptions
/// 
/// All exceptions in the app should extend this class.
/// Use [code] for error identification and [message] for user-friendly descriptions.
@immutable
abstract class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.originalError,
    this.stackTrace,
  });
  
  /// Error code for logging and debugging
  final String code;
  
  /// User-friendly error message
  final String message;
  
  /// Original error object if this exception wraps another
  final Object? originalError;
  
  /// Stack trace of the original error
  final StackTrace? stackTrace;
  
  @override
  String toString() => 'AppException(code: $code, message: $message)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;
  
  @override
  int get hashCode => code.hashCode ^ message.hashCode;
}

/// Network-related exceptions (no internet, timeout, etc.)
class NetworkException extends AppException {
  const NetworkException({
    required super.code,
    required super.message,
    super.originalError,
    super.stackTrace,
  });
  
  factory NetworkException.noInternet() => const NetworkException(
        code: 'NETWORK_NO_INTERNET',
        message: 'No internet connection. Please check your network settings.',
      );
  
  factory NetworkException.timeout() => const NetworkException(
        code: 'NETWORK_TIMEOUT',
        message: 'Request timed out. Please try again.',
      );
  
  factory NetworkException.serverError() => const NetworkException(
        code: 'NETWORK_SERVER_ERROR',
        message: 'Server error. Please try again later.',
      );
}

/// Database-related exceptions (sqflite errors)
class DatabaseException extends AppException {
  const DatabaseException({
    required super.code,
    required super.message,
    super.originalError,
    super.stackTrace,
  });
  
  factory DatabaseException.queryFailed(Object error, StackTrace stack) =>
      DatabaseException(
        code: 'DB_QUERY_FAILED',
        message: 'Database query failed.',
        originalError: error,
        stackTrace: stack,
      );
  
  factory DatabaseException.insertFailed(Object error, StackTrace stack) =>
      DatabaseException(
        code: 'DB_INSERT_FAILED',
        message: 'Failed to save data.',
        originalError: error,
        stackTrace: stack,
      );
  
  factory DatabaseException.updateFailed(Object error, StackTrace stack) =>
      DatabaseException(
        code: 'DB_UPDATE_FAILED',
        message: 'Failed to update data.',
        originalError: error,
        stackTrace: stack,
      );
  
  factory DatabaseException.deleteFailed(Object error, StackTrace stack) =>
      DatabaseException(
        code: 'DB_DELETE_FAILED',
        message: 'Failed to delete data.',
        originalError: error,
        stackTrace: stack,
      );
}

/// Firestore-related exceptions
class FirestoreException extends AppException {
  const FirestoreException({
    required super.code,
    required super.message,
    super.originalError,
    super.stackTrace,
  });
  
  factory FirestoreException.permissionDenied() => const FirestoreException(
        code: 'FIRESTORE_PERMISSION_DENIED',
        message: 'Permission denied. Please check your access rights.',
      );
  
  factory FirestoreException.documentNotFound() => const FirestoreException(
        code: 'FIRESTORE_NOT_FOUND',
        message: 'Document not found.',
      );
  
  factory FirestoreException.operationFailed(Object error, StackTrace stack) =>
      FirestoreException(
        code: 'FIRESTORE_OPERATION_FAILED',
        message: 'Firestore operation failed.',
        originalError: error,
        stackTrace: stack,
      );
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    required super.code,
    required super.message,
    super.originalError,
    super.stackTrace,
  });
  
  factory AuthException.userNotFound() => const AuthException(
        code: 'AUTH_USER_NOT_FOUND',
        message: 'User not found.',
      );
  
  factory AuthException.invalidCredentials() => const AuthException(
        code: 'AUTH_INVALID_CREDENTIALS',
        message: 'Invalid phone number or OTP.',
      );
  
  factory AuthException.sessionExpired() => const AuthException(
        code: 'AUTH_SESSION_EXPIRED',
        message: 'Your session has expired. Please sign in again.',
      );
  
  factory AuthException.operationFailed(Object error, StackTrace stack) =>
      AuthException(
        code: 'AUTH_OPERATION_FAILED',
        message: 'Authentication failed.',
        originalError: error,
        stackTrace: stack,
      );
}

/// Validation exceptions (business logic validation)
class ValidationException extends AppException {
  const ValidationException({
    required super.code,
    required super.message,
    super.originalError,
    super.stackTrace,
  });
  
  factory ValidationException.invalidAmount() => const ValidationException(
        code: 'VALIDATION_INVALID_AMOUNT',
        message: 'Amount must be greater than zero.',
      );
  
  factory ValidationException.invalidSplit() => const ValidationException(
        code: 'VALIDATION_INVALID_SPLIT',
        message: 'Split amounts do not match total.',
      );
  
  factory ValidationException.emptyField(String fieldName) => ValidationException(
        code: 'VALIDATION_EMPTY_FIELD',
        message: '$fieldName cannot be empty.',
      );
  
  factory ValidationException.invalidPhoneNumber() => const ValidationException(
        code: 'VALIDATION_INVALID_PHONE',
        message: 'Please enter a valid phone number.',
      );
}

/// Cache/Storage exceptions
class CacheException extends AppException {
  const CacheException({
    required super.code,
    required super.message,
    super.originalError,
    super.stackTrace,
  });
  
  factory CacheException.readFailed(Object error, StackTrace stack) =>
      CacheException(
        code: 'CACHE_READ_FAILED',
        message: 'Failed to read cached data.',
        originalError: error,
        stackTrace: stack,
      );
  
  factory CacheException.writeFailed(Object error, StackTrace stack) =>
      CacheException(
        code: 'CACHE_WRITE_FAILED',
        message: 'Failed to save data to cache.',
        originalError: error,
        stackTrace: stack,
      );
}

/// Unknown/unexpected exceptions
class UnknownException extends AppException {
  const UnknownException({
    super.code = 'UNKNOWN_ERROR',
    super.message = 'An unexpected error occurred.',
    super.originalError,
    super.stackTrace,
  });
  
  factory UnknownException.fromError(Object error, StackTrace stack) =>
      UnknownException(
        originalError: error,
        stackTrace: stack,
      );
}
