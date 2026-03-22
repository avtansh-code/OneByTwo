import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/data/mappers/user_mapper.dart';
import 'package:one_by_two/data/remote/firestore/user_firestore_source.dart';
import 'package:one_by_two/domain/entities/user.dart';
import 'package:one_by_two/domain/repositories/user_repository.dart';

/// Concrete implementation of [UserRepository] backed by [UserFirestoreSource].
///
/// Every method wraps the corresponding data-source call in a try/catch block,
/// mapping [FirestoreException] (and unexpected errors) into [Result.failure]
/// values. Domain entities are produced by [UserMapper].
class UserRepositoryImpl implements UserRepository {
  /// Creates a [UserRepositoryImpl] with the given [UserFirestoreSource].
  const UserRepositoryImpl(this._userSource);

  final UserFirestoreSource _userSource;

  @override
  Future<Result<User>> getUser(String uid) async {
    try {
      final model = await _userSource.getUser(uid);
      if (model == null) {
        return Result.failure(
          const NotFoundException('User not found', code: 'not-found'),
        );
      }
      return Result.success(UserMapper.toEntity(model));
    } on FirestoreException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Stream<User?> watchUser(String uid) {
    return _userSource.watchUser(uid).map((model) {
      if (model == null) return null;
      return UserMapper.toEntity(model);
    });
  }

  @override
  Future<Result<void>> createUser(User user) async {
    try {
      final model = UserMapper.toModel(user);
      await _userSource.createUser(model);
      return Result.success(null);
    } on FirestoreException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> updateUser(User user) async {
    try {
      final model = UserMapper.toModel(user);
      await _userSource.updateUser(model);
      return Result.success(null);
    } on FirestoreException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<bool>> userExists(String uid) async {
    try {
      final exists = await _userSource.userExists(uid);
      return Result.success(exists);
    } on FirestoreException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }
}
