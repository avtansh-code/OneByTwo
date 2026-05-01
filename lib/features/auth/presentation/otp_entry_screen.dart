import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/otp_entry_controller.dart';
import 'package:onebytwo/features/auth/presentation/widgets/otp_input.dart';

/// OTP verification screen for FR-AU-03.
///
/// Displays a six-digit OTP input, a countdown timer for resend, and a
/// masked phone number. The phone number is masked to show only the
/// last 4 digits (e.g. +91 XXXXXX3210).
class OtpEntryScreen extends ConsumerWidget {
  /// Creates an [OtpEntryScreen].
  const OtpEntryScreen({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    this.initialCountdownSeconds = 30,
    super.key,
  });

  /// The raw 10-digit phone number (no prefix).
  final String phoneNumber;

  /// The verification ID from the initial OTP request.
  final String verificationId;

  /// The resend token from the initial OTP request.
  final int? resendToken;

  /// Initial countdown seconds before resend is allowed.
  final int initialCountdownSeconds;

  String get _maskedPhone {
    final last4 = phoneNumber.length >= 4
        ? phoneNumber.substring(phoneNumber.length - 4)
        : phoneNumber;
    return '+91 XXXXXX$last4';
  }

  /// Provider arguments derived from widget properties.
  ({
    String phoneNumber,
    String verificationId,
    int? resendToken,
    int initialCountdownSeconds,
  })
  get _providerArgs => (
    phoneNumber: phoneNumber,
    verificationId: verificationId,
    resendToken: resendToken,
    initialCountdownSeconds: initialCountdownSeconds,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(otpEntryControllerProvider(_providerArgs));
    final controller = ref.read(
      otpEntryControllerProvider(_providerArgs).notifier,
    );

    // Post-auth routing is handled reactively by the auth gate
    // (OneBytwoApp) which observes authStateNotifierProvider. When
    // OTP verification succeeds, Firebase Auth emits a new user,
    // the auth state provider transitions, and the auth gate
    // replaces the MaterialApp (clearing this screen from the stack).
    // No imperative navigation is needed here.

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Navigate back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Verify your number',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  children: [
                    TextSpan(
                      text: _maskedPhone,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OtpInput(
                onDigitEntered: controller.setDigit,
                onCompleted: (_) => controller.submit(),
                onBackspace: controller.clearDigit,
              ),
              const SizedBox(height: 16),

              // Error text.
              if (state.validationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    state.validationError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

              // Loading indicator.
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              if (!state.canResend)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Resend OTP in '
                    '${_formatCountdown(state.remainingSeconds)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: state.canResend
                    ? 'Resend OTP'
                    : 'Resend OTP, disabled, '
                          '${state.remainingSeconds} '
                          'seconds remaining',
                excludeSemantics: true,
                child: TextButton(
                  onPressed: state.canResend ? controller.resend : null,
                  child: Text.rich(
                    TextSpan(
                      text: "Didn't receive the code? ",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      children: [
                        TextSpan(
                          text: 'Resend',
                          style: TextStyle(
                            color: state.canResend
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.38,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCountdown(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
