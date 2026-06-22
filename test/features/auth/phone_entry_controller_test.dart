// ignore_for_file: cascade_invocations
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/phone_entry_controller.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

/// Fake [AnalyticsService] that records logged events.
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
  /// When non-null, [requestOtp] invokes `onCodeSent` with this
  /// session.
  VerificationSession? requestOtpSession;

  /// When non-null, [requestOtp] invokes `onError` with this error.
  AuthError? requestOtpError;

  /// When non-null, [requestOtp] invokes `onAutoVerified`.
  AuthUser? requestOtpAutoVerifiedUser;

  /// When non-null, [verifyOtp] returns this result.
  Result<AuthUser, AuthError>? verifyOtpResult;

  /// Captured phone number from the last [requestOtp] call.
  String? lastRequestedPhoneNumber;

  /// Number of times [requestOtp] was called.
  int requestOtpCallCount = 0;

  /// When `true`, [requestOtp] invokes `onAutoRetrievalTimeout` after the
  /// primary callback, simulating Android auto-read expiry.
  bool fireAutoRetrievalTimeout = false;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {
    lastRequestedPhoneNumber = phoneNumber;
    requestOtpCallCount++;
    if (requestOtpAutoVerifiedUser != null) {
      onAutoVerified(requestOtpAutoVerifiedUser!);
    } else if (requestOtpError != null) {
      onError(requestOtpError!);
    } else if (requestOtpSession != null) {
      onCodeSent(requestOtpSession!);
    }
    if (fireAutoRetrievalTimeout) {
      onAutoRetrievalTimeout?.call();
    }
  }

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    return verifyOtpResult ?? const Failure(AuthError.unknown);
  }

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {}

  @override
  Future<void> signOut() async {}
}

