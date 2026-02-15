import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/result.dart';
import '../../data/local/dao/user_dao.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/firestore/user_firestore_source.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';

part 'user_providers.g.dart';

/// Provider for UserDao instance
@riverpod
UserDao userDao(UserDaoRef ref) {
  return UserDao(
    dbHelper: DatabaseHelper(),
    logger: Logger(),
  );
}

/// Provider for UserFirestoreSource instance
@riverpod
UserFirestoreSource userFirestoreSource(UserFirestoreSourceRef ref) {
  return UserFirestoreSource(
    firestore: FirebaseFirestore.instance,
    logger: Logger(),
  );
}

/// Provider for UserRepository instance
@riverpod
UserRepository userRepository(UserRepositoryRef ref) {
  return UserRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    userDao: ref.watch(userDaoProvider),
    firestoreSource: ref.watch(userFirestoreSourceProvider),
    logger: Logger(),
  );
}

/// Provider for creating user profile
@riverpod
class CreateProfile extends _$CreateProfile {
  @override
  FutureOr<UserEntity?> build() => null;

  Future<Result<UserEntity>> create({
    required String name,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.createProfile(
      name: name,
      avatarUrl: avatarUrl,
    );

    try {
      state = switch (result) {
        Success(:final data) => AsyncData(data),
        Failure(:final exception) => AsyncError(exception, StackTrace.current),
      };
    } catch (_) {
      // Ignore if provider's internal completer was already completed
    }

    return result;
  }
}

/// Provider for updating user profile
@riverpod
class UpdateProfile extends _$UpdateProfile {
  @override
  FutureOr<UserEntity?> build() => null;

  Future<void> updateUserProfile({
    String? name,
    String? avatarUrl,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.updateProfile(
      name: name,
      avatarUrl: avatarUrl,
    );

    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final exception) => AsyncError(exception, StackTrace.current),
    };
  }
}

/// Provider for current user profile
/// 
/// This provider fetches the current user's profile once.
/// Use [watchCurrentUserProfile] for reactive updates.
@riverpod
Future<UserEntity?> userProfile(UserProfileRef ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final result = await repository.getCurrentUserProfile();

  return switch (result) {
    Success(:final data) => data,
    Failure(:final exception) => throw exception,
  };
}

/// Provider for watching current user profile
/// 
/// This provider streams updates to the current user's profile.
@riverpod
Stream<UserEntity?> watchCurrentUserProfile(WatchCurrentUserProfileRef ref) {
  final repository = ref.watch(userRepositoryProvider);
  return repository.watchCurrentUserProfile();
}

/// Provider for getting a specific user's profile
/// 
/// This is a family provider that takes a user ID as parameter.
@riverpod
Future<UserEntity?> getUserProfile(GetUserProfileRef ref, String uid) async {
  final repository = ref.watch(userRepositoryProvider);
  final result = await repository.getUserProfile(uid);

  return switch (result) {
    Success(:final data) => data,
    Failure(:final exception) => throw exception,
  };
}
