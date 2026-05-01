import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/validators.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';

/// Immutable state for the phone entry form.
class PhoneEntryState {
  /// Creates a [PhoneEntryState].
  const PhoneEntryState({
    this.phoneNumber = '',
    this.validationError,
    this.isSubmitted = false,
  });

  /// The raw 10-digit phone number (no prefix).
  final String phoneNumber;

  /// Non-null when the last submission failed validation.
  final String? validationError;

  /// Whether a valid submission has been made.
  final bool isSubmitted;

  /// Creates a copy with the given fields replaced.
  PhoneEntryState copyWith({
    String? phoneNumber,
    String? Function()? validationError,
    bool? isSubmitted,
  }) {
    return PhoneEntryState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}

/// Controller for the phone entry screen (FR-AU-01).
///
/// Manages the phone number input, validates on submission, and fires
/// the `signup_started` analytics event on valid submit.
class PhoneEntryController extends StateNotifier<PhoneEntryState> {
  /// Creates a [PhoneEntryController].
  PhoneEntryController({required AnalyticsService analytics})
    : _analytics = analytics,
      super(const PhoneEntryState());

  final AnalyticsService _analytics;

  /// Updates the phone number digits and clears any prior validation error.
  void updatePhoneNumber(String digits) {
    state = state.copyWith(phoneNumber: digits, validationError: () => null);
  }

  /// Validates and submits the current phone number.
  ///
  /// On valid input, fires `signup_started` analytics event and sets
  /// [PhoneEntryState.isSubmitted] to `true`.
  /// On invalid input, sets [PhoneEntryState.validationError].
  Future<void> submit() async {
    final error = validateIndianMobile(state.phoneNumber);
    if (error != null) {
      state = state.copyWith(validationError: () => error);
      return;
    }

    await _analytics.logEvent(name: 'signup_started');
    state = state.copyWith(isSubmitted: true, validationError: () => null);
  }
}

/// Riverpod provider for [PhoneEntryController].
final phoneEntryControllerProvider =
    StateNotifierProvider<PhoneEntryController, PhoneEntryState>((ref) {
      final analytics = ref.watch(analyticsServiceProvider);
      return PhoneEntryController(analytics: analytics);
    });
