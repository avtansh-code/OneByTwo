// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/otp_entry_controller.dart';

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

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late OtpEntryController controller;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    controller = OtpEntryController(
      analytics: fakeAnalytics,
      phoneNumber: '9876543210',
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

    test('submit is a no-op when OTP is incomplete', () {
      controller.setDigit(0, '1');
      controller.submit();
      expect(controller.state.isSubmitted, isFalse);
    });

    test('submit sets isSubmitted when OTP is complete', () {
      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      controller.submit();
      expect(controller.state.isSubmitted, isTrue);
    });

    test('submit logs otp_screen_submitted telemetry when complete', () {
      for (var i = 0; i < 6; i++) {
        controller.setDigit(i, '${i + 1}');
      }
      controller.submit();
      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'signup_otp_submitted'),
        isTrue,
      );
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

      // Wait slightly over 2 seconds to allow 2 ticks.
      await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));

      expect(controller.state.remainingSeconds, lessThanOrEqualTo(28));
    });

    test('canResend becomes true when countdown reaches zero', () async {
      // Create a controller with a very short countdown for testing.
      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        phoneNumber: '9876543210',
        initialCountdownSeconds: 2,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 200));

      expect(fastController.state.canResend, isTrue);
      expect(fastController.state.remainingSeconds, 0);
    });

    test('resend resets countdown and increments resendCount', () async {
      // Use a fast countdown.
      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        phoneNumber: '9876543210',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
      expect(fastController.state.canResend, isTrue);

      fastController.resend();
      expect(fastController.state.resendCount, 1);
      expect(fastController.state.remainingSeconds, 1);
      expect(fastController.state.canResend, isFalse);
    });

    test('resend logs otp_resend_tapped telemetry', () async {
      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        phoneNumber: '9876543210',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      fastController.startResendTimer();
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));

      fastController.resend();
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'signup_otp_resend_requested' &&
              e.parameters?['attempt_number'] == 1,
        ),
        isTrue,
      );
    });

    test('resend is no-op when canResend is false', () {
      controller.resend();
      expect(controller.state.resendCount, 0);
    });

    test('resend is no-op after 3 attempts (resend exhausted)', () async {
      final fastController = OtpEntryController(
        analytics: fakeAnalytics,
        phoneNumber: '9876543210',
        initialCountdownSeconds: 1,
      );
      addTearDown(fastController.dispose);

      for (var i = 0; i < 3; i++) {
        fastController.startResendTimer();
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 200),
        );
        fastController.resend();
      }

      expect(fastController.state.resendCount, 3);

      // Wait for timer to expire again.
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));

      // 4th resend should be no-op.
      fastController.resend();
      expect(fastController.state.resendCount, 3);
    });

    test('otp_screen_viewed is logged at construction with hashed phone', () {
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
  });
}
