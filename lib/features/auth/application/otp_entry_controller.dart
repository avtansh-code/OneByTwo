import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';

/// Immutable state for the OTP entry form.
class OtpEntryState {
  /// Creates an [OtpEntryState].
  const OtpEntryState({
    this.digits = const ['', '', '', '', '', ''],
    this.remainingSeconds = 30,
    this.canResend = false,
    this.resendCount = 0,
    this.validationError,
    this.isSubmitted = false,
  });

  /// The six OTP digit cells. Always has exactly 6 elements.
  final List<String> digits;

  /// Seconds remaining until resend is allowed.
  final int remainingSeconds;

  /// Whether the user may request a new OTP.
  final bool canResend;

  /// Number of times the user has requested a resend.
  final int resendCount;

  /// Non-null when the last action failed validation.
  final String? validationError;

  /// Whether the OTP has been submitted.
  final bool isSubmitted;

  /// Whether all six digits have been entered.
  bool get isComplete => digits.every((d) => d.isNotEmpty);

  /// Whether the form can be submitted (complete and not yet submitted).
  bool get canSubmit => isComplete && !isSubmitted;

  /// The concatenated OTP string.
  String get otp => digits.join();

  /// Creates a copy with the given fields replaced.
  OtpEntryState copyWith({
    List<String>? digits,
    int? remainingSeconds,
    bool? canResend,
    int? resendCount,
    String? Function()? validationError,
    bool? isSubmitted,
  }) {
    return OtpEntryState(
      digits: digits != null ? List<String>.unmodifiable(digits) : this.digits,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      canResend: canResend ?? this.canResend,
      resendCount: resendCount ?? this.resendCount,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}

/// Controller for the OTP entry screen (FR-AU-02).
///
/// Manages the six-digit OTP input, resend countdown timer, and fires
/// analytics events for screen views, submissions, and resend requests.
class OtpEntryController extends StateNotifier<OtpEntryState> {
  /// Creates an [OtpEntryController].
  ///
  /// Immediately logs `signup_otp_screen_viewed` with a SHA-256 hash of
  /// the [phoneNumber].
  OtpEntryController({
    required AnalyticsService analytics,
    required String phoneNumber,
    int initialCountdownSeconds = 30,
  }) : _analytics = analytics,
       _initialCountdownSeconds = initialCountdownSeconds,
       super(OtpEntryState(remainingSeconds: initialCountdownSeconds)) {
    final phoneHash = sha256.convert(utf8.encode(phoneNumber)).toString();
    _analytics.logEvent(
      name: 'signup_otp_screen_viewed',
      parameters: {'phone_hash': phoneHash},
    );
  }

  final AnalyticsService _analytics;
  final int _initialCountdownSeconds;
  Timer? _timer;

  /// Sets a single digit at [index] (0-5).
  void setDigit(int index, String digit) {
    final updated = List<String>.of(state.digits);
    updated[index] = digit;
    state = state.copyWith(digits: updated);
  }

  /// Clears the digit at [index] (0-5).
  void clearDigit(int index) {
    final updated = List<String>.of(state.digits);
    updated[index] = '';
    state = state.copyWith(digits: updated);
  }

  /// Pastes a full OTP code into all six cells.
  ///
  /// Rejects codes that are not exactly 6 numeric digits.
  void pasteOtp(String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return;
    final digits = code.split('');
    state = state.copyWith(digits: digits);
  }

  /// Submits the OTP if all six digits are present.
  ///
  /// No-op when the OTP is incomplete.
  void submit() {
    if (!state.isComplete) return;
    state = state.copyWith(isSubmitted: true);
    _analytics.logEvent(name: 'signup_otp_submitted');
  }

  /// Starts the resend countdown timer.
  void startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        _timer?.cancel();
        state = state.copyWith(remainingSeconds: 0, canResend: true);
      } else {
        state = state.copyWith(remainingSeconds: next);
      }
    });
  }

  /// Requests a new OTP if allowed.
  ///
  /// No-op when [OtpEntryState.canResend] is `false` or after 3 resends.
  void resend() {
    if (!state.canResend || state.resendCount >= 3) return;
    final newCount = state.resendCount + 1;
    state = state.copyWith(
      resendCount: newCount,
      remainingSeconds: _initialCountdownSeconds,
      canResend: false,
    );
    startResendTimer();
    _analytics.logEvent(
      name: 'signup_otp_resend_requested',
      parameters: {'attempt_number': newCount},
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for [OtpEntryController].
///
/// Keyed by phone number and countdown duration. Auto-disposes when the
/// screen is popped. Starts the resend timer automatically.
final otpEntryControllerProvider = StateNotifierProvider.autoDispose
    .family<
      OtpEntryController,
      OtpEntryState,
      ({String phoneNumber, int initialCountdownSeconds})
    >((ref, args) {
      final analytics = ref.watch(analyticsServiceProvider);
      return OtpEntryController(
        analytics: analytics,
        phoneNumber: args.phoneNumber,
        initialCountdownSeconds: args.initialCountdownSeconds,
      )..startResendTimer();
    });
