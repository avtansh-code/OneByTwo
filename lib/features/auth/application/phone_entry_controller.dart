import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/validators.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';

/// Immutable state for the phone entry form.
class PhoneEntryState {
  /// Creates a [PhoneEntryState].
  const PhoneEntryState({
    this.phoneNumber = '',
    this.validationError,
    this.isSubmitted = false,
    this.isLoading = false,
    this.verificationSession,
    this.autoVerifiedUser,
  });

  /// The raw 10-digit phone number (no prefix).
  final String phoneNumber;

  /// Non-null when the last submission failed validation.
  final String? validationError;

  /// Whether a valid submission has been made.
  final bool isSubmitted;

  /// Whether an OTP request is in progress.
  final bool isLoading;

  /// Set when OTP has been sent successfully. Signals navigation
  /// to the OTP entry screen.
  final VerificationSession? verificationSession;

  /// Set when Android auto-verification completes during OTP request.
  final AuthUser? autoVerifiedUser;

  /// Creates a copy with the given fields replaced.
  PhoneEntryState copyWith({
    String? phoneNumber,
    String? Function()? validationError,
    bool? isSubmitted,
    bool? isLoading,
    VerificationSession? Function()? verificationSession,
    AuthUser? Function()? autoVerifiedUser,
  }) {
    return PhoneEntryState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      isLoading: isLoading ?? this.isLoading,
      verificationSession: verificationSession != null
          ? verificationSession()
          : this.verificationSession,
      autoVerifiedUser: autoVerifiedUser != null
          ? autoVerifiedUser()
          : this.autoVerifiedUser,
    );
  }
}

/// Controller for the phone entry screen (FR-AU-01).
///
/// Manages the phone number input, validates on submission, requests
/// an OTP via [PhoneAuthRepository], and fires analytics events.
class PhoneEntryController extends StateNotifier<PhoneEntryState> {
  /// Creates a [PhoneEntryController].
  PhoneEntryController({
    required AnalyticsService analytics,
    required PhoneAuthRepository repository,
  }) : _analytics = analytics,
       _repository = repository,
       super(const PhoneEntryState());

  final AnalyticsService _analytics;
  final PhoneAuthRepository _repository;

  /// Updates the phone number digits and clears any prior error.
  void updatePhoneNumber(String digits) {
    state = state.copyWith(phoneNumber: digits, validationError: () => null);
  }

  /// Validates and submits the current phone number.
  ///
  /// On valid input, fires `signup_started`, then requests an OTP.
  /// On OTP sent, sets [PhoneEntryState.verificationSession].
  /// On error, sets [PhoneEntryState.validationError] with the
  /// domain error message.
  Future<void> submit() async {
    final error = validateIndianMobile(state.phoneNumber);
    if (error != null) {
      state = state.copyWith(validationError: () => error);
      return;
    }

    await _analytics.logEvent(name: 'signup_started');
    state = state.copyWith(
      isLoading: true,
      validationError: () => null,
      verificationSession: () => null,
      autoVerifiedUser: () => null,
    );

    final stopwatch = Stopwatch()..start();
    final phoneE164 = '+91${state.phoneNumber}';

    await _repository.requestOtp(
      phoneNumber: phoneE164,
      onCodeSent: (session) {
        stopwatch.stop();
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isSubmitted: true,
          verificationSession: () => session,
        );
        _analytics.logEvent(
          name: 'otp_send_succeeded',
          parameters: {'duration_ms': stopwatch.elapsedMilliseconds},
        );
      },
      onAutoVerified: (user) {
        stopwatch.stop();
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isSubmitted: true,
          autoVerifiedUser: () => user,
        );
        _analytics.logEvent(
          name: 'otp_auto_read_succeeded',
          parameters: {'duration_ms': stopwatch.elapsedMilliseconds},
        );
      },
      onError: (authError) {
        stopwatch.stop();
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          validationError: () => authError.message,
        );
        _analytics.logEvent(
          name: 'otp_send_failed',
          parameters: {'error_code': authError.name},
        );
      },
      onAutoRetrievalTimeout: () {
        if (!mounted) return;
        // Only log if auto-verification did not already succeed.
        if (state.autoVerifiedUser == null) {
          _analytics.logEvent(
            name: 'otp_auto_read_failed',
            parameters: {'error_type': 'timeout'},
          );
        }
      },
    );
  }
}

/// Riverpod provider for [PhoneEntryController].
final phoneEntryControllerProvider =
    StateNotifierProvider<PhoneEntryController, PhoneEntryState>((ref) {
      final analytics = ref.watch(analyticsServiceProvider);
      final repository = ref.watch(phoneAuthRepositoryProvider);
      return PhoneEntryController(analytics: analytics, repository: repository);
    });
