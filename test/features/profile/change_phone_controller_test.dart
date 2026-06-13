// ignore_for_file: cascade_invocations
import 'package:firebase_auth/firebase_auth.dart'
    show PhoneAuthCredential, PhoneAuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/profile/application/change_phone_controller.dart';

/// Records logged analytics events.
class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  List<String> get names => loggedEvents.map((e) => e.name).toList();

  Map<String, Object>? paramsOf(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;
}

/// Configurable fake [PhoneAccountRepository].
class FakePhoneAccountRepository implements PhoneAccountRepository {
  FakePhoneAccountRepository(this.ops);

  final List<String> ops;

  String currentNumber = '+919876543210';

  /// When non-null, `requestOtp` invokes `onError` with this.
  AuthError? requestOtpError;

  /// Session handed to `onCodeSent`; defaults to a synthetic one.
  VerificationSession? requestOtpSession;

  AuthError? reauthResult;
  AuthError? updateResult;

  final List<String> requestedPhones = [];
  String? lastReauthCode;
  String? lastUpdateCode;

  /// When set, `requestOtp` invokes `onAutoRetrieved` with this credential
  /// (simulating Android instant verification) instead of `onCodeSent`.
  PhoneAuthCredential? autoRetrievedCredential;
  PhoneAuthCredential? lastReauthCredential;
  PhoneAuthCredential? lastUpdateCredential;

  @override
  String? currentPhoneNumber() => currentNumber;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    void Function(PhoneAuthCredential credential)? onAutoRetrieved,
  }) async {
    requestedPhones.add(phoneNumber);
    if (requestOtpError != null) {
      onError(requestOtpError!);
      return;
    }
    if (autoRetrievedCredential != null) {
      onAutoRetrieved?.call(autoRetrievedCredential!);
      return;
    }
    onCodeSent(
      requestOtpSession ??
          VerificationSession(
            verificationId: 'vid-${requestedPhones.length}',
            phoneNumber: phoneNumber,
            requestedAt: DateTime(2024),
          ),
    );
  }

  @override
  Future<AuthError?> reauthenticate({
    required String verificationId,
    required String code,
  }) async {
    lastReauthCode = code;
    return reauthResult;
  }

  @override
  Future<AuthError?> reauthenticateWithCredential(
    PhoneAuthCredential credential,
  ) async {
    lastReauthCredential = credential;
    return reauthResult;
  }

  @override
  Future<AuthError?> updatePhoneNumber({
    required String verificationId,
    required String code,
  }) async {
    lastUpdateCode = code;
    return updateResult;
  }

  @override
  Future<AuthError?> updatePhoneNumberWithCredential(
    PhoneAuthCredential credential,
  ) async {
    lastUpdateCredential = credential;
    return updateResult;
  }

  @override
  Future<void> refreshIdToken() async {
    ops.add('refreshIdToken');
  }
}

/// Configurable fake [UserRepository] capturing the phone write.
class FakeUserRepository implements UserRepository {
  FakeUserRepository(this.ops);

  final List<String> ops;
  bool shouldFailPhoneWrite = false;
  int updatePhoneCallCount = 0;
  String? lastUid;
  String? lastPhone;

  @override
  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {
    updatePhoneCallCount++;
    lastUid = uid;
    lastPhone = phoneNumber;
    if (shouldFailPhoneWrite) {
      throw Exception('firestore write failed');
    }
    ops.add('firestoreWrite');
  }

  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {}

  @override
  Future<String> uploadAvatar(String uid, String filePath) async => '';

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {}

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {}

  @override
  Future<void> deleteAvatar(String uid) async {}
}

