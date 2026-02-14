// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userDaoHash() => r'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';

/// Provider for UserDao instance
///
/// Copied from [userDao].
@ProviderFor(userDao)
final userDaoProvider = AutoDisposeProvider<UserDao>.internal(
  userDao,
  name: r'userDaoProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserDaoRef = AutoDisposeProviderRef<UserDao>;
String _$userFirestoreSourceHash() => r'b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7';

/// Provider for UserFirestoreSource instance
///
/// Copied from [userFirestoreSource].
@ProviderFor(userFirestoreSource)
final userFirestoreSourceProvider =
    AutoDisposeProvider<UserFirestoreSource>.internal(
  userFirestoreSource,
  name: r'userFirestoreSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userFirestoreSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserFirestoreSourceRef = AutoDisposeProviderRef<UserFirestoreSource>;
String _$userRepositoryHash() => r'c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8';

/// Provider for UserRepository instance
///
/// Copied from [userRepository].
@ProviderFor(userRepository)
final userRepositoryProvider = AutoDisposeProvider<UserRepository>.internal(
  userRepository,
  name: r'userRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserRepositoryRef = AutoDisposeProviderRef<UserRepository>;
String _$userProfileHash() => r'd4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9';

/// Provider for current user profile
///
/// This provider fetches the current user's profile once.
/// Use [watchCurrentUserProfile] for reactive updates.
///
/// Copied from [userProfile].
@ProviderFor(userProfile)
final userProfileProvider = AutoDisposeFutureProvider<UserEntity?>.internal(
  userProfile,
  name: r'userProfileProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserProfileRef = AutoDisposeFutureProviderRef<UserEntity?>;
String _$watchCurrentUserProfileHash() =>
    r'e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0';

/// Provider for watching current user profile
///
/// This provider streams updates to the current user's profile.
///
/// Copied from [watchCurrentUserProfile].
@ProviderFor(watchCurrentUserProfile)
final watchCurrentUserProfileProvider =
    AutoDisposeStreamProvider<UserEntity?>.internal(
  watchCurrentUserProfile,
  name: r'watchCurrentUserProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$watchCurrentUserProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef WatchCurrentUserProfileRef = AutoDisposeStreamProviderRef<UserEntity?>;
String _$getUserProfileHash() => r'f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1';

/// Provider for getting a specific user's profile
///
/// This is a family provider that takes a user ID as parameter.
///
/// Copied from [getUserProfile].
@ProviderFor(getUserProfile)
const getUserProfileProvider = GetUserProfileFamily();

/// Provider for getting a specific user's profile
///
/// This is a family provider that takes a user ID as parameter.
///
/// Copied from [getUserProfile].
class GetUserProfileFamily extends Family<AsyncValue<UserEntity?>> {
  /// Provider for getting a specific user's profile
  ///
  /// This is a family provider that takes a user ID as parameter.
  ///
  /// Copied from [getUserProfile].
  const GetUserProfileFamily();

  /// Provider for getting a specific user's profile
  ///
  /// This is a family provider that takes a user ID as parameter.
  ///
  /// Copied from [getUserProfile].
  GetUserProfileProvider call(
    String uid,
  ) {
    return GetUserProfileProvider(
      uid,
    );
  }

  @override
  GetUserProfileProvider getProviderOverride(
    covariant GetUserProfileProvider provider,
  ) {
    return call(
      provider.uid,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getUserProfileProvider';
}

/// Provider for getting a specific user's profile
///
/// This is a family provider that takes a user ID as parameter.
///
/// Copied from [getUserProfile].
class GetUserProfileProvider extends AutoDisposeFutureProvider<UserEntity?> {
  /// Provider for getting a specific user's profile
  ///
  /// This is a family provider that takes a user ID as parameter.
  ///
  /// Copied from [getUserProfile].
  GetUserProfileProvider(
    String uid,
  ) : this._internal(
          (ref) => getUserProfile(
            ref as GetUserProfileRef,
            uid,
          ),
          from: getUserProfileProvider,
          name: r'getUserProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getUserProfileHash,
          dependencies: GetUserProfileFamily._dependencies,
          allTransitiveDependencies:
              GetUserProfileFamily._allTransitiveDependencies,
          uid: uid,
        );

  GetUserProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.uid,
  }) : super.internal();

  final String uid;

  @override
  Override overrideWith(
    FutureOr<UserEntity?> Function(GetUserProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetUserProfileProvider._internal(
        (ref) => create(ref as GetUserProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        uid: uid,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<UserEntity?> createElement() {
    return _GetUserProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetUserProfileProvider && other.uid == uid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, uid.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GetUserProfileRef on AutoDisposeFutureProviderRef<UserEntity?> {
  /// The parameter `uid` of this provider.
  String get uid;
}

class _GetUserProfileProviderElement
    extends AutoDisposeFutureProviderElement<UserEntity?>
    with GetUserProfileRef {
  _GetUserProfileProviderElement(super.provider);

  @override
  String get uid => (origin as GetUserProfileProvider).uid;
}

String _$createProfileHash() => r'g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2';

/// Provider for creating user profile
///
/// Copied from [CreateProfile].
@ProviderFor(CreateProfile)
final createProfileProvider =
    AutoDisposeAsyncNotifierProvider<CreateProfile, UserEntity?>.internal(
  CreateProfile.new,
  name: r'createProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$createProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CreateProfile = AutoDisposeAsyncNotifier<UserEntity?>;
String _$updateProfileHash() => r'h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3';

/// Provider for updating user profile
///
/// Copied from [UpdateProfile].
@ProviderFor(UpdateProfile)
final updateProfileProvider =
    AutoDisposeAsyncNotifierProvider<UpdateProfile, UserEntity?>.internal(
  UpdateProfile.new,
  name: r'updateProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UpdateProfile = AutoDisposeAsyncNotifier<UserEntity?>;

// Ignore lint warnings for generated code
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

// Code for system hash
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // Jenkins hash function
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}
