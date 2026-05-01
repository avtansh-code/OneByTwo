import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            final user = userCredential.user;
            if (user != null) {
              onAutoVerified(AuthUser.fromFirebaseUser(user));
            } else {
              onError(AuthError.unknown);
            }
          } on FirebaseAuthException catch (e) {
            onError(_mapException(e));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_mapException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
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
    } on FirebaseAuthException catch (e) {
      onError(_mapException(e));
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
  /// See `docs/design/07-technical/auth-error-codes.md` for the
  /// full mapping table.
  AuthError _mapException(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-phone-number' ||
      'missing-phone-number' => AuthError.invalidPhoneNumber,
      'too-many-requests' => AuthError.tooManyRequests,
      'quota-exceeded' => AuthError.quotaExceeded,
      'network-request-failed' => AuthError.networkFailure,
      'operation-not-allowed' => AuthError.operationNotAllowed,
      'app-not-authorized' => AuthError.appNotAuthorised,
      'captcha-check-failed' => AuthError.captchaFailed,
      'user-disabled' => AuthError.userDisabled,
      'invalid-verification-code' => AuthError.invalidOtp,
      'session-expired' ||
      'invalid-verification-id' => AuthError.sessionExpired,
      'credential-already-in-use' => AuthError.credentialInUse,
      _ => AuthError.unknown,
    };
  }
}

/// Riverpod provider for [PhoneAuthRepository].
///
/// Override in tests with a fake implementation to avoid Firebase
/// initialisation.
final phoneAuthRepositoryProvider = Provider<PhoneAuthRepository>(
  (ref) => FirebasePhoneAuthRepository(),
);
