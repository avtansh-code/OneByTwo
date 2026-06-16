import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore_for_file: one_member_abstracts
//
// The abstract class exists because [DeleteAccountRepository] is a typed
// factory-constructor surface that hides the concrete
// [DeleteAccountRepositoryImpl] (the established pattern in the codebase;
// see [ReminderRepository] in lib/features/reminders/data/). The single
// method is the signal that this is a one-call surface.

/// Callable signature for the `deleteUserAccount` Cloud Function.
///
/// Takes no input — the subject is the caller's own `request.auth.uid`.
/// Matches the response shape returned by
/// `FirebaseFunctions.httpsCallable(...).call()` (`{ success: true }`).
typedef DeleteAccountCallable = Future<Map<String, dynamic>> Function();

/// Exception thrown by [DeleteAccountCallable] when the callable rejects
/// with a typed `HttpsError`. The production wiring catches
/// `FirebaseFunctionsException` at the `cloud_functions` boundary and
/// re-throws as [DeleteAccountException]; the `error_code` carried here is
/// a PII-free catalogue code (e.g. `'INTERNAL'`, `'UNAUTHENTICATED'`).
class DeleteAccountException implements Exception {
  /// Creates a [DeleteAccountException].
  const DeleteAccountException({required this.code, required this.errorCode});

  /// The Firebase `HttpsError.code` (e.g. `'internal'`).
  final String code;

  /// The server-side `details.errorCode` (e.g. `'INTERNAL'`).
  final String errorCode;

  @override
  String toString() =>
      'DeleteAccountException(code: $code, errorCode: $errorCode)';
}

/// Repository surface for FR-AU-09 account deletion.
///
/// Wraps the `deleteUserAccount` Cloud Function callable. The production
/// override in `main.dart` injects a [DeleteAccountCallable] backed by
/// `FirebaseFunctions.instance.httpsCallable(...)`; tests inject a fake
/// callable directly so no Firebase initialisation is needed.
abstract class DeleteAccountRepository {
  /// Creates a default [DeleteAccountRepository] backed by [callable].
  const factory DeleteAccountRepository({
    required DeleteAccountCallable callable,
  }) = DeleteAccountRepositoryImpl;

  /// Default constructor for sub-classing / fakes.
  const DeleteAccountRepository._();

  /// Invokes the `deleteUserAccount` callable.
  ///
  /// Returns normally when the cascade succeeds. Throws
  /// [DeleteAccountException] (or any opaque error the callable raises)
  /// on failure so the controller can map it to a PII-free `error_code`.
  Future<void> deleteAccount();
}

/// Concrete implementation of [DeleteAccountRepository].
class DeleteAccountRepositoryImpl extends DeleteAccountRepository {
  /// Creates a [DeleteAccountRepositoryImpl] with the given [callable].
  const DeleteAccountRepositoryImpl({required DeleteAccountCallable callable})
    : _callable = callable,
      super._();

  final DeleteAccountCallable _callable;

  @override
  Future<void> deleteAccount() async {
    final response = await _callable();
    if (response['success'] != true) {
      throw const DeleteAccountException(
        code: 'internal',
        errorCode: 'INTERNAL',
      );
    }
  }
}

/// Provides a [DeleteAccountRepository]. Production overrides in
/// `main.dart` with the `cloud_functions`-backed callable; tests override
/// with a fake.
final deleteAccountRepositoryProvider = Provider<DeleteAccountRepository>((
  ref,
) {
  throw UnimplementedError(
    'deleteAccountRepositoryProvider must be overridden with a '
    'DeleteAccountCallable backed by FirebaseFunctions in main.dart.',
  );
});
