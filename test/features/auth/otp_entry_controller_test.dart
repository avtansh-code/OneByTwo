// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/otp_entry_controller.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged as `(name, parameters)` tuples.
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }
}

/// Fake [PhoneAuthRepository] with configurable behaviour.
class FakePhoneAuthRepository implements PhoneAuthRepository {
  /// When non-null, [verifyOtp] returns this result.
  Result<AuthUser, AuthError>? verifyOtpResult;

  /// When non-null, [resendOtp] invokes `onCodeSent` with this.
  VerificationSession? resendOtpSession;

  /// When non-null, [resendOtp] invokes `onError` with this.
  AuthError? resendOtpError;

  /// Number of times [verifyOtp] was called.
  int verifyOtpCallCount = 0;

  /// Number of times [resendOtp] was called.
  int resendOtpCallCount = 0;

  /// Last verification ID passed to [verifyOtp].
  String? lastVerifyVerificationId;

  /// Last code passed to [verifyOtp].
  String? lastVerifyCode;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {}

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    verifyOtpCallCount++;
    lastVerifyVerificationId = verificationId;
    lastVerifyCode = code;
    return verifyOtpResult ?? const Failure(AuthError.unknown);
  }

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {
    resendOtpCallCount++;
    if (resendOtpError != null) {
      onError(resendOtpError!);
      return;
    }
    if (resendOtpSession != null) {
      onCodeSent(resendOtpSession!);
    }
  }

  @override
  Future<void> signOut() async {}
}

