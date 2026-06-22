import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

/// Abstract interface for phone authentication operations.
///
/// Provides a platform-agnostic API over Firebase Phone Auth.
/// All errors are returned as [AuthError] values rather than thrown.
abstract class PhoneAuthRepository {
  /// Requests an OTP for the given [phoneNumber] (E.164 format).
  ///
  /// On success, invokes [onCodeSent] with a [VerificationSession].
  /// On Android, may invoke [onAutoVerified] if the SMS Retriever
  /// auto-reads the code.
  /// On failure, invokes [onError] with the mapped [AuthError].
  /// When auto-retrieval times out, invokes [onAutoRetrievalTimeout]
  /// if provided.
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  });

  /// Verifies the OTP [code] against the given [verificationId].
  ///
  /// Returns [Success] with an [AuthUser] on success, or [Failure]
  /// with an [AuthError] on failure.
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  });

  /// Resends the OTP for an existing verification session.
  ///
  /// Accepts the [resendToken] from the previous [VerificationSession]
  /// (may be `null` on iOS).
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  });

  /// Signs the current user out.
  Future<void> signOut();
}

/// Firebase implementation of [PhoneAuthRepository].
///
/// Uses `verifyPhoneNumber` (not `signInWithPhoneNumber`, which is
/// web-only) on both Android and iOS.
class FirebasePhoneAuthRepository implements PhoneAuthRepository {
  /// Creates a [FirebasePhoneAuthRepository].
  ///
  /// Accepts a [FirebaseAuth] instance for testability; defaults to
  /// [FirebaseAuth.instance].
  FirebasePhoneAuthRepository({FirebaseAuth? firebaseAuth})
    : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {
    try {
      debugPrint('[PhoneAuthRepo] requestOtp called for $phoneNumber');
      debugPrint('[PhoneAuthRepo] Calling verifyPhoneNumber...');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[PhoneAuthRepo] verificationCompleted callback');
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            final user = userCredential.user;
            if (user != null) {
              onAutoVerified(AuthUser.fromFirebaseUser(user));
            } else {
              onError(AuthError.unknown);
            }
          } on FirebaseAuthException catch (e) {
            debugPrint('[PhoneAuthRepo] signIn error: ${e.code}');
            onError(_mapException(e));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
            '[PhoneAuthRepo] verificationFailed: ${e.code} '
            '${e.message}',
          );
          onError(_mapException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[PhoneAuthRepo] codeSent: vid=$verificationId');
          onCodeSent(
            VerificationSession(
              verificationId: verificationId,
              phoneNumber: phoneNumber,
              resendToken: resendToken,
              requestedAt: DateTime.now(),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {
          // Auto-retrieval timed out (Android). The verificationId
          // from codeSent remains valid for manual entry.
          onAutoRetrievalTimeout?.call();
        },
      );
      debugPrint('[PhoneAuthRepo] verifyPhoneNumber returned');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[PhoneAuthRepo] FirebaseAuthException: ${e.code} '
        '${e.message}',
      );
      onError(_mapException(e));
      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      debugPrint('[PhoneAuthRepo] Unexpected error: $e');
      debugPrint('[PhoneAuthRepo] Stack trace: $st');
      onError(AuthError.unknown);
    }
  }

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return const Failure(AuthError.unknown);
      }
      return Success(AuthUser.fromUserCredential(userCredential));
    } on FirebaseAuthException catch (e) {
      return Failure(_mapException(e));
    }
  }

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (_) {
          // Resend path does not auto-verify.
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_mapException(e));
        },
        codeSent: (String verificationId, int? newResendToken) {
          onCodeSent(
            VerificationSession(
              verificationId: verificationId,
              phoneNumber: phoneNumber,
              resendToken: newResendToken,
              requestedAt: DateTime.now(),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      onError(_mapException(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Maps a [FirebaseAuthException] to a domain [AuthError].
  ///
  /// Delegates to [authErrorFromFirebaseCode], the single source of truth
  /// for the mapping. See `docs/design/07-technical/auth-error-codes.md`
  /// for the full mapping table.
  AuthError _mapException(FirebaseAuthException e) =>
      authErrorFromFirebaseCode(e.code);
}
