import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/result.dart';
import '../../data/local/database_helper.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

/// Provider for AuthRepository instance
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
    databaseHelper: DatabaseHelper(),
    logger: Logger(),
  );
}

/// Provider for current auth state (stream)
/// 
/// Emits UserEntity when user is signed in, null when signed out
@riverpod
Stream<UserEntity?> authState(AuthStateRef ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
}

/// Provider for current user (synchronous)
@riverpod
UserEntity? currentUser(CurrentUserRef ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.currentUser;
}

/// Provider for checking if user is signed in
@riverpod
bool isSignedIn(IsSignedInRef ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.isSignedIn;
}

/// Provider for sending OTP
/// 
/// This is a family provider that takes phone number as parameter
@riverpod
class SendOtp extends _$SendOtp {
  @override
  FutureOr<String?> build() => null;

  Future<void> send(String phoneNumber) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.sendOtp(phoneNumber);

    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final exception) => AsyncError(exception, StackTrace.current),
    };
  }
}

/// Provider for verifying OTP
@riverpod
class VerifyOtp extends _$VerifyOtp {
  @override
  FutureOr<UserEntity?> build() => null;

  Future<void> verify({
    required String verificationId,
    required String otp,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.verifyOtp(
      verificationId: verificationId,
      otp: otp,
    );

    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final exception) => AsyncError(exception, StackTrace.current),
    };
  }
}

/// Provider for signing out
@riverpod
class SignOut extends _$SignOut {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.signOut();

    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final exception) => AsyncError(exception, StackTrace.current),
    };
  }
}

/// Provider for deleting account
@riverpod
class DeleteAccount extends _$DeleteAccount {
  @override
  FutureOr<void> build() {}

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.deleteAccount();

    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final exception) => AsyncError(exception, StackTrace.current),
    };
  }
}
