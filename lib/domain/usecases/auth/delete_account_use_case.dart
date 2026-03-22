import 'package:one_by_two/core/errors/failure.dart';

import '../../repositories/auth_repository.dart';

/// Use case for permanently deleting the current user's account.
///
/// Delegates directly to [AuthRepository.deleteAccount]. The caller is
/// responsible for soft-deleting the user's Firestore data (profile,
/// groups, balances, etc.) before invoking this use case.
///
/// ## Example
/// ```dart
/// final result = await deleteAccountUseCase();
/// result.when(
///   success: (_) => navigateToWelcome(),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
class DeleteAccountUseCase {
  /// Creates a [DeleteAccountUseCase] with the given [_authRepository].
  const DeleteAccountUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Permanently deletes the current user's Firebase Auth account.
  ///
  /// This is irreversible. Returns:
  /// - [Success<void>] on successful deletion.
  /// - [Failure] with an [AuthException] if deletion fails
  ///   (e.g., re-authentication required).
  Future<Result<void>> call() async {
    return _authRepository.deleteAccount();
  }
}