/// A [PhoneAuthRepository] whose `resendOtp` never completes.
///
/// Used to test concurrent-call protection by keeping the controller
/// in the loading state indefinitely.
class _SlowPhoneAuthRepository implements PhoneAuthRepository {
  /// Number of times [resendOtp] was called.
  int resendOtpCallCount = 0;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {}

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    return const Failure(AuthError.unknown);
  }

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) {
    resendOtpCallCount++;
    // Never completes -- keeps the controller in isLoading state.
    return Completer<void>().future;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakePhoneAuthRepository fakeRepository;
  late OtpEntryController controller;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakePhoneAuthRepository();
    controller = OtpEntryController(
      analytics: fakeAnalytics,
      repository: fakeRepository,
      phoneNumber: '9876543210',
      verificationId: 'vid-test',
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('OtpEntryController', () {
    test('initial state has empty digits and isComplete is false', () {
      expect(controller.state.isComplete, isFalse);
      expect(controller.state.digits, everyElement(''));
      expect(controller.state.digits.length, 6);
    });

    test('isComplete is false when fewer than 6 digits are entered', () {
      controller.setDigit(0, '1');
      controller.setDigit(1, '2');
      controller.setDigit(2, '3');
      expect(controller.state.isComplete, isFalse);
    });

    test('isComplete is true when exactly 6 digits are entered', () {
      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      expect(controller.state.isComplete, isTrue);
    });

    test('pasteOtp fills all cells with a 6-digit string', () {
      controller.pasteOtp('123456');
      expect(controller.state.digits, ['1', '2', '3', '4', '5', '6']);
      expect(controller.state.isComplete, isTrue);
    });

    test('pasteOtp rejects non-numeric strings', () {
      controller.pasteOtp('12345a');
      expect(controller.state.digits, everyElement(''));
      expect(controller.state.isComplete, isFalse);
    });

    test('pasteOtp rejects strings that are not exactly 6 characters', () {
      controller.pasteOtp('12345');
      expect(controller.state.digits, everyElement(''));

      controller.pasteOtp('1234567');
      expect(controller.state.digits, everyElement(''));
    });

    test('submit is a no-op when OTP is incomplete', () async {
      controller.setDigit(0, '1');
      await controller.submit();
      expect(controller.state.isSubmitted, isFalse);
    });

    test('successful verifyOtp sets isAuthenticated', () async {
      fakeRepository.verifyOtpResult = const Success(
        AuthUser(uid: 'uid-123', phoneNumber: '+919876543210'),
      );

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.authenticatedUser?.uid, 'uid-123');
      expect(controller.state.isLoading, isFalse);
    });

    test('failed verifyOtp sets validationError with domain message', () async {
      fakeRepository.verifyOtpResult = const Failure(AuthError.invalidOtp);

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      expect(controller.state.validationError, AuthError.invalidOtp.message);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.isLoading, isFalse);
      // Digits should be cleared on failure.
      expect(controller.state.digits, everyElement(''));
    });

    test(
      'failed verifyOtp with sessionExpired shows correct message',
      () async {
        fakeRepository.verifyOtpResult = const Failure(
          AuthError.sessionExpired,
        );

        for (var i = 0; i < 6; i++) {
          controller.setDigit(i, '${i + 1}');
        }
        await controller.submit();

        expect(
          controller.state.validationError,
          AuthError.sessionExpired.message,
        );
      },
    );

    test('submit passes correct verificationId and code', () async {
      fakeRepository.verifyOtpResult = const Success(AuthUser(uid: 'uid-123'));

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      expect(fakeRepository.lastVerifyVerificationId, 'vid-test');
      expect(fakeRepository.lastVerifyCode, '123456');
    });

    test('submit logs signup_otp_submitted telemetry', () async {
      fakeRepository.verifyOtpResult = const Success(AuthUser(uid: 'uid-123'));

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'signup_otp_submitted'),
        isTrue,
      );
    });

    test('otp_verification_succeeded telemetry fires on success', () async {
      fakeRepository.verifyOtpResult = const Success(AuthUser(uid: 'uid-123'));

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'otp_verification_succeeded',
      );
      expect(event.parameters, containsPair('duration_ms', isA<int>()));
    });

    test('otp_verification_failed telemetry fires on failure', () async {
      fakeRepository.verifyOtpResult = const Failure(AuthError.invalidOtp);

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'otp_verification_failed',
      );
      expect(event.parameters, containsPair('error_code', 'invalidOtp'));
    });

    test('clearDigit clears the specified cell', () {
      controller.setDigit(0, '1');
      controller.setDigit(1, '2');
      controller.clearDigit(1);
      expect(controller.state.digits[1], '');
    });

    test('initial remainingSeconds is 30', () {
      expect(controller.state.remainingSeconds, 30);
    });

    test('canResend is false initially', () {
      expect(controller.state.canResend, isFalse);
    });

    test('resend countdown decreases by 1 per second', () async {
      controller.startResendTimer();

      await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));

      expect(controller.state.remainingSeconds, lessThanOrEqualTo(28));
    });

    test('canResend becomes true when countdown reaches zero', () async {
      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: fakeRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 2,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 200));

      expect(fastController.state.canResend, isTrue);
      expect(fastController.state.remainingSeconds, 0);
    });

    test('resend calls resendOtp and updates state on success', () async {
      fakeRepository.resendOtpSession = VerificationSession(
        verificationId: 'vid-resend',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: fakeRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
      expect(fastController.state.canResend, isTrue);

      await fastController.resend();

      expect(fastController.state.resendCount, 1);
      expect(fastController.state.remainingSeconds, 1);
      expect(fastController.state.canResend, isFalse);
      expect(fastController.state.verificationId, 'vid-resend');
      expect(fakeRepository.resendOtpCallCount, 1);
    });

    test('resend logs otp_resend_tapped telemetry', () async {
      fakeRepository.resendOtpSession = VerificationSession(
        verificationId: 'vid-resend',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: fakeRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));

      await fastController.resend();
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'otp_resend_tapped' &&
              e.parameters?['attempt_number'] == 1,
        ),
        isTrue,
      );
    });

    test('resend is no-op when canResend is false', () async {
      await controller.resend();
      expect(controller.state.resendCount, 0);
    });

    test('resend enforces 3-per-10-min sliding window '
        'and fires otp_resend_exhausted', () async {
      fakeRepository.resendOtpSession = VerificationSession(
        verificationId: 'vid-resend',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: fakeRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      // Perform 3 resends.
      for (var i = 0; i < 3; i++) {
        fastController.startResendTimer();
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 200),
        );
        await fastController.resend();
      }

      expect(fastController.state.resendCount, 3);

      // Wait for timer and try 4th resend.
      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));

      await fastController.resend();

      // 4th resend should be blocked.
      expect(fastController.state.resendCount, 3);
      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'otp_resend_exhausted'),
        isTrue,
      );
    });

    test('handleAutoVerification sets isAuthenticated and fires '
        'otp_auto_read_succeeded', () {
      const user = AuthUser(uid: 'uid-auto', phoneNumber: '+919876543210');

      controller.handleAutoVerification(user);

      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.authenticatedUser?.uid, 'uid-auto');
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'otp_auto_read_succeeded',
        ),
        isTrue,
      );
    });

    test('otp_screen_viewed is logged at construction with '
        'hashed phone', () {
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'signup_otp_screen_viewed' &&
              e.parameters != null &&
              e.parameters!.containsKey('phone_hash') &&
              e.parameters!['phone_hash'] != '9876543210',
        ),
        isTrue,
      );
    });

    test('digits list is unmodifiable', () {
      expect(() => controller.state.digits.add('7'), throwsUnsupportedError);
    });

    test('verificationId is set from constructor', () {
      expect(controller.state.verificationId, 'vid-test');
    });

    test('resend failure restores canResend to true', () async {
      fakeRepository.resendOtpError = AuthError.networkFailure;

      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: fakeRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
      expect(fastController.state.canResend, isTrue);

      await fastController.resend();

      expect(fastController.state.canResend, isTrue);
      expect(fastController.state.isLoading, isFalse);
      expect(
        fastController.state.validationError,
        AuthError.networkFailure.message,
      );
      // The failed timestamp should be removed, so resendCount
      // stays at 0 (the increment only happens on success).
      expect(fastController.state.resendCount, 0);
    });

    test('resend allows attempt after 10-minute window '
        'expires', () async {
      // Start at an arbitrary fixed time.
      var fakeNow = DateTime(2025);
      DateTime fakeClock() => fakeNow;

      fakeRepository.resendOtpSession = VerificationSession(
        verificationId: 'vid-resend',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: fakeRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 1,
        clock: fakeClock,
      );
      addTearDown(fastController.dispose);

      // Perform 3 resends at time T.
      for (var i = 0; i < 3; i++) {
        fastController.startResendTimer();
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 200),
        );
        await fastController.resend();
      }

      expect(fastController.state.resendCount, 3);

      // Advance clock past the 10-minute window.
      fakeNow = fakeNow.add(const Duration(minutes: 11));

      // Wait for countdown then try 4th resend.
      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
      await fastController.resend();

      // 4th resend should succeed because old timestamps
      // are pruned.
      expect(fastController.state.resendCount, 4);
    });

    test('resend is a no-op when isLoading is true', () async {
      // Use a slow repository that never completes within
      // the test so that isLoading stays true.
      final slowRepository = _SlowPhoneAuthRepository();

      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        repository: slowRepository,
        phoneNumber: '9876543210',
        verificationId: 'vid-fast',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
      expect(fastController.state.canResend, isTrue);

      // Start a resend (will not complete because the
      // repository never calls its callbacks).
      unawaited(fastController.resend());
      // Allow the microtask to set isLoading.
      await Future<void>.delayed(Duration.zero);

      expect(fastController.state.isLoading, isTrue);

      // A second resend call should be a no-op.
      await fastController.resend();
      expect(slowRepository.resendOtpCallCount, 1);
    });

    test('otp_verification_succeeded telemetry includes '
        'is_new_user', () async {
      fakeRepository.verifyOtpResult = const Success(
        AuthUser(uid: 'uid-new', phoneNumber: '+919876543210', isNewUser: true),
      );

      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'otp_verification_succeeded',
      );
      expect(event.parameters, containsPair('is_new_user', true));
    });
  });
}
