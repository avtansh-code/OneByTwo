import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:one_by_two/core/errors/app_exception.dart';

/// Data source that wraps [FirebaseAuth] for phone-based OTP authentication.
///
/// All Firebase Auth interactions in the app go through this class.
/// Exceptions thrown by the Firebase SDK are caught and re-thrown as
/// [AuthException] instances for consistent error handling upstream.
class FirebaseAuthSource {
  /// Creates a [FirebaseAuthSource] backed by the given [FirebaseAuth] instance.
  FirebaseAuthSource(this._auth);

  final FirebaseAuth _auth;

  /// Stream of authentication state changes.
  ///
  /// Emits the user's UID ([String]) when signed in, or `null` when signed
  /// out. The stream fires immediately with the current state upon
  /// subscription and then on every subsequent auth state change.
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  /// The currently signed-in user's UID, or `null` if not authenticated.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Sends an OTP to [phoneNumber] via Firebase Phone Auth.
  ///
  /// [phoneNumber] must be in E.164 format (e.g., `+91XXXXXXXXXX`).
  ///
  /// Returns the `verificationId` string needed for [verifyOtp].
  ///
  /// On Android, auto-verification may complete before the user enters the
  /// code — in that case the user is signed in directly and the returned
  /// verification ID may not be used.
  ///
  /// Throws [AuthException] if the phone number is invalid, rate-limited,
  /// or another Firebase Auth error occurs.
  Future<String> sendOtp(String phoneNumber) async {
    final completer = Completer<String>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android — sign in directly.
          try {
            await _auth.signInWithCredential(credential);
          } on FirebaseAuthException catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(
                AuthException(
                  e.message ?? 'Auto-verification sign-in failed',
                  code: e.code,
                ),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(
              AuthException(
                e.message ?? 'Phone verification failed',
                code: e.code,
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timer expired. No-op — the user can still
          // manually enter the OTP.
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          AuthException(
            e.message ?? 'Failed to initiate phone verification',
            code: e.code,
          ),
        );
      }
    }

    return completer.future;
  }

  /// Verifies the [otp] against the given [verificationId] and signs in.
  ///
  /// Returns the authenticated user's UID on success.
  ///
  /// Throws [AuthException] if the OTP is invalid, expired, or another
  /// Firebase Auth error occurs.
  Future<String> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw const AuthException(
          'Sign-in succeeded but no user was returned',
          code: 'no-user',
        );
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'OTP verification failed', code: e.code);
    }
  }

  /// Signs out the currently authenticated user.
  ///
  /// Throws [AuthException] if sign-out fails.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign-out failed', code: e.code);
    }
  }

  /// Permanently deletes the current user's Firebase Auth account.
  ///
  /// This is irreversible. The caller should ensure that the user's
  /// Firestore data has been soft-deleted before calling this method.
  ///
  /// Throws [AuthException] if deletion fails (e.g., re-authentication
  /// required).
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthException(
          'No authenticated user to delete',
          code: 'no-user',
        );
      }
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Account deletion failed', code: e.code);
    }
  }
}
