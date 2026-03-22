import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';

import '../../entities/user.dart';
import '../../repositories/user_repository.dart';

/// Use case for creating a new user profile in Firestore.
///
/// Validates that the [User] entity has a non-empty ID, name, and phone
/// number before delegating to [UserRepository.createUser].
///
/// ## Validation
/// - [User.id] must not be empty or whitespace-only.
/// - [User.name] must not be empty or whitespace-only.
/// - [User.phone] must not be empty or whitespace-only.
///
/// ## Example
/// ```dart
/// final result = await createUserUseCase(newUser);
/// result.when(
///   success: (_) => navigateToHome(),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
class CreateUserUseCase {
  /// Creates a [CreateUserUseCase] with the given [_userRepository].
  const CreateUserUseCase(this._userRepository);

  final UserRepository _userRepository;

  /// Creates a new user document from the given [user] entity.
  ///
  /// [user] must have a non-empty [User.name] and [User.phone].
  ///
  /// Returns:
  /// - [Success<void>] when the user is created successfully.
  /// - [Failure] with a [ValidationException] if required fields are missing.
  /// - [Failure] with a [FirestoreException] if the write fails.
  Future<Result<void>> call(User user) async {
    if (user.id.trim().isEmpty) {
      return Result.failure(
        const ValidationException(
          'User ID cannot be empty',
          code: 'empty-user-id',
        ),
      );
    }

    if (user.name.trim().isEmpty) {
      return Result.failure(
        const ValidationException(
          'User name cannot be empty',
          code: 'empty-user-name',
        ),
      );
    }

    if (user.phone.trim().isEmpty) {
      return Result.failure(
        const ValidationException(
          'Phone number cannot be empty',
          code: 'empty-phone-number',
        ),
      );
    }

    return _userRepository.createUser(user);
  }
}
