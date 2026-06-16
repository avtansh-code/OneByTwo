import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

// -- Test helpers --

/// Creates a [FirebaseAuthException] for testing.
///
/// The real constructor is `@protected`, so we use a subclass.
class TestFirebaseAuthException extends FirebaseAuthException {
  /// Creates a test exception with the given [code].
  TestFirebaseAuthException(String code)
    : super(code: code, message: 'test: $code');
}

// -- Fakes for FirebaseAuth --

/// Callback signature for the fake `verifyPhoneNumber`.
typedef FakeVerifyPhoneNumberCallback =
    Future<void> Function({
      required String phoneNumber,
      required PhoneVerificationCompleted verificationCompleted,
      required PhoneVerificationFailed verificationFailed,
      required PhoneCodeSent codeSent,
      required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
      int? forceResendingToken,
    });

/// Callback signature for the fake `signInWithCredential`.
typedef FakeSignInCallback =
    Future<UserCredential> Function(AuthCredential credential);

/// A minimal fake of [FirebaseAuth] for unit testing.
///
/// Only implements the methods used by [FirebasePhoneAuthRepository].
class FakeFirebaseAuth implements FirebaseAuth {
  /// Handler for `verifyPhoneNumber` calls.
  FakeVerifyPhoneNumberCallback? onVerifyPhoneNumber;

  /// Handler for `signInWithCredential` calls.
  FakeSignInCallback? onSignInWithCredential;

