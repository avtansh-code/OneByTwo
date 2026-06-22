import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';

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
    this.isLoading = false,
    this.isAuthenticated = false,
    this.verificationId,
    this.authenticatedUser,
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

  /// Whether a verify or resend operation is in progress.
  final bool isLoading;

  /// Whether the user has been authenticated successfully.
  final bool isAuthenticated;

  /// The current verification session ID.
  final String? verificationId;

  /// The authenticated user after successful verification.
  final AuthUser? authenticatedUser;

  /// Whether all six digits have been entered.
  bool get isComplete => digits.every((d) => d.isNotEmpty);

  /// Whether the form can be submitted (complete and not loading).
  bool get canSubmit => isComplete && !isLoading;

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
    bool? isLoading,
    bool? isAuthenticated,
    String? Function()? verificationId,
    AuthUser? Function()? authenticatedUser,
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
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      verificationId: verificationId != null
          ? verificationId()
          : this.verificationId,
      authenticatedUser: authenticatedUser != null
          ? authenticatedUser()
          : this.authenticatedUser,
    );
  }
}

/// Controller for the OTP entry screen (FR-AU-02).
///
/// Manages the six-digit OTP input, resend countdown timer,
/// verification via [PhoneAuthRepository], and analytics events.
class OtpEntryController extends StateNotifier<OtpEntryState> {
  /// Creates an [OtpEntryController].
  ///
  /// Immediately logs `otp_screen_viewed` with a SHA-256 hash
  /// of the [phoneNumber].
  OtpEntryController({
    required AnalyticsService analytics,
    required PhoneAuthRepository repository,
    required String phoneNumber,
    required String verificationId,
    int? resendToken,
    int initialCountdownSeconds = 30,
    @visibleForTesting DateTime Function()? clock,
  }) : _analytics = analytics,
       _repository = repository,
       _phoneNumber = phoneNumber,
       _resendToken = resendToken,
       _initialCountdownSeconds = initialCountdownSeconds,
       _clock = clock ?? DateTime.now,
       super(
         OtpEntryState(
           remainingSeconds: initialCountdownSeconds,
           verificationId: verificationId,
         ),
       ) {
    final phoneHash = sha256.convert(utf8.encode(phoneNumber)).toString();
    _analytics.logEvent(
      name: 'otp_screen_viewed',
      parameters: {'phone_hash': phoneHash},
    );
    _otpScreenStopwatch.start();
  }

  final AnalyticsService _analytics;
  final PhoneAuthRepository _repository;
  final String _phoneNumber;
  final int _initialCountdownSeconds;
  final DateTime Function() _clock;
  final Stopwatch _otpScreenStopwatch = Stopwatch();
  final List<DateTime> _resendTimestamps = [];
  int? _resendToken;
  Timer? _timer;
  bool _wasPasted = false;

  /// Sets a single digit at [index] (0-5).
  void setDigit(int index, String digit) {
    _wasPasted = false;
    final updated = List<String>.of(state.digits);
    updated[index] = digit;
    state = state.copyWith(digits: updated);
  }

  /// Clears the digit at [index] (0-5).
  void clearDigit(int index) {
    _wasPasted = false;
    final updated = List<String>.of(state.digits);
    updated[index] = '';
    state = state.copyWith(digits: updated);
  }

  /// Pastes a full OTP code into all six cells.
  ///
  /// Rejects codes that are not exactly 6 numeric digits.
  void pasteOtp(String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return;
    _wasPasted = true;
    final digits = code.split('');
    state = state.copyWith(digits: digits);
  }

