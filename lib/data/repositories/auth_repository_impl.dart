import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mappers/user_mapper.dart';
import '../models/user_model.dart';

/// Implementation of AuthRepository using Firebase Auth and Firestore
/// 
/// This repository handles:
/// - Phone authentication with OTP
/// - User profile management in Firestore
/// - Auth state stream
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required firebase_auth.FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required Logger logger,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _logger = logger;

  static const _tag = 'Repo.Auth';

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final Logger _logger;

  @override
  Future<Result<String>> sendOtp(String phoneNumber) async {
    try {
      _logger.i('[$_tag] Sending OTP', error: {'phone': '${phoneNumber.substring(0, 6)}****'});

      String? verificationId;
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          // Auto-retrieval on Android - not used for manual OTP flow
          _logger.d('[$_tag] Auto-verification completed');
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          _logger.e('[$_tag] Verification failed', error: e, stackTrace: e.stackTrace);
        },
        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
          _logger.i('[$_tag] OTP sent successfully');
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId ??= verId;
          _logger.d('[$_tag] Auto-retrieval timeout');
        },
        timeout: const Duration(seconds: 60),
      );

      // Wait for codeSent callback
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (verificationId == null) {
        return const Failure(
          AuthException(
            code: 'AUTH_OTP_SEND_FAILED',
            message: 'Failed to send OTP. Please try again.',
          ),
        );
      }

      return Success(verificationId!);
    } on firebase_auth.FirebaseAuthException catch (e, stack) {
      _logger.e('[$_tag] FirebaseAuth error', error: e, stackTrace: stack);
      return Failure(_mapFirebaseAuthException(e));
    } catch (e, stack) {
      _logger.e('[$_tag] Unexpected error sending OTP', error: e, stackTrace: stack);
      return Failure(
        AuthException.operationFailed(e, stack),
      );
    }
  }

  @override
  Future<Result<UserEntity?>> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      _logger.i('[$_tag] Verifying OTP');

      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return const Failure(
          AuthException(
            code: 'AUTH_USER_NULL',
            message: 'Authentication failed. Please try again.',
          ),
        );
      }

      _logger.i('[$_tag] OTP verified successfully', error: {'uid': firebaseUser.uid});

      // Check if user profile exists in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        // Existing user - return user entity
        final userModel = UserModel.fromFirestore(userDoc);
        return Success(UserMapper.toEntity(userModel));
      } else {
        // New user - return null to indicate profile setup needed
        _logger.i('[$_tag] New user, profile setup required');
        return const Success(null);
      }
    } on firebase_auth.FirebaseAuthException catch (e, stack) {
      _logger.e('[$_tag] FirebaseAuth error during verification', error: e, stackTrace: stack);
      return Failure(_mapFirebaseAuthException(e));
    } catch (e, stack) {
      _logger.e('[$_tag] Unexpected error verifying OTP', error: e, stackTrace: stack);
      return Failure(
        AuthException.operationFailed(e, stack),
      );
    }
  }

  @override
  UserEntity? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    // Note: This returns a basic user entity from Firebase User
    // For full user profile, use a separate method that fetches from Firestore
    return UserMapper.fromFirebaseUser(firebaseUser);
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        return null;
      }
      return UserMapper.fromFirebaseUser(firebaseUser);
    });
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      _logger.i('[$_tag] Signing out user');
      await _firebaseAuth.signOut();
      return const Success(null);
    } catch (e, stack) {
      _logger.e('[$_tag] Error signing out', error: e, stackTrace: stack);
      return Failure(
        AuthException.operationFailed(e, stack),
      );
    }
  }

  @override
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Map Firebase Auth exceptions to app exceptions
  AuthException _mapFirebaseAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return const AuthException(
          code: 'AUTH_INVALID_PHONE',
          message: 'Invalid phone number. Please check and try again.',
        );
      case 'invalid-verification-code':
        return const AuthException(
          code: 'AUTH_INVALID_OTP',
          message: 'Invalid OTP. Please check and try again.',
        );
      case 'invalid-verification-id':
        return const AuthException(
          code: 'AUTH_INVALID_VERIFICATION_ID',
          message: 'Verification session expired. Please request a new OTP.',
        );
      case 'session-expired':
        return AuthException.sessionExpired();
      case 'too-many-requests':
        return const AuthException(
          code: 'AUTH_TOO_MANY_REQUESTS',
          message: 'Too many attempts. Please try again later.',
        );
      case 'user-disabled':
        return const AuthException(
          code: 'AUTH_USER_DISABLED',
          message: 'This account has been disabled.',
        );
      default:
        return AuthException(
          code: 'AUTH_ERROR_${e.code.toUpperCase()}',
          message: e.message ?? 'Authentication failed. Please try again.',
          originalError: e,
          stackTrace: e.stackTrace,
        );
    }
  }
}
