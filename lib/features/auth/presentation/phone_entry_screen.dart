import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/india_phone_input_formatter.dart';
import 'package:onebytwo/core/widgets/inputs/obt_locked_phone_field.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/phone_entry_controller.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/presentation/otp_entry_screen.dart';
import 'package:onebytwo/features/auth/presentation/profile_setup_screen.dart';
import 'package:onebytwo/features/shell/presentation/authenticated_shell.dart';

/// Phone number entry screen for FR-AU-01.
///
/// Collects a 10-digit Indian mobile number. The +91 country code is
/// displayed as a non-editable prefix widget. Validation occurs on
/// Continue tap; the button is passively disabled until 10 digits are
/// entered.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  /// Creates the phone entry screen.
  ///
  /// [source] identifies how the screen was reached, for the
  /// `phone_entry_viewed` telemetry event (defaults to `splash`).
  const PhoneEntryScreen({this.source = 'splash', super.key});

  /// Telemetry source recorded by `phone_entry_viewed` on mount.
  final String source;

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'phone_entry_viewed',
            parameters: {'source': widget.source},
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneEntryControllerProvider);
    final controller = ref.read(phoneEntryControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasExactlyTenDigits = state.phoneNumber.length == 10;

    // Navigate to OTP screen when verification session is set.
    ref.listen<PhoneEntryState>(phoneEntryControllerProvider, (previous, next) {
      if (next.verificationSession != null &&
          previous?.verificationSession == null) {
        final session = next.verificationSession!;
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OtpEntryScreen(
              phoneNumber: session.phoneNumber.replaceFirst('+91', ''),
              verificationId: session.verificationId,
              resendToken: session.resendToken,
            ),
          ),
        );
      }
      // Navigate post-auth on auto-verification.
      if (next.autoVerifiedUser != null && previous?.autoVerifiedUser == null) {
        _navigatePostAuth(
          context,
          ref,
          next.autoVerifiedUser!.uid,
          next.phoneNumber,
        );
      }
      // Surface OTP-send failures as a snackbar (SCR-03).
      if (next.otpSendError != null &&
          previous?.otpSendError != next.otpSendError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.otpSendError!)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Heading.
              Text(
                'Enter your mobile number',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle.
              Text(
                "We'll send you a 6-digit code to verify.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Phone input row.
              OBTLockedPhoneField(
                enabled: !state.isLoading,
                hasError: state.validationError != null,
                inputFormatters: [IndianPhoneDisplayFormatter()],
                onChanged: controller.updatePhoneNumber,
              ),

              // Error text.
              if (state.validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.validationError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),

              const Spacer(),

              // Continue button.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: hasExactlyTenDigits && !state.isLoading
                      ? controller.submit
                      : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigates to home or profile setup based on whether
  /// a user document already exists.
  Future<void> _navigatePostAuth(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String phoneDigits,
  ) async {
    final userRepo = ref.read(userRepositoryProvider);
    try {
      final user = await userRepo.getUser(uid);
      if (!context.mounted) return;
      if (user != null && user.displayName.trim().isNotEmpty) {
        unawaited(
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const AuthenticatedShell()),
            (_) => false,
          ),
        );
      } else {
        unawaited(
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ProfileSetupScreen(uid: uid, phoneNumber: '+91$phoneDigits'),
            ),
            (_) => false,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      unawaited(
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) =>
                ProfileSetupScreen(uid: uid, phoneNumber: '+91$phoneDigits'),
          ),
          (_) => false,
        ),
      );
    }
  }
}
