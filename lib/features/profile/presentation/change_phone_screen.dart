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

    // The success state is a full-bleed brand moment (Haldi screen 5) with
    // no app bar or stepper; "Back to Profile" pops back. The profile
    // screen already reflects the new number via the auth listener, so no
    // snackbar is needed here.
    if (state.step == ChangePhoneStep.success) {
      return Scaffold(body: _buildSuccess(context, state, controller));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change number'),
        leading: BackButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: state.isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepIndicator(currentStep: _stepIndex(state.step)),
                const SizedBox(height: 24),
                switch (state.step) {
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a [ChangePhoneStep] to its 1-based position in the four-segment
  /// progress indicator (the Haldi screen-1..4 stepper).
  int _stepIndex(ChangePhoneStep step) => switch (step) {
    ChangePhoneStep.reauthIntro => 1,
    ChangePhoneStep.reauthOtp => 2,
    ChangePhoneStep.newPhoneEntry => 3,
    ChangePhoneStep.newPhoneOtp => 4,
    ChangePhoneStep.success => 4,
  };

  /// The brand-moment success screen (Haldi screen 5): a full-bleed
  /// marigold radial wash, a check disc, the confirmation copy, and a
  /// single "Back to Profile" action that pops to the profile screen
  /// (which already reflects the new number via the auth listener).
  Widget _buildSuccess(
    BuildContext context,
    ChangePhoneState state,
    ChangePhoneController controller,
  ) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final onWash = theme.colorScheme.onPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.1,
          colors: [theme.colorScheme.primary, obtColors.primaryPressed],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Phone number updated successfully',
                image: true,
                child: Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: obtColors.heroShadow,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 60,
                    color: obtColors.balancePositive,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Semantics(
                header: true,
                child: Text(
                  'Phone number updated',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(color: onWash),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You'll sign in with ${_maskDigits(state.newPhoneDigits)} "
                'from now on.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onWash.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 30),
              Semantics(
                button: true,
                label: 'Back to Profile, button',
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurface,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusButton,
                      ),
                    ),
                  ),
                  child: const Text('Back to Profile'),
                ),
              ),
            ],
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
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: obtColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 42,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Verify your current number',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'For your security, confirm the number on your account '
                "before you change it. We'll send a 6-digit code.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: OBTColors.metaText(theme),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _currentNumberCard(context, state),
        const SizedBox(height: 16),
        if (state.errorMessage != null) _errorText(theme, state.errorMessage!),
        const SizedBox(height: 8),
        _primaryButton(
          context,
          label: 'Send verification code',
          icon: Icons.sms_outlined,
          isLoading: state.isLoading,
          onPressed: controller.sendReauthOtp,
        ),
      ],
    );
  }

  /// The locked "current number" card on the re-auth intro (Haldi screen 1)
  /// — a smartphone glyph, the unmasked current number, and a lock glyph.
  /// This is the one place the current number is shown unmasked.
  Widget _currentNumberCard(BuildContext context, ChangePhoneState state) {
    final theme = Theme.of(context);
    final meta = OBTColors.metaText(theme);
    return Semantics(
      label: 'Current phone number: ${_a11yPhone(state.currentPhoneNumber)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.smartphone, size: 22, color: meta),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current number',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: meta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPhoneDisplay(state.currentPhoneNumber),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_outline, size: 20, color: meta),
          ],
        ),
      ),
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
        _heading(theme, "Confirm it's you"),
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
        _heading(theme, 'Your new number'),
        const SizedBox(height: 12),
        Text(
          "We'll send a code to confirm it. India numbers only.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: OBTColors.metaText(theme),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'NEW MOBILE NUMBER',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        _newPhoneInputRow(context, state, controller),
        if (state.validationError != null) ...[
          const SizedBox(height: 8),
          _errorText(theme, state.validationError!),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Must differ from your current number.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: OBTColors.metaText(theme),
            ),
          ),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          _errorText(theme, state.errorMessage!),
        ],
        const SizedBox(height: 24),
        _primaryButton(
          context,
          label: 'Send code',
          trailingIcon: Icons.arrow_forward,
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
    // IntrinsicHeight + CrossAxisAlignment.stretch make the +91 prefix and the
    // input share one height so their top and bottom edges align (issue #150).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Country code, India, plus 91',
            excludeSemantics: true,
            child: Container(
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
        ],
      ),
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

  Widget _primaryButton(
    BuildContext context, {
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, size: 20),
                    ],
                  ],
                ),
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

  /// Formats "+919876543210" for display as "+91 98765 43210".
  String _formatPhoneDisplay(String e164) {
    if (e164.startsWith('+91') && e164.length == 13) {
      final digits = e164.substring(3);
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return e164;
  }
}

/// The four-segment progress indicator for the change-number flow (Haldi
/// screens 1..4): segments up to and including [currentStep] are filled
/// with the primary marigold; the rest use a muted track.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  static const int totalSteps = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Semantics(
      label: 'Step $currentStep of $totalSteps',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= totalSteps; i++) ...[
            if (i > 1) const SizedBox(width: 7),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i <= currentStep
                      ? theme.colorScheme.primary
                      : obtColors.disabledFill,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const SizedBox(height: 5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
