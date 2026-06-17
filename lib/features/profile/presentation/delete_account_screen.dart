import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/presentation/widgets/otp_input.dart';
import 'package:onebytwo/features/profile/application/delete_account_controller.dart';

/// The result a [DeleteAccountScreen] returns to its caller via
/// `Navigator.pop`.
enum DeleteAccountOutcome {
  /// The `deleteUserAccount` cascade failed or timed out (Step D). The
  /// caller (Profile View) shows the Contact Support snackbar.
  failed,
}

/// How long the Step E success state is shown before signing out to the
/// Phone Entry screen (SCR-28: 3 seconds).
const Duration _kSuccessDisplayDuration = Duration(seconds: 3);

/// Account-deletion flow screen for FR-AU-09 (SCR-28 Part B).
///
/// A single full-screen route at `/profile/delete-account` whose body
/// switches by [DeleteAccountStep]: Step A warning, Step B re-authentication
/// (reusing the FR-PR-02 auth OTP widgets), Step C type-`DELETE`
/// confirmation, Step D processing, Step E success. On success the
/// controller signs out and the root auth gate clears the stack to the
/// Phone Entry screen; on failure the screen pops with
/// [DeleteAccountOutcome.failed].
class DeleteAccountScreen extends ConsumerStatefulWidget {
  /// Creates a [DeleteAccountScreen].
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  void _handleBack() {
    final handled = ref.read(deleteAccountControllerProvider.notifier).goBack();
    if (!handled && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onStepChanged(DeleteAccountStep? previous, DeleteAccountStep next) {
    if (previous == next) return;
    switch (next) {
      case DeleteAccountStep.failed:
        Navigator.of(context).pop(DeleteAccountOutcome.failed);
      case DeleteAccountStep.success:
        _successTimer?.cancel();
        _successTimer = Timer(_kSuccessDisplayDuration, () {
          if (!mounted) return;
          ref
              .read(deleteAccountControllerProvider.notifier)
              .signOutAfterDeletion();
        });
      case DeleteAccountStep.warning:
      case DeleteAccountStep.reauthIntro:
      case DeleteAccountStep.reauthOtp:
      case DeleteAccountStep.confirm:
      case DeleteAccountStep.processing:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountControllerProvider);
    final controller = ref.read(deleteAccountControllerProvider.notifier);

    ref.listen<DeleteAccountState>(deleteAccountControllerProvider, (
      previous,
      next,
    ) {
      _onStepChanged(previous?.step, next.step);
      final snackbar = next.snackbarMessage;
      if (snackbar != null && previous?.snackbarMessage != snackbar) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(snackbar)));
        controller.clearSnackbar();
      }
    });