void main() {
  late FakeAnalyticsService analytics;
  late List<String> ops;
  late FakePhoneAccountRepository account;
  late FakeUserRepository users;

  const currentPhone = '+919876543210';
  const uid = 'user-1';

  ChangePhoneController build() => ChangePhoneController(
    uid: uid,
    currentPhoneNumber: currentPhone,
    analytics: analytics,
    accountRepository: account,
    userRepository: users,
  );

  setUp(() {
    analytics = FakeAnalyticsService();
    ops = [];
    account = FakePhoneAccountRepository(ops);
    users = FakeUserRepository(ops);
  });

  group('construction', () {
    test('fires phone_change_started and starts on reauthIntro', () {
      final controller = build();
      expect(controller.state.step, ChangePhoneStep.reauthIntro);
      expect(controller.state.currentPhoneNumber, currentPhone);
      expect(analytics.names, contains('phone_change_started'));
    });
  });

  group('re-authentication leg', () {
    test(
      'sendReauthOtp requests OTP for the current number and advances',
      () async {
        final controller = build();
        await controller.sendReauthOtp();

        expect(account.requestedPhones, [currentPhone]);
        expect(controller.state.step, ChangePhoneStep.reauthOtp);
        expect(controller.state.verificationId, isNotNull);
        expect(analytics.paramsOf('phone_change_otp_requested'), {
          'leg': 'reauth',
        });
      },
    );

    test('successful reauth advances to newPhoneEntry', () async {
      final controller = build();
      await controller.sendReauthOtp();
      account.reauthResult = null; // success
      await controller.submitReauthOtp('123456');

      expect(account.lastReauthCode, '123456');
      expect(controller.state.step, ChangePhoneStep.newPhoneEntry);
      expect(controller.state.errorMessage, isNull);
    });

    test(
      'wrong reauth OTP surfaces invalidOtp and stays on reauthOtp',
      () async {
        final controller = build();
        await controller.sendReauthOtp();
        account.reauthResult = AuthError.invalidOtp;
        await controller.submitReauthOtp('000000');

        expect(controller.state.step, ChangePhoneStep.reauthOtp);
        expect(controller.state.errorMessage, AuthError.invalidOtp.message);
        expect(analytics.paramsOf('phone_change_failed'), {
          'error_code': 'invalidOtp',
        });
      },
    );

    test('requiresRecentLogin during reauth surfaces its message', () async {
      final controller = build();
      await controller.sendReauthOtp();
      account.reauthResult = AuthError.requiresRecentLogin;
      await controller.submitReauthOtp('123456');

      expect(
        controller.state.errorMessage,
        AuthError.requiresRecentLogin.message,
      );
      expect(analytics.paramsOf('phone_change_failed'), {
        'error_code': 'requiresRecentLogin',
      });
    });
  });

  group('new-number entry validation', () {
    Future<ChangePhoneController> atNewPhoneEntry() async {
      final controller = build();
      await controller.sendReauthOtp();
      await controller.submitReauthOtp('123456');
      return controller;
    }

    test(
      'rejects a non-+91 / invalid number without requesting an OTP',
      () async {
        final controller = await atNewPhoneEntry();
        controller.updateNewPhone('12345');
        await controller.submitNewPhone();

        expect(controller.state.validationError, isNotNull);
        expect(controller.state.step, ChangePhoneStep.newPhoneEntry);
        // Only the reauth OTP was requested, not a new-number OTP.
        expect(account.requestedPhones, [currentPhone]);
        expect(analytics.names, isNot(contains('phone_change_failed')));
      },
    );

    test('rejects the same number as current', () async {
      final controller = await atNewPhoneEntry();
      controller.updateNewPhone('9876543210'); // == currentPhone digits
      await controller.submitNewPhone();

      expect(
        controller.state.validationError,
        'This is already your phone number.',
      );
      expect(account.requestedPhones, [currentPhone]);
      expect(analytics.names, isNot(contains('phone_change_failed')));
    });

    test('valid new number requests OTP and advances', () async {
      final controller = await atNewPhoneEntry();
      controller.updateNewPhone('9123456780');
      await controller.submitNewPhone();

      expect(account.requestedPhones, [currentPhone, '+919123456780']);
      expect(controller.state.step, ChangePhoneStep.newPhoneOtp);
      expect(analytics.paramsOf('phone_change_otp_requested'), {
        'leg': 'new_number',
      });
    });
  });

  group('new-number update leg', () {
    Future<ChangePhoneController> atNewPhoneOtp() async {
      final controller = build();
      await controller.sendReauthOtp();
      await controller.submitReauthOtp('123456');
      controller.updateNewPhone('9123456780');
      await controller.submitNewPhone();
      return controller;
    }

    test(
      'happy path: update, refresh token BEFORE firestore write, complete',
      () async {
        final controller = await atNewPhoneOtp();
        account.updateResult = null; // success
        await controller.submitNewPhoneOtp('654321');

        expect(account.lastUpdateCode, '654321');
        // Token refresh must precede the Firestore write (stale-claim order).
        expect(ops, ['refreshIdToken', 'firestoreWrite']);
        expect(users.lastUid, uid);
        expect(users.lastPhone, '+919123456780');
        expect(controller.state.step, ChangePhoneStep.success);
        expect(analytics.names, contains('phone_change_completed'));
      },
    );

    test('credential-already-in-use blocks the write', () async {
      final controller = await atNewPhoneOtp();
      account.updateResult = AuthError.credentialInUse;
      await controller.submitNewPhoneOtp('654321');

      expect(controller.state.step, ChangePhoneStep.newPhoneOtp);
      expect(controller.state.errorMessage, AuthError.credentialInUse.message);
      expect(users.updatePhoneCallCount, 0);
      expect(analytics.paramsOf('phone_change_failed'), {
        'error_code': 'credentialInUse',
      });
    });

    test(
      'firestore sync failure sets syncPending; retrySync completes',
      () async {
        final controller = await atNewPhoneOtp();
        account.updateResult = null;
        users.shouldFailPhoneWrite = true;
        await controller.submitNewPhoneOtp('654321');

        expect(controller.state.syncPending, isTrue);
        expect(controller.state.step, ChangePhoneStep.newPhoneOtp);
        expect(analytics.paramsOf('phone_change_failed'), {
          'error_code': 'sync_failed',
        });

        // Retry without re-entering an OTP.
        users.shouldFailPhoneWrite = false;
        await controller.retrySync();

        expect(controller.state.step, ChangePhoneStep.success);
        expect(controller.state.syncPending, isFalse);
        expect(analytics.names, contains('phone_change_completed'));
      },
    );
  });

  group('OTP request failure', () {
    test('reauth OTP send failure surfaces the error', () async {
      final controller = build();
      account.requestOtpError = AuthError.tooManyRequests;
      await controller.sendReauthOtp();

      expect(controller.state.step, ChangePhoneStep.reauthIntro);
      expect(controller.state.errorMessage, AuthError.tooManyRequests.message);
      expect(analytics.paramsOf('phone_change_failed'), {
        'error_code': 'tooManyRequests',
      });
    });
  });

  group('Android instant verification (no codeSent)', () {
    test('reauth leg auto-completes and advances to newPhoneEntry', () async {
      final controller = build();
      account.autoRetrievedCredential = PhoneAuthProvider.credential(
        verificationId: 'vid',
        smsCode: '123456',
      );
      account.reauthResult = null; // reauth succeeds

      await controller.sendReauthOtp();
      await Future<void>.delayed(Duration.zero); // flush unawaited handler

      // It never gets stuck loading, and advances without a manual OTP.
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.step, ChangePhoneStep.newPhoneEntry);
      expect(account.lastReauthCredential, isNotNull);
    });

    test('new-number leg auto-completes the update + sync', () async {
      final controller = build();
      // First reach newPhoneEntry via a normal reauth.
      await controller.sendReauthOtp();
      await controller.submitReauthOtp('123456');
      controller.updateNewPhone('9123456780');

      // Now the new-number OTP arrives via instant verification.
      account.autoRetrievedCredential = PhoneAuthProvider.credential(
        verificationId: 'vid',
        smsCode: '654321',
      );
      account.updateResult = null;
      await controller.submitNewPhone();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.step, ChangePhoneStep.success);
      expect(account.lastUpdateCredential, isNotNull);
      expect(ops, ['refreshIdToken', 'firestoreWrite']);
      expect(analytics.names, contains('phone_change_completed'));
    });
  });
}