  /// Submits the OTP for verification.
  ///
  /// No-op when the OTP is incomplete or already loading.
  Future<void> submit() async {
    if (!state.isComplete || state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      isSubmitted: true,
      validationError: () => null,
    );
    unawaited(
      _analytics.logEvent(
        name: 'otp_verification_started',
        parameters: {'method': _wasPasted ? 'paste' : 'manual'},
      ),
    );

    final vid = state.verificationId;
    if (vid == null) {
      state = state.copyWith(
        isLoading: false,
        validationError: () => AuthError.sessionExpired.message,
      );
      return;
    }

    final stopwatch = Stopwatch()..start();
    final result = await _repository.verifyOtp(
      verificationId: vid,
      code: state.otp,
    );
    stopwatch.stop();

    if (!mounted) return;

    switch (result) {
      case Success(:final value):
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          authenticatedUser: () => value,
        );
        unawaited(
          _analytics.logEvent(
            name: 'otp_verification_succeeded',
            parameters: {
              'duration_ms': stopwatch.elapsedMilliseconds,
              'is_new_user': value.isNewUser ? 1 : 0,
            },
          ),
        );
        if (value.isNewUser) {
          unawaited(
            _analytics.logEvent(
              name: 'signup_completed',
              parameters: {'method': 'phone'},
            ),
          );
        }
      case Failure(:final error):
        state = state.copyWith(
          isLoading: false,
          isSubmitted: false,
          validationError: () => error.message,
          digits: List.filled(6, ''),
        );
        unawaited(
          _analytics.logEvent(
            name: 'otp_verification_failed',
            parameters: {'error_code': error.name},
          ),
        );
    }
  }

  /// Handles auto-verification from Android SMS Retriever.
  ///
  /// Called when the repository fires `onAutoVerified` with a
  /// pre-authenticated user.
  void handleAutoVerification(AuthUser user) {
    if (!mounted) return;
    _otpScreenStopwatch.stop();
    state = state.copyWith(
      isAuthenticated: true,
      authenticatedUser: () => user,
    );
    unawaited(
      _analytics.logEvent(
        name: 'otp_auto_read_succeeded',
        parameters: {'duration_ms': _otpScreenStopwatch.elapsedMilliseconds},
      ),
    );
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
  /// Enforces a sliding window of max 3 resends per 10 minutes.
  /// No-op when [OtpEntryState.canResend] is `false` or loading.
  Future<void> resend() async {
    if (!state.canResend || state.isLoading) return;

    // Prune timestamps older than 10 minutes.
    final now = _clock();
    final cutoff = now.subtract(const Duration(minutes: 10));
    _resendTimestamps.removeWhere((t) => t.isBefore(cutoff));

    if (_resendTimestamps.length >= 3) {
      unawaited(_analytics.logEvent(name: 'otp_resend_exhausted'));
      state = state.copyWith(
        validationError: () =>
            'Maximum resend attempts reached. Please try again later.',
        canResend: false,
      );
      return;
    }

    _resendTimestamps.add(now);
    final newCount = state.resendCount + 1;

    state = state.copyWith(
      isLoading: true,
      canResend: false,
      validationError: () => null,
    );

    unawaited(
      _analytics.logEvent(
        name: 'otp_resend_tapped',
        parameters: {'attempt_number': newCount},
      ),
    );

    await _repository.resendOtp(
      phoneNumber: '+91$_phoneNumber',
      onCodeSent: (session) {
        if (!mounted) return;
        _resendToken = session.resendToken;
        state = state.copyWith(
          resendCount: newCount,
          remainingSeconds: _initialCountdownSeconds,
          canResend: false,
          isLoading: false,
          verificationId: () => session.verificationId,
        );
        startResendTimer();
      },
      onError: (authError) {
        if (!mounted) return;
        // Remove the timestamp since the resend failed.
        _resendTimestamps.removeLast();
        state = state.copyWith(
          isLoading: false,
          canResend: true,
          validationError: () => authError.message,
        );
      },
      resendToken: _resendToken,
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
/// Keyed by phone number, verification ID, and countdown duration.
/// Auto-disposes when the screen is popped. Starts the resend timer
/// automatically.
final otpEntryControllerProvider = StateNotifierProvider.autoDispose
    .family<
      OtpEntryController,
      OtpEntryState,
      ({
        String phoneNumber,
        String verificationId,
        int? resendToken,
        int initialCountdownSeconds,
      })
    >((ref, args) {
      final analytics = ref.watch(analyticsServiceProvider);
      final repository = ref.watch(phoneAuthRepositoryProvider);
      return OtpEntryController(
        analytics: analytics,
        repository: repository,
        phoneNumber: args.phoneNumber,
        verificationId: args.verificationId,
        resendToken: args.resendToken,
        initialCountdownSeconds: args.initialCountdownSeconds,
      )..startResendTimer();
    });
