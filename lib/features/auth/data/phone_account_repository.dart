import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

/// Repository for re-verifying and mutating the CURRENT user's phone
/// credential (FR-PR-02 change-phone flow).
///
/// Deliberately separate from `PhoneAuthRepository` (sign-in) by Interface
/// Segregation: the change-phone flow must NEVER sign in or switch accounts.
/// It re-authenticates the current number and then mutates the current
/// user's phone via `currentUser.updatePhoneNumber` — not
/// `signInWithCredential`. See ADR-0015.
///
/// All operations return errors as [AuthError] values rather than throwing.
/// The verify-style operations return `null` on success.
abstract class PhoneAccountRepository {
  /// The current user's verified E.164 phone number, or `null` when there
  /// is no signed-in user.
  String? currentPhoneNumber();

  /// Requests an OTP for [phoneNumber] (E.164) for the change-phone flow.
  ///
  /// Unlike `PhoneAuthRepository.requestOtp`, this NEVER signs the user in:
  /// on Android instant verification the auto-retrieved credential is handed
  /// to [onAutoRetrieved] (so the caller can re-authenticate or update the
  /// current user with it) — it is never passed to `signInWithCredential`,
  /// which would switch the account. When [onAutoRetrieved] is omitted,
  /// auto-retrieval is ignored and entry is manual via the [onCodeSent]
  /// `verificationId`.
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    void Function(PhoneAuthCredential credential)? onAutoRetrieved,
  });

  /// Re-authenticates the current user with a phone credential built from
  /// [verificationId] and [code].
  ///
  /// Refreshes Firebase's recent-login window so a subsequent
  /// [updatePhoneNumber] does not raise `requires-recent-login`. Returns
  /// `null` on success or an [AuthError] on failure.
  Future<AuthError?> reauthenticate({
    required String verificationId,
    required String code,
  });

  /// Re-authenticates the current user with an already-retrieved
  /// [credential] (the Android instant-verification path). Returns `null`
  /// on success or an [AuthError] on failure.
  Future<AuthError?> reauthenticateWithCredential(
    PhoneAuthCredential credential,
  );

  /// Updates the current user's phone number using the credential built
  /// from [verificationId] and [code] — the mutate-current-user path
  /// (`currentUser.updatePhoneNumber`), NOT `signInWithCredential`.
  ///
  /// Returns `null` on success or an [AuthError] on failure.
  Future<AuthError?> updatePhoneNumber({
    required String verificationId,
    required String code,
  });

  /// Updates the current user's phone number using an already-retrieved
  /// [credential] (the Android instant-verification path). Returns `null`
  /// on success or an [AuthError] on failure.
  Future<AuthError?> updatePhoneNumberWithCredential(
    PhoneAuthCredential credential,
  );

  /// Forces an ID-token refresh so `request.auth.token.phone_number`
  /// reflects the NEW number before the Firestore users-doc write.
  Future<void> refreshIdToken();
}

/// Firebase implementation of [PhoneAccountRepository].
class FirebasePhoneAccountRepository implements PhoneAccountRepository {
  /// Creates a [FirebasePhoneAccountRepository].
  ///
  /// Accepts a [FirebaseAuth] instance for testability; defaults to
  /// [FirebaseAuth.instance].
  FirebasePhoneAccountRepository({FirebaseAuth? firebaseAuth})
    : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  String? currentPhoneNumber() => _auth.currentUser?.phoneNumber;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    void Function(PhoneAuthCredential credential)? onAutoRetrieved,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        // Android instant verification: hand the credential to the caller
        // (to re-authenticate / update the current user). We NEVER call
        // signInWithCredential here, which would switch the account. Without
        // this, an instant-verification number would fire no codeSent and
        // leave the flow stuck on a loading state.
        verificationCompleted: (PhoneAuthCredential credential) {
          onAutoRetrieved?.call(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(authErrorFromFirebaseCode(e.code));
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
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      onError(authErrorFromFirebaseCode(e.code));
      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      debugPrint('[PhoneAccountRepo] Unexpected requestOtp error: $e\n$st');
      onError(AuthError.unknown);
    }
  }

  @override
  Future<AuthError?> reauthenticate({
    required String verificationId,
    required String code,
  }) {
    return reauthenticateWithCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ),
    );
  }

  @override
  Future<AuthError?> reauthenticateWithCredential(
    PhoneAuthCredential credential,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return AuthError.requiresRecentLogin;
    try {
      await user.reauthenticateWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return authErrorFromFirebaseCode(e.code);
    }
  }

  @override
  Future<AuthError?> updatePhoneNumber({
    required String verificationId,
    required String code,
  }) {
    return updatePhoneNumberWithCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ),
    );
  }

  @override
  Future<AuthError?> updatePhoneNumberWithCredential(
    PhoneAuthCredential credential,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return AuthError.requiresRecentLogin;
    try {
      await user.updatePhoneNumber(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return authErrorFromFirebaseCode(e.code);
    }
  }

  @override
  Future<void> refreshIdToken() async {
    await _auth.currentUser?.getIdToken(true);
  }
}

/// Riverpod provider for [PhoneAccountRepository].
///
/// Override in tests with a fake implementation to avoid Firebase
/// initialisation.
final phoneAccountRepositoryProvider = Provider<PhoneAccountRepository>(
  (ref) => FirebasePhoneAccountRepository(),
);
