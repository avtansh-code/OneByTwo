import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';

import '../../entities/user.dart';
import '../../repositories/user_repository.dart';

/// Use case for retrieving a user profile by UID.
///
/// Validates that the UID is non-empty before delegating to
/// [UserRepository.getUser].
///
/// ## Example
/// ```dart
/// final result = await getUserUseCase('abc123');
/// result.when(
///   success: (user) => showProfile(user),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
class GetUserUseCase {
  /// Creates a [GetUserUseCase] with the given [_userRepository].
  const GetUserUseCase(this._userRepository);

  final UserRepository _userRepository;

  /// Retrieves the [User] entity for the given [uid].
  ///
  /// [uid] must be a non-empty Firebase Auth UID.
  ///
  /// Returns:
  /// - [Success<User>] with the user entity if found.
  /// - [Failure] with a [ValidationException] if [uid] is empty.
  /// - [Failure] with a [NotFoundException] if the user does not exist.
  /// - [Failure] with a [FirestoreException] if the read fails.
  Future<Result<User>> call(String uid) async {
    if (uid.trim().isEmpty) {
      return Result.failure(
        const ValidationException(
          'User ID cannot be empty',
          code: 'empty-user-id',
        ),
      );
    }

    return _userRepository.getUser(uid);
  }
}