/// A [PhoneAuthRepository] whose `requestOtp` never completes.
///
/// Keeps the controller pinned in the loading state so a concurrent
/// second submit can be observed (SC1). Mirrors the
/// `_SlowPhoneAuthRepository` pattern in otp_entry_controller_test.dart.
class _SlowPhoneAuthRepository implements PhoneAuthRepository {
  /// Number of times [requestOtp] was called.
  int requestOtpCallCount = 0;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) {
    requestOtpCallCount++;
    // Never completes -- keeps the controller in the isLoading state.
    return Completer<void>().future;
  }

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async => const Failure(AuthError.unknown);

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakePhoneAuthRepository fakeRepository;
  late PhoneEntryController controller;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakePhoneAuthRepository();
    controller = PhoneEntryController(
      analytics: fakeAnalytics,
      repository: fakeRepository,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('PhoneEntryController', () {
    test('initial state has empty phone number and no error', () {
      expect(controller.state.phoneNumber, '');
      expect(controller.state.validationError, isNull);
      expect(controller.state.isSubmitted, isFalse);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.verificationSession, isNull);
    });

    test('updatePhoneNumber updates digits and clears error', () {
      controller.updatePhoneNumber('9876543210');
      expect(controller.state.phoneNumber, '9876543210');
      expect(controller.state.validationError, isNull);
    });

    test('submit with invalid number sets validation error', () async {
      controller.updatePhoneNumber('12345');
      await controller.submit();
      expect(controller.state.validationError, isNotNull);
      expect(controller.state.isSubmitted, isFalse);
    });

    test('successful requestOtp sets verificationSession', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(controller.state.verificationSession, isNotNull);
      expect(controller.state.verificationSession!.verificationId, 'vid-123');
      expect(controller.state.isSubmitted, isTrue);
      expect(controller.state.isLoading, isFalse);
    });

    test('requestOtp passes E.164 formatted phone number', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(fakeRepository.lastRequestedPhoneNumber, '+919876543210');
    });

    test('failed requestOtp sets otpSendError with '
        'AuthError message', () async {
      fakeRepository.requestOtpError = AuthError.tooManyRequests;

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(controller.state.otpSendError, AuthError.tooManyRequests.message);
      expect(controller.state.validationError, isNull);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.verificationSession, isNull);
    });

    test('failed requestOtp with networkFailure shows correct '
        'message', () async {
      fakeRepository.requestOtpError = AuthError.networkFailure;

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(controller.state.otpSendError, AuthError.networkFailure.message);
    });

    test('signup_started telemetry fires before Firebase call', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'signup_started'),
        isTrue,
      );
    });

    test('otp_send_succeeded telemetry fires on success', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'otp_send_succeeded',
      );
      expect(event.parameters, containsPair('duration_ms', isA<int>()));
    });

    test('otp_send_failed telemetry fires on failure', () async {
      fakeRepository.requestOtpError = AuthError.tooManyRequests;

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'otp_send_failed',
      );
      expect(event.parameters, containsPair('error_code', 'tooManyRequests'));
    });

    test('loading state is set during async operation', () async {
      // Use a session so requestOtp completes.
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');

      // After submit completes, loading should be false.
      await controller.submit();
      expect(controller.state.isLoading, isFalse);
    });

    test('auto-verification sets autoVerifiedUser', () async {
      fakeRepository.requestOtpAutoVerifiedUser = const AuthUser(
        uid: 'uid-auto',
        phoneNumber: '+919876543210',
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(controller.state.autoVerifiedUser, isNotNull);
      expect(controller.state.autoVerifiedUser!.uid, 'uid-auto');
    });

    test('signup_started fires before otp_send_succeeded', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      final eventNames = fakeAnalytics.loggedEvents.map((e) => e.name).toList();
      final startedIndex = eventNames.indexOf('signup_started');
      final succeededIndex = eventNames.indexOf('otp_send_succeeded');

      expect(startedIndex, greaterThanOrEqualTo(0));
      expect(succeededIndex, greaterThanOrEqualTo(0));
      expect(startedIndex, lessThan(succeededIndex));
    });

    test('phone_validation_failed fires with too_short reason', () async {
      controller.updatePhoneNumber('12345');
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'phone_validation_failed',
      );
      expect(event.parameters, containsPair('reason', 'too_short'));
    });

    test('phone_validation_failed fires with invalid_prefix reason', () async {
      // 10 digits but starts with 5 (not 6-9).
      controller.updatePhoneNumber('5678901234');
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'phone_validation_failed',
      );
      expect(event.parameters, containsPair('reason', 'invalid_prefix'));
    });

    test('phone_validation_failed labels >10 digits as '
        'invalid_prefix', () async {
      // Defensive: the UI caps input at 10, but a direct caller could
      // pass more; a >10-digit value must not be mislabelled too_short.
      controller.updatePhoneNumber('123456789012');
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'phone_validation_failed',
      );
      expect(event.parameters, containsPair('reason', 'invalid_prefix'));
    });

    test('otp_send_requested fires between signup_started and send', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      final eventNames = fakeAnalytics.loggedEvents.map((e) => e.name).toList();
      expect(eventNames, contains('otp_send_requested'));
      expect(
        eventNames.indexOf('otp_send_requested'),
        greaterThan(eventNames.indexOf('signup_started')),
      );
      expect(
        eventNames.indexOf('otp_send_requested'),
        lessThan(eventNames.indexOf('otp_send_succeeded')),
      );
    });

    test('updatePhoneNumber strips display-formatting space', () {
      controller.updatePhoneNumber('98765 43210');
      expect(controller.state.phoneNumber, '9876543210');
    });
  });

  group('PhoneEntryController concurrent-submit guard (SC1)', () {
    late _SlowPhoneAuthRepository slowRepository;
    late PhoneEntryController slowController;

    setUp(() {
      slowRepository = _SlowPhoneAuthRepository();
      slowController = PhoneEntryController(
        analytics: fakeAnalytics,
        repository: slowRepository,
      );
    });

    tearDown(() {
      slowController.dispose();
    });

    test('a second submit while an OTP request is in flight is '
        'ignored', () async {
      slowController.updatePhoneNumber('9876543210');

      // First submit pins the controller in the loading state because the
      // slow repository's requestOtp never completes.
      unawaited(slowController.submit());
      await Future<void>.delayed(Duration.zero);
      expect(slowController.state.isLoading, isTrue);
      expect(slowRepository.requestOtpCallCount, 1);

      // A rapid second tap must NOT fire a duplicate requestOtp.
      unawaited(slowController.submit());
      await Future<void>.delayed(Duration.zero);

      expect(
        slowRepository.requestOtpCallCount,
        1,
        reason:
            'Concurrent submit while loading must not duplicate requestOtp.',
      );
    });

    test('submit is accepted again once the controller is no longer '
        'loading', () async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );
      controller.updatePhoneNumber('9876543210');

      await controller.submit();
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.verificationSession, isNotNull);

      // A fresh submit after completion is allowed (the guard only blocks
      // while loading), so requestOtp is invoked a second time.
      await controller.submit();
      expect(fakeRepository.requestOtpCallCount, 2);
    });
  });

  group('PhoneEntryController OTP auto-retrieval timeout (SC2)', () {
    test('logs otp_auto_read_failed with a timeout error_type when '
        'auto-read expires', () async {
      // The code was sent, then Android auto-retrieval expired without an
      // instant auto-verification.
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid-123',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );
      fakeRepository.fireAutoRetrievalTimeout = true;

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'otp_auto_read_failed',
        orElse: () => (name: '', parameters: null),
      );
      expect(event.name, 'otp_auto_read_failed');
      expect(event.parameters, containsPair('error_type', 'timeout'));
    });

    test('does not log otp_auto_read_failed when auto-verification '
        'already succeeded', () async {
      // Instant verification fired before the auto-retrieval timeout; the
      // timeout must be suppressed because the user is already authenticated.
      fakeRepository.requestOtpAutoVerifiedUser = const AuthUser(
        uid: 'uid-auto',
        phoneNumber: '+919876543210',
      );
      fakeRepository.fireAutoRetrievalTimeout = true;

      controller.updatePhoneNumber('9876543210');
      await controller.submit();

      expect(controller.state.autoVerifiedUser, isNotNull);
      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'otp_auto_read_failed'),
        isFalse,
        reason:
            'A timeout after auto-verification must not be logged as a '
            'failure.',
      );
    });
  });
}
