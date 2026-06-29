import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/inputs/obt_otp_input.dart';
import 'package:onebytwo/features/auth/application/otp_entry_controller.dart';

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

  String get _fullPhone {
    final p = phoneNumber;
    if (p.length == 10) {
      return '+91 ${p.substring(0, 5)} ${p.substring(5)}';
    }
    return '+91 $p';
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
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final state = ref.watch(otpEntryControllerProvider(_providerArgs));
    final controller = ref.read(
      otpEntryControllerProvider(_providerArgs).notifier,
    );

    // Post-auth routing is handled reactively by the auth gate
    // (OneBytwoApp) which observes authStateProvider. When
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
        child: SingleChildScrollView(
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Enter the code sent to ',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: _fullPhone,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Edit phone number',
                    child: InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Text(
                        'Edit',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: obtColors.link,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              OBTOtpInput(
                digits: state.digits,
                errorText: state.validationError,
                onDigitEntered: controller.setDigit,
                onCompleted: (_) => controller.submit(),
                onBackspace: controller.clearDigit,
              ),
              if (Theme.of(context).platform == TargetPlatform.android) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: obtColors.balancePositive.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sms_outlined,
                          size: 18,
                          color: obtColors.balancePositive,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-detecting code from SMS…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: obtColors.balancePositive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: OBTColors.metaText(theme),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resend code in '
                        '${_formatCountdown(state.remainingSeconds)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: OBTColors.metaText(theme),
                        ),
                      ),
                    ],
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
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: 'Resend',
                          style: TextStyle(
                            color: state.canResend
                                ? obtColors.link
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: state.canSubmit ? controller.submit : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                  child: const Text('Verify'),
                ),
              ),
              const SizedBox(height: 24),
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
