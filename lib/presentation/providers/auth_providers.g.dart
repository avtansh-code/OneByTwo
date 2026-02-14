// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authRepositoryHash() => r'c3e4d5f6g7h8i9j0k1l2m3n4o5p6q7r8';

/// Provider for AuthRepository instance
///
/// Copied from [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$authStateHash() => r'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';

/// Provider for current auth state (stream)
///
/// Emits UserEntity when user is signed in, null when signed out
///
/// Copied from [authState].
@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<UserEntity?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthStateRef = AutoDisposeStreamProviderRef<UserEntity?>;
String _$currentUserHash() => r'q1w2e3r4t5y6u7i8o9p0a1s2d3f4g5h6';

/// Provider for current user (synchronous)
///
/// Copied from [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeProvider<UserEntity?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentUserRef = AutoDisposeProviderRef<UserEntity?>;
String _$isSignedInHash() => r'z1x2c3v4b5n6m7l8k9j0h1g2f3d4s5a6';

/// Provider for checking if user is signed in
///
/// Copied from [isSignedIn].
@ProviderFor(isSignedIn)
final isSignedInProvider = AutoDisposeProvider<bool>.internal(
  isSignedIn,
  name: r'isSignedInProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isSignedInHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IsSignedInRef = AutoDisposeProviderRef<bool>;
String _$sendOtpHash() => r'e1d2c3b4a5z6y7x8w9v0u1t2s3r4q5p6';

/// Provider for sending OTP
///
/// This is a family provider that takes phone number as parameter
///
/// Copied from [SendOtp].
@ProviderFor(SendOtp)
final sendOtpProvider =
    AutoDisposeAsyncNotifierProvider<SendOtp, String?>.internal(
  SendOtp.new,
  name: r'sendOtpProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sendOtpHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SendOtp = AutoDisposeAsyncNotifier<String?>;
String _$verifyOtpHash() => r'o1i2u3y4t5r6e7w8q9p0l1k2j3h4g5f6';

/// Provider for verifying OTP
///
/// Copied from [VerifyOtp].
@ProviderFor(VerifyOtp)
final verifyOtpProvider =
    AutoDisposeAsyncNotifierProvider<VerifyOtp, UserEntity?>.internal(
  VerifyOtp.new,
  name: r'verifyOtpProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$verifyOtpHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VerifyOtp = AutoDisposeAsyncNotifier<UserEntity?>;
String _$signOutHash() => r'm1n2b3v4c5x6z7a8s9d0f1g2h3j4k5l6';

/// Provider for signing out
///
/// Copied from [SignOut].
@ProviderFor(SignOut)
final signOutProvider =
    AutoDisposeAsyncNotifierProvider<SignOut, void>.internal(
  SignOut.new,
  name: r'signOutProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$signOutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SignOut = AutoDisposeAsyncNotifier<void>;
String _$deleteAccountHash() => r'z1x2c3v4b5n6m7a8s9d0f1g2h3j4k5l6';

/// Provider for deleting account
///
/// Copied from [DeleteAccount].
@ProviderFor(DeleteAccount)
final deleteAccountProvider =
    AutoDisposeAsyncNotifierProvider<DeleteAccount, void>.internal(
  DeleteAccount.new,
  name: r'deleteAccountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deleteAccountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeleteAccount = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