  /// The last `forceResendingToken` passed to `verifyPhoneNumber`.
  int? lastForceResendingToken;

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    int? forceResendingToken,
    PhoneMultiFactorInfo? multiFactorInfo,
    PhoneVerificationCompleted? verificationCompleted,
    PhoneVerificationFailed? verificationFailed,
    PhoneCodeSent? codeSent,
    PhoneCodeAutoRetrievalTimeout? codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 30),
    String? autoRetrievedSmsCodeForTesting,
    MultiFactorSession? multiFactorSession,
  }) async {
    lastForceResendingToken = forceResendingToken;
    await onVerifyPhoneNumber?.call(
      phoneNumber: phoneNumber ?? '',
      verificationCompleted: verificationCompleted!,
      verificationFailed: verificationFailed!,
      codeSent: codeSent!,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout!,
      forceResendingToken: forceResendingToken,
    );
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    if (onSignInWithCredential != null) {
      return onSignInWithCredential!(credential);
    }
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  // -- Stubs for unimplemented members --
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A minimal fake of [UserCredential].
class FakeUserCredential implements UserCredential {
  /// Creates a [FakeUserCredential].
  FakeUserCredential({this.user});

  @override
  final User? user;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  AuthCredential? get credential => null;
}

/// A minimal fake of [User].
class FakeUser implements User {
  /// Creates a [FakeUser].
  FakeUser({required this.uid, this.phoneNumber});

  @override
  final String uid;

  @override
  final String? phoneNumber;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseAuth fakeAuth;
  late FirebasePhoneAuthRepository repository;

  setUp(() {
    fakeAuth = FakeFirebaseAuth();
    repository = FirebasePhoneAuthRepository(firebaseAuth: fakeAuth);
  });

  group('FirebasePhoneAuthRepository', () {
    group('requestOtp', () {
      test('invokes verifyPhoneNumber with correct phone number', () async {
        String? capturedPhone;
        fakeAuth.onVerifyPhoneNumber =
            ({
              required phoneNumber,
              required verificationCompleted,
              required verificationFailed,
              required codeSent,
              required codeAutoRetrievalTimeout,
              int? forceResendingToken,
            }) async {
              capturedPhone = phoneNumber;
              codeSent('vid-123', 42);
            };

        await repository.requestOtp(
          phoneNumber: '+919876543210',
          onCodeSent: (_) {},
          onAutoVerified: (_) {},
          onError: (_) {},
        );

        expect(capturedPhone, '+919876543210');
      });

      test('codeSent callback provides VerificationSession', () async {
        fakeAuth.onVerifyPhoneNumber =
            ({
              required phoneNumber,
              required verificationCompleted,
              required verificationFailed,
              required codeSent,
              required codeAutoRetrievalTimeout,
              int? forceResendingToken,
            }) async {
              codeSent('vid-456', 99);
            };

        VerificationSession? session;
        await repository.requestOtp(
          phoneNumber: '+919876543210',
          onCodeSent: (s) => session = s,
          onAutoVerified: (_) {},
          onError: (_) {},
        );

        expect(session, isNotNull);
        expect(session!.verificationId, 'vid-456');
        expect(session!.resendToken, 99);
        expect(session!.phoneNumber, '+919876543210');
      });

      test('verificationFailed surfaces as AuthError', () async {
        fakeAuth.onVerifyPhoneNumber =
            ({
              required phoneNumber,
              required verificationCompleted,
              required verificationFailed,
              required codeSent,
              required codeAutoRetrievalTimeout,
              int? forceResendingToken,
            }) async {
              verificationFailed(
                TestFirebaseAuthException('too-many-requests'),
              );
            };

        AuthError? captured;
        await repository.requestOtp(
          phoneNumber: '+919876543210',
          onCodeSent: (_) {},
          onAutoVerified: (_) {},
          onError: (e) => captured = e,
        );

        expect(captured, AuthError.tooManyRequests);
      });
    });

    group('verifyOtp', () {
      test('with correct code returns Success<AuthUser>', () async {
        fakeAuth.onSignInWithCredential = (credential) async {
          return FakeUserCredential(
            user: FakeUser(uid: 'uid-ok', phoneNumber: '+919876543210'),
          );
        };

        final result = await repository.verifyOtp(
          verificationId: 'vid-123',
          code: '123456',
        );

        expect(result, isA<Success<AuthUser, AuthError>>());
        final success = result as Success<AuthUser, AuthError>;
        expect(success.value.uid, 'uid-ok');
        expect(success.value.phoneNumber, '+919876543210');
      });

      test('with wrong code returns Failure with invalidOtp', () async {
        fakeAuth.onSignInWithCredential = (credential) {
          throw TestFirebaseAuthException('invalid-verification-code');
        };

        final result = await repository.verifyOtp(
          verificationId: 'vid-123',
          code: '000000',
        );

        expect(result, isA<Failure<AuthUser, AuthError>>());
        final failure = result as Failure<AuthUser, AuthError>;
        expect(failure.error, AuthError.invalidOtp);
      });

      test('session-expired returns Failure with sessionExpired', () async {
        fakeAuth.onSignInWithCredential = (credential) {
          throw TestFirebaseAuthException('session-expired');
        };

        final result = await repository.verifyOtp(
          verificationId: 'vid-123',
          code: '123456',
        );

        final failure = result as Failure<AuthUser, AuthError>;
        expect(failure.error, AuthError.sessionExpired);
      });

      test('null user returns Failure with unknown', () async {
        fakeAuth.onSignInWithCredential = (credential) async {
          return FakeUserCredential();
        };

        final result = await repository.verifyOtp(
          verificationId: 'vid-123',
          code: '123456',
        );

        final failure = result as Failure<AuthUser, AuthError>;
        expect(failure.error, AuthError.unknown);
      });
    });

    group('resendOtp', () {
      test('re-invokes verifyPhoneNumber and returns new session', () async {
        fakeAuth.onVerifyPhoneNumber =
            ({
              required phoneNumber,
              required verificationCompleted,
              required verificationFailed,
              required codeSent,
              required codeAutoRetrievalTimeout,
              int? forceResendingToken,
            }) async {
              codeSent('vid-resend', 100);
            };

        VerificationSession? session;
        await repository.resendOtp(
          phoneNumber: '+919876543210',
          resendToken: 42,
          onCodeSent: (s) => session = s,
          onError: (_) {},
        );

        expect(session, isNotNull);
        expect(session!.verificationId, 'vid-resend');
        expect(session!.resendToken, 100);
      });

      test('resendOtp error surfaces as AuthError', () async {
        fakeAuth.onVerifyPhoneNumber =
            ({
              required phoneNumber,
              required verificationCompleted,
              required verificationFailed,
              required codeSent,
              required codeAutoRetrievalTimeout,
              int? forceResendingToken,
            }) async {
              verificationFailed(
                TestFirebaseAuthException('network-request-failed'),
              );
            };

        AuthError? captured;
        await repository.resendOtp(
          phoneNumber: '+919876543210',
          onCodeSent: (_) {},
          onError: (e) => captured = e,
        );

        expect(captured, AuthError.networkFailure);
      });

      test('resendOtp passes forceResendingToken to '
          'verifyPhoneNumber', () async {
        fakeAuth.onVerifyPhoneNumber =
            ({
              required phoneNumber,
              required verificationCompleted,
              required verificationFailed,
              required codeSent,
              required codeAutoRetrievalTimeout,
              int? forceResendingToken,
            }) async {
              codeSent('vid-token', 200);
            };

        await repository.resendOtp(
          phoneNumber: '+919876543210',
          resendToken: 42,
          onCodeSent: (_) {},
          onError: (_) {},
        );

        expect(fakeAuth.lastForceResendingToken, 42);
      });
    });

    group('error code mapping', () {
      final codeToError = {
        'invalid-phone-number': AuthError.invalidPhoneNumber,
        'missing-phone-number': AuthError.invalidPhoneNumber,
        'too-many-requests': AuthError.tooManyRequests,
        'quota-exceeded': AuthError.quotaExceeded,
        'network-request-failed': AuthError.networkFailure,
        'operation-not-allowed': AuthError.operationNotAllowed,
        'app-not-authorized': AuthError.appNotAuthorised,
        'captcha-check-failed': AuthError.captchaFailed,
        'user-disabled': AuthError.userDisabled,
        'invalid-verification-code': AuthError.invalidOtp,
        'session-expired': AuthError.sessionExpired,
        'invalid-verification-id': AuthError.sessionExpired,
        'credential-already-in-use': AuthError.credentialInUse,
        'requires-recent-login': AuthError.requiresRecentLogin,
        'user-mismatch': AuthError.requiresRecentLogin,
        'internal-error': AuthError.unknown,
        'some-unknown-code': AuthError.unknown,
      };

      for (final entry in codeToError.entries) {
        test('Firebase code "${entry.key}" maps to '
            '${entry.value}', () async {
          fakeAuth.onSignInWithCredential = (credential) {
            throw TestFirebaseAuthException(entry.key);
          };

          final result = await repository.verifyOtp(
            verificationId: 'vid',
            code: '123456',
          );

          final failure = result as Failure<AuthUser, AuthError>;
          expect(failure.error, entry.value);
        });
      }
    });
  });
}
