import 'package:one_by_two/core/errors/failure.dart';

import '../../repositories/auth_repository.dart';

/// Use case for signing out the currently authenticated user.
///
/// Delegates directly to [AuthRepository.signOut]. No additional
/// validation is needed for this operation.
///
/// ## Example
/// ```dart
/// final result = await signOutUseCase();
/// result.when(
///   success: (_) => navigateToLogin(),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
class SignOutUseCase {
  /// Creates a [SignOutUseCase] with the given [_authRepository].
  const SignOutUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Signs out the current user.
  ///
  /// Returns:
  /// - [Success<void>] on successful sign-out.
  /// - [Failure] with an [AuthException] if sign-out fails.
  Future<Result<void>> call() async {
    return _authRepository.signOut();
  }
}