    final blockBack =
        state.step == DeleteAccountStep.processing ||
        state.step == DeleteAccountStep.success;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || blockBack) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: _buildAppBar(context, state),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing:
                state.isLoading && state.step != DeleteAccountStep.reauthOtp,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: switch (state.step) {
                DeleteAccountStep.warning => _buildWarning(context, controller),
                DeleteAccountStep.reauthIntro => _buildReauthIntro(
                  context,
                  state,
                  controller,
                ),
                DeleteAccountStep.reauthOtp => _buildReauthOtp(
                  context,
                  state,
                  controller,
                ),
                DeleteAccountStep.confirm => _buildConfirm(
                  context,
                  state,
                  controller,
                ),
                DeleteAccountStep.processing => _buildProcessing(context),
                DeleteAccountStep.success => _buildSuccess(context),
                DeleteAccountStep.failed => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(
    BuildContext context,
    DeleteAccountState state,
  ) {
    // Step E (success) is a full-screen state with no app bar.
    if (state.step == DeleteAccountStep.success ||
        state.step == DeleteAccountStep.failed) {
      return null;
    }
    final title = switch (state.step) {
      DeleteAccountStep.warning => 'Delete Account',
      DeleteAccountStep.reauthIntro ||
      DeleteAccountStep.reauthOtp => 'Verify Your Identity',
      DeleteAccountStep.confirm => 'Confirm Deletion',
      DeleteAccountStep.processing => 'Deleting Account',
      _ => 'Delete Account',
    };
    // Step D (processing) blocks back navigation entirely.
    final showBack = state.step != DeleteAccountStep.processing;
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: false,
      leading: showBack
          ? BackButton(onPressed: state.isLoading ? null : _handleBack)
          : null,
    );
  }

  // --- Step A: warning ---

  Widget _buildWarning(BuildContext context, DeleteAccountController c) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Semantics(
          label: 'Warning',
          image: true,
          child: Icon(Icons.warning_amber_rounded, size: 56, color: danger),
        ),
        const SizedBox(height: 24),
        Text(
          'This will permanently delete your account',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Your personal data, profile, and expense history will be '
          'permanently removed.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "In shared groups, your name will be replaced with 'Deleted User' "
          'and your balances will be preserved for other members.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          label:
              'Important: This cannot be undone. Data is removed within 30 '
              'days of your request.',
          container: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text(
              'This cannot be undone. Data is removed within 30 days of your '
              'request.',
              style: theme.textTheme.bodyMedium?.copyWith(color: danger),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          button: true,
          label: 'Continue with account deletion, button',
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: c.continueFromWarning,
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Cancel, button',
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                c.cancelFromWarning();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step B: re-authentication ---

  Widget _buildReauthIntro(
    BuildContext context,
    DeleteAccountState state,
    DeleteAccountController c,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Verify your identity'),
        const SizedBox(height: 12),
        Text(
          'To protect your account, please verify your phone number before '
          'continuing.',
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
            decoration: InputDecoration(
              labelText: 'Your number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null) _errorText(theme, state.errorMessage!),
        const SizedBox(height: 16),
        _primaryButton(
          context,
          label: 'Send OTP',
          isLoading: state.isLoading,
          onPressed: c.sendReauthOtp,
        ),
      ],
    );
  }

  Widget _buildReauthOtp(
    BuildContext context,
    DeleteAccountState state,
    DeleteAccountController c,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Verify your identity'),
        const SizedBox(height: 12),
        _sentToText(theme, _maskE164(state.currentPhoneNumber)),
        const SizedBox(height: 32),
        OtpInput(
          key: const ValueKey('delete-reauth-otp'),
          onDigitEntered: (_, _) {},
          onCompleted: c.submitReauthOtp,
          onBackspace: (_) {},
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null) _errorText(theme, state.errorMessage!),
        if (state.isLoading) _loadingRow(),
      ],
    );
  }

  // --- Step C: type-DELETE confirmation ---

  Widget _buildConfirm(
    BuildContext context,
    DeleteAccountState state,
    DeleteAccountController c,
  ) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    final enabled = state.confirmationMatches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, 'Confirm deletion'),
        const SizedBox(height: 12),
        Text(
          'This is your last chance to change your mind.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Type DELETE to confirm',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Type DELETE to confirm, text field',
          textField: true,
          child: TextField(
            key: const ValueKey('delete-confirm-input'),
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            onChanged: c.updateConfirmationText,
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          button: true,
          enabled: enabled,
          label: enabled
              ? 'Delete My Account, button'
              : 'Delete My Account, button, disabled',
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: enabled ? c.confirmDeletion : null,
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: theme.colorScheme.onError,
                disabledBackgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: const Text('Delete My Account'),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step D: processing ---

  Widget _buildProcessing(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            label: 'Deleting your account, please wait',
            child: SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Deleting your account...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a moment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step E: success ---

  Widget _buildSuccess(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Column(
        children: [
          Semantics(
            label: 'Account deleted successfully',
            image: true,
            child: Icon(
              Icons.check_circle,
              size: 64,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Account deleted',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Your data will be fully removed within 30 days.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // --- Shared building blocks (mirrors ChangePhoneScreen) ---

  Widget _heading(ThemeData theme, String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.primary,
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

  Widget _loadingRow() => const Padding(
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
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
