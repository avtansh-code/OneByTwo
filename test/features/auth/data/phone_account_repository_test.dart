import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

/// `FirebaseAuthException` has a protected constructor; subclass for tests.
class _TestAuthException extends FirebaseAuthException {
  _TestAuthException(String code) : super(code: code, message: 'test: $code');
}

class _FakeUserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser({this.phoneNumber});

  @override
  final String? phoneNumber;

  String? reauthError;
  String? updateError;
  PhoneAuthCredential? lastUpdateCredential;
  PhoneAuthCredential? lastReauthCredential;
  int getIdTokenCalls = 0;
  bool lastForceRefresh = false;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    lastReauthCredential = credential as PhoneAuthCredential;
    if (reauthError != null) throw _TestAuthException(reauthError!);
    return _FakeUserCredential();
  }

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {
    lastUpdateCredential = phoneCredential;
    if (updateError != null) throw _TestAuthException(updateError!);
  }

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    getIdTokenCalls++;
    lastForceRefresh = forceRefresh;
    return 'token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements FirebaseAuth {
  _FakeAuth({this.fakeUser});

  _FakeUser? fakeUser;

  /// When non-null, `verifyPhoneNumber` fires `verificationFailed`.
  String? verifyFailedCode;

  /// When true, `verifyPhoneNumber` fires `verificationCompleted` (Android
  /// instant verification) instead of `codeSent`.
  bool fireInstantVerification = false;
  String verificationId = 'vid-1';

  @override
  User? get currentUser => fakeUser;

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
    if (verifyFailedCode != null) {
      verificationFailed!(_TestAuthException(verifyFailedCode!));
      return;
    }
    if (fireInstantVerification) {
      verificationCompleted!(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: '123456',
        ),
      );
      return;
    }
    codeSent!(verificationId, null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('currentPhoneNumber', () {
    test('returns the signed-in user phone', () {
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: _FakeUser(phoneNumber: '+91999')),
      );
      expect(repo.currentPhoneNumber(), '+91999');
    });

    test('returns null when there is no current user', () {
      final repo = FirebasePhoneAccountRepository(firebaseAuth: _FakeAuth());
      expect(repo.currentPhoneNumber(), isNull);
    });
  });

  group('requestOtp', () {
    test('delivers a VerificationSession via onCodeSent', () async {
      final auth = _FakeAuth(fakeUser: _FakeUser())..verificationId = 'vid-9';
      final repo = FirebasePhoneAccountRepository(firebaseAuth: auth);

      VerificationSession? session;
      AuthError? error;
      await repo.requestOtp(
        phoneNumber: '+919123456780',
        onCodeSent: (s) => session = s,
        onError: (e) => error = e,
      );

      expect(error, isNull);
      expect(session, isNotNull);
      expect(session!.verificationId, 'vid-9');
      expect(session!.phoneNumber, '+919123456780');
    });

    test('maps verificationFailed to an AuthError via onError', () async {
      final auth = _FakeAuth(fakeUser: _FakeUser())
        ..verifyFailedCode = 'too-many-requests';
      final repo = FirebasePhoneAccountRepository(firebaseAuth: auth);

      AuthError? error;
      await repo.requestOtp(
        phoneNumber: '+919123456780',
        onCodeSent: (_) {},
        onError: (e) => error = e,
      );

      expect(error, AuthError.tooManyRequests);
    });

    test('hands an instant-verification credential to onAutoRetrieved '
        'without signing in or sending a code', () async {
      final auth = _FakeAuth(fakeUser: _FakeUser())
        ..fireInstantVerification = true;
      final repo = FirebasePhoneAccountRepository(firebaseAuth: auth);

      PhoneAuthCredential? autoCred;
      var codeSentCalled = false;
      AuthError? error;
      await repo.requestOtp(
        phoneNumber: '+919123456780',
        onCodeSent: (_) => codeSentCalled = true,
        onError: (e) => error = e,
        onAutoRetrieved: (c) => autoCred = c,
      );

      expect(autoCred, isNotNull);
      expect(codeSentCalled, isFalse);
      expect(error, isNull);
    });
  });

  group('reauthenticate', () {
    test('returns null and forwards a phone credential on success', () async {
      final user = _FakeUser();
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: user),
      );

      final result = await repo.reauthenticate(
        verificationId: 'vid',
        code: '123456',
      );

      expect(result, isNull);
      expect(user.lastReauthCredential, isNotNull);
    });

    test('maps a FirebaseAuthException to an AuthError', () async {
      final user = _FakeUser()..reauthError = 'invalid-verification-code';
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: user),
      );

      final result = await repo.reauthenticate(
        verificationId: 'vid',
        code: '000000',
      );

      expect(result, AuthError.invalidOtp);
    });

    test('returns requiresRecentLogin when there is no current user', () async {
      final repo = FirebasePhoneAccountRepository(firebaseAuth: _FakeAuth());
      final result = await repo.reauthenticate(
        verificationId: 'vid',
        code: '123456',
      );
      expect(result, AuthError.requiresRecentLogin);
    });
  });

  group('updatePhoneNumber', () {
    test('returns null and calls currentUser.updatePhoneNumber', () async {
      final user = _FakeUser();
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: user),
      );

      final result = await repo.updatePhoneNumber(
        verificationId: 'vid',
        code: '654321',
      );

      expect(result, isNull);
      expect(user.lastUpdateCredential, isNotNull);
    });

    test('maps credential-already-in-use', () async {
      final user = _FakeUser()..updateError = 'credential-already-in-use';
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: user),
      );

      final result = await repo.updatePhoneNumber(
        verificationId: 'vid',
        code: '654321',
      );

      expect(result, AuthError.credentialInUse);
    });

    test('maps requires-recent-login', () async {
      final user = _FakeUser()..updateError = 'requires-recent-login';
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: user),
      );

      final result = await repo.updatePhoneNumber(
        verificationId: 'vid',
        code: '654321',
      );

      expect(result, AuthError.requiresRecentLogin);
    });

    test('returns requiresRecentLogin when there is no current user', () async {
      final repo = FirebasePhoneAccountRepository(firebaseAuth: _FakeAuth());
      final result = await repo.updatePhoneNumber(
        verificationId: 'vid',
        code: '654321',
      );
      expect(result, AuthError.requiresRecentLogin);
    });
  });

  group('refreshIdToken', () {
    test('forces a token refresh on the current user', () async {
      final user = _FakeUser();
      final repo = FirebasePhoneAccountRepository(
        firebaseAuth: _FakeAuth(fakeUser: user),
      );

      await repo.refreshIdToken();

      expect(user.getIdTokenCalls, 1);
      expect(user.lastForceRefresh, isTrue);
    });

    test('is a no-op when there is no current user', () async {
      final repo = FirebasePhoneAccountRepository(firebaseAuth: _FakeAuth());
      await repo.refreshIdToken(); // should not throw
    });
  });
}
