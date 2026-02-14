import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../local/dao/user_dao.dart';
import '../mappers/user_mapper.dart';
import '../models/user_model.dart';
import '../remote/firestore/user_firestore_source.dart';

/// Implementation of UserRepository
/// 
/// Follows offline-first pattern:
/// - Writes go to local DB first (< 500ms), then sync to Firestore
/// - Reads come from local DB (instant)
/// - Firestore listeners update local DB in background
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    required firebase_auth.FirebaseAuth firebaseAuth,
    required UserDao userDao,
    required UserFirestoreSource firestoreSource,
    required Logger logger,
  })  : _firebaseAuth = firebaseAuth,
        _userDao = userDao,
        _firestoreSource = firestoreSource,
        _logger = logger;

  static const _tag = 'Repo.User';

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final UserDao _userDao;
  final UserFirestoreSource _firestoreSource;
  final Logger _logger;

  @override
  Future<Result<UserEntity>> createProfile({
    required String name,
    required String email,
    String? avatarUrl,
  }) async {
    try {
      // Validate inputs
      final trimmedName = name.trim();
      final trimmedEmail = email.trim();
      
      if (trimmedName.isEmpty) {
        return const Failure(
          ValidationException(
            code: 'INVALID_NAME',
            message: 'Name cannot be empty',
          ),
        );
      }
      
      if (trimmedEmail.isEmpty) {
        return const Failure(
          ValidationException(
            code: 'INVALID_EMAIL',
            message: 'Email cannot be empty',
          ),
        );
      }
      
      // Basic email validation
      if (!_isValidEmail(trimmedEmail)) {
        return const Failure(
          ValidationException(
            code: 'INVALID_EMAIL',
            message: 'Please enter a valid email address',
          ),
        );
      }

      // Get current user from Firebase Auth
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Failure(
          AuthException(
            code: 'AUTH_NOT_AUTHENTICATED',
            message: 'User not authenticated. Please sign in again.',
          ),
        );
      }

      _logger.i(
        '[$_tag] Creating profile',
        error: {'uid': firebaseUser.uid},
      );

      final now = DateTime.now();
      final userModel = UserModel(
        uid: firebaseUser.uid,
        name: trimmedName,
        email: trimmedEmail,
        phone: firebaseUser.phoneNumber ?? '',
        avatarUrl: avatarUrl,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Save to local DB first (offline-first)
      await _userDao.insertUser(userModel);
      await _userDao.setCurrentUser(firebaseUser.uid);

      // 2. Sync to Firestore asynchronously (don't await - fire and forget)
      // ignore: unawaited_futures
      _syncToFirestore(userModel);

      _logger.i(
        '[$_tag] Profile created successfully',
        error: {'uid': firebaseUser.uid},
      );

      return Success(UserMapper.toEntity(userModel));
    } on AppException catch (e) {
      _logger.e('[$_tag] AppException creating profile', error: e);
      return Failure(e);
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Unexpected error creating profile',
        error: e,
        stackTrace: stack,
      );
      return Failure(
        DatabaseException.operationFailed(e, stack),
      );
    }
  }

  @override
  Future<Result<UserEntity>> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  }) async {
    try {
      // Get current user
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Failure(
          AuthException(
            code: 'AUTH_NOT_AUTHENTICATED',
            message: 'User not authenticated. Please sign in again.',
          ),
        );
      }

      _logger.i(
        '[$_tag] Updating profile',
        error: {'uid': firebaseUser.uid},
      );

      // Fetch existing profile from local DB
      final existingUser = await _userDao.getUserById(firebaseUser.uid);
      if (existingUser == null) {
        return const Failure(
          DatabaseException(
            code: 'USER_NOT_FOUND',
            message: 'User profile not found. Please create profile first.',
          ),
        );
      }

      // Validate and apply updates
      String updatedName = existingUser.name;
      String updatedEmail = existingUser.email;
      String? updatedAvatarUrl = existingUser.avatarUrl;

      if (name != null) {
        final trimmedName = name.trim();
        if (trimmedName.isEmpty) {
          return const Failure(
            ValidationException(
              code: 'INVALID_NAME',
              message: 'Name cannot be empty',
            ),
          );
        }
        updatedName = trimmedName;
      }

      if (email != null) {
        final trimmedEmail = email.trim();
        if (trimmedEmail.isEmpty) {
          return const Failure(
            ValidationException(
              code: 'INVALID_EMAIL',
              message: 'Email cannot be empty',
            ),
          );
        }
        if (!_isValidEmail(trimmedEmail)) {
          return const Failure(
            ValidationException(
              code: 'INVALID_EMAIL',
              message: 'Please enter a valid email address',
            ),
          );
        }
        updatedEmail = trimmedEmail;
      }

      if (avatarUrl != null) {
        updatedAvatarUrl = avatarUrl;
      }

      // Create updated user model
      final updatedUser = UserModel(
        uid: existingUser.uid,
        name: updatedName,
        email: updatedEmail,
        phone: existingUser.phone,
        avatarUrl: updatedAvatarUrl,
        language: existingUser.language,
        createdAt: existingUser.createdAt,
        updatedAt: DateTime.now(),
      );

      // 1. Update local DB first (offline-first)
      await _userDao.updateUser(updatedUser);

      // 2. Sync to Firestore asynchronously
      // ignore: unawaited_futures
      _syncToFirestore(updatedUser);

      _logger.i(
        '[$_tag] Profile updated successfully',
        error: {'uid': firebaseUser.uid},
      );

      return Success(UserMapper.toEntity(updatedUser));
    } on AppException catch (e) {
      _logger.e('[$_tag] AppException updating profile', error: e);
      return Failure(e);
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Unexpected error updating profile',
        error: e,
        stackTrace: stack,
      );
      return Failure(
        DatabaseException.operationFailed(e, stack),
      );
    }
  }

  @override
  Future<Result<UserEntity?>> getUserProfile(String uid) async {
    try {
      _logger.d('[$_tag] Getting user profile', error: {'uid': uid});

      // Try local DB first
      final localUser = await _userDao.getUserById(uid);
      if (localUser != null) {
        return Success(UserMapper.toEntity(localUser));
      }

      // Not in local DB, try Firestore
      _logger.d('[$_tag] User not in local DB, fetching from Firestore');
      final firestoreUser = await _firestoreSource.getUserProfile(uid);
      
      if (firestoreUser != null) {
        // Save to local DB for next time
        await _userDao.insertUser(firestoreUser);
        return Success(UserMapper.toEntity(firestoreUser));
      }

      // User not found anywhere
      return const Success(null);
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error getting user profile',
        error: e,
        stackTrace: stack,
      );
      return Failure(
        DatabaseException.operationFailed(e, stack),
      );
    }
  }

  @override
  Future<Result<UserEntity?>> getCurrentUserProfile() async {
    try {
      _logger.d('[$_tag] Getting current user profile');

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return const Success(null);
      }

      // Get from local DB
      final localUser = await _userDao.getCurrentUser();
      if (localUser != null) {
        return Success(UserMapper.toEntity(localUser));
      }

      // Not in local DB, try Firestore
      _logger.d('[$_tag] Current user not in local DB, fetching from Firestore');
      final firestoreUser = await _firestoreSource.getUserProfile(firebaseUser.uid);
      
      if (firestoreUser != null) {
        // Save to local DB
        await _userDao.insertUser(firestoreUser);
        await _userDao.setCurrentUser(firebaseUser.uid);
        return Success(UserMapper.toEntity(firestoreUser));
      }

      // User authenticated but no profile - needs profile setup
      return const Success(null);
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error getting current user profile',
        error: e,
        stackTrace: stack,
      );
      return Failure(
        DatabaseException.operationFailed(e, stack),
      );
    }
  }

  @override
  Stream<UserEntity?> watchCurrentUserProfile() {
    try {
      _logger.d('[$_tag] Watching current user profile');

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        return Stream<UserEntity?>.value(null);
      }

      // For now, return a simple stream
      // In a full implementation, this would listen to local DB changes
      return Stream<void>.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final user = await _userDao.getCurrentUser();
        return user != null ? UserMapper.toEntity(user) : null;
      });
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error watching current user profile',
        error: e,
        stackTrace: stack,
      );
      return Stream<UserEntity?>.error(e, stack);
    }
  }

  /// Sync user to Firestore asynchronously
  /// 
  /// Errors are logged but not propagated (offline-first)
  Future<void> _syncToFirestore(UserModel user) async {
    try {
      _logger.d('[$_tag] Syncing user to Firestore');
      await _firestoreSource.updateUserProfile(user);
      _logger.i('[$_tag] User synced to Firestore');
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Failed to sync user to Firestore',
        error: e,
        stackTrace: stack,
      );
      // Don't rethrow - offline-first means local DB is source of truth
    }
  }

  /// Basic email validation
  bool _isValidEmail(String email) {
    // Basic RFC 5322 email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );
    return emailRegex.hasMatch(email);
  }
}
