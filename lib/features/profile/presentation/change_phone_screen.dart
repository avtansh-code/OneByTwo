import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/india_phone_input_formatter.dart';
import 'package:onebytwo/features/auth/presentation/widgets/otp_input.dart';
import 'package:onebytwo/features/profile/application/change_phone_controller.dart';

/// Change-phone re-verification screen for FR-PR-02 (SCR-26 entry point).
///
/// Reuses the auth +91 phone entry and six-digit [OtpInput] widgets across a
/// two-OTP flow: re-verify the CURRENT number, then verify the NEW number.
/// The single screen switches body by [ChangePhoneStep]; post-success the
/// auth gate's real-time listener refreshes the displayed number.
class ChangePhoneScreen extends ConsumerStatefulWidget {
  /// Creates a [ChangePhoneScreen].
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePhoneControllerProvider);
    final controller = ref.read(changePhoneControllerProvider.notifier);

    ref.listen<ChangePhoneState>(changePhoneControllerProvider, (
      previous,
      next,
    ) {
      if (next.step == ChangePhoneStep.success &&
          previous?.step != ChangePhoneStep.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Phone number updated')));
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Phone Number'),
        leading: BackButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: state.isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (state.step) {
              ChangePhoneStep.reauthIntro => _buildReauthIntro(
                context,
                state,
                controller,
              ),
              ChangePhoneStep.reauthOtp => _buildReauthOtp(
                context,
                state,
                controller,
              ),
              ChangePhoneStep.newPhoneEntry => _buildNewPhoneEntry(
                context,
                state,
                controller,
              ),
              ChangePhoneStep.newPhoneOtp => _buildNewPhoneOtp(
                context,
                state,
                controller,
              ),
              ChangePhoneStep.success => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReauthIntro(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Verify your current number'),
        const SizedBox(height: 12),
        Text(
          'To protect your account, please verify your current number '
          'before changing it.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          label:
              'Current phone number: '
              '${_a11yPhone(state.currentPhoneNumber)}',
          child: TextFormField(
            initialValue: state.currentPhoneNumber,
            enabled: false,
            decoration: _outlinedDecoration(context, label: 'Current number'),
          ),
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null) _errorText(theme, state.errorMessage!),
        const SizedBox(height: 16),
        _primaryButton(
          context,
          label: 'Send verification code',
          isLoading: state.isLoading,
          onPressed: controller.sendReauthOtp,
        ),
      ],
    );
  }

  Widget _buildReauthOtp(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Verify your current number'),
        const SizedBox(height: 12),
        _sentToText(theme, _maskE164(state.currentPhoneNumber)),
        const SizedBox(height: 32),
        OtpInput(
          key: const ValueKey('reauth-otp'),
          onDigitEntered: (_, _) {},
          onCompleted: controller.submitReauthOtp,
          onBackspace: (_) {},
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null) _errorText(theme, state.errorMessage!),
        if (state.isLoading) _loadingRow(theme),
      ],
    );
  }

  Widget _buildNewPhoneEntry(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Enter your new number'),
        const SizedBox(height: 12),
        Text(
          "We'll send a 6-digit code to verify your new number.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        _newPhoneInputRow(context, state, controller),
        if (state.validationError != null) ...[
          const SizedBox(height: 8),
          _errorText(theme, state.validationError!),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          _errorText(theme, state.errorMessage!),
        ],
        const SizedBox(height: 24),
        _primaryButton(
          context,
          label: 'Send code',
          isLoading: state.isLoading,
          onPressed: state.newPhoneDigits.length == 10
              ? controller.submitNewPhone
              : null,
        ),
      ],
    );
  }

  Widget _buildNewPhoneOtp(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Verify your new number'),
        const SizedBox(height: 12),
        _sentToText(theme, _maskDigits(state.newPhoneDigits)),
        const SizedBox(height: 32),
        OtpInput(
          key: const ValueKey('new-otp'),
          onDigitEntered: (_, _) {},
          onCompleted: controller.submitNewPhoneOtp,
          onBackspace: (_) {},
        ),
        const SizedBox(height: 16),
        if (state.syncPending)
          _syncPendingRecovery(context, state, controller)
        else if (state.errorMessage != null)
          _errorText(theme, state.errorMessage!),
        if (state.isLoading) _loadingRow(theme),
      ],
    );
  }

  Widget _newPhoneInputRow(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Country code, India, plus 91',
          excludeSemantics: true,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusChipInput),
                bottomLeft: Radius.circular(AppTheme.radiusChipInput),
              ),
              border: Border.all(color: colorScheme.outline),
            ),
            alignment: Alignment.center,
            child: Text(
              '+91',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 56,
            child: TextField(
              enabled: !state.isLoading,
              decoration: const InputDecoration(
                hintText: 'Enter new mobile number',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppTheme.radiusChipInput),
                    bottomRight: Radius.circular(AppTheme.radiusChipInput),
                  ),
                ),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                IndianPhoneInputFormatter(),
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: controller.updateNewPhone,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ],
    );
  }

  // --- Small shared building blocks ---

  /// The ADR-0015 "sync pending" recovery: the auth number changed but the
  /// Firestore mirror did not, so we surface a [OBTColors.warning]-toned
  /// caution (never the danger token) plus a retry. The re-auth state
  /// machine is unchanged — this only restyles the recovery affordance.
  Widget _syncPendingRecovery(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    final warning =
        theme.extension<OBTColors>()?.warning ?? theme.colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sync_problem, color: warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.errorMessage ??
                        'Your number was verified but we could not finish '
                            'updating it. Please try again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _primaryButton(
          context,
          label: 'Try again',
          isLoading: state.isLoading,
          onPressed: controller.retrySync,
        ),
      ],
    );
  }

  Widget _heading(ThemeData theme, String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    ),
  );

  Widget _sentToText(ThemeData theme, String masked) => Text.rich(
    TextSpan(
      text: 'Enter the 6-digit code sent to ',
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      children: [
        TextSpan(
          text: masked,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _errorText(ThemeData theme, String message) => Text(
    message,
    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
  );

  Widget _loadingRow(ThemeData theme) => const Padding(
    padding: EdgeInsets.only(top: 16),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  InputDecoration _outlinedDecoration(
    BuildContext context, {
    required String label,
  }) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
    ),
  );

  Widget _primaryButton(
    BuildContext context, {
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Semantics(
        button: true,
        label: isLoading ? '$label, in progress' : label,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }

  /// Masks an E.164 `+91XXXXXXXXXX` number to `+91 XXXXXX1234`.
  String _maskE164(String e164) {
    final digits = e164.startsWith('+91') ? e164.substring(3) : e164;
    return _maskDigits(digits);
  }

  String _maskDigits(String digits) {
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    return '+91 XXXXXX$last4';
  }

  /// Spells out an E.164 number for screen readers.
  String _a11yPhone(String e164) {
    if (e164.startsWith('+91') && e164.length == 13) {
      final digits = e164.substring(3);
      return 'plus 91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return e164;
  }
}
