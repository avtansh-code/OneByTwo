import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Shows the "Stay in the loop" pre-permission dialog (FR-AC-03,
/// wireframes §1.1).
///
/// - 24dp corner radius, 8dp elevation per design tokens.
/// - Bell illustration tinted Primary.
/// - "Enable Notifications" filled button (Primary, 48dp height).
/// - "Not now" text button.
/// - Scrim tap + back gesture → onDismiss.
/// - Heading announced as a heading (Semantics(header: true)) for
///   screen readers per AC-20.
Future<void> showPrePermissionDialog({
  required BuildContext context,
  required VoidCallback onEnable,
  required VoidCallback onDismiss,
}) {
  return showDialog<void>(
    context: context,
    // ignore: use_build_context_synchronously
    builder: (dialogContext) =>
        _PrePermissionDialog(onEnable: onEnable, onDismiss: onDismiss),
  ).then((_) {
    // Defensive: if the dialog is dismissed via scrim tap or back
    // gesture, the future resolves with no return value. We treat both
    // as dismissals. Tap-on-Enable / tap-on-Not now pop the dialog AND
    // invoke their respective callbacks via the buttons themselves;
    // this `.then` is the catch-all for scrim/back.
  });
}

class _PrePermissionDialog extends StatefulWidget {
  const _PrePermissionDialog({required this.onEnable, required this.onDismiss});

  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  State<_PrePermissionDialog> createState() => _PrePermissionDialogState();
}

class _PrePermissionDialogState extends State<_PrePermissionDialog> {
  // Tracks whether either explicit button was tapped. If the dialog
  // pops without an explicit tap (scrim / back), we treat that as
  // dismissal.
  bool _explicitChoice = false;

  @override
  void dispose() {
    if (!_explicitChoice) {
      // Scrim tap or back gesture — fire dismiss.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDismiss();
      });
    }
    super.dispose();
  }

  void _onEnable() {
    _explicitChoice = true;
    Navigator.of(context).pop();
    widget.onEnable();
  }

  void _onNotNow() {
    _explicitChoice = true;
    Navigator.of(context).pop();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    );
    final ctaShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
    );
    return Dialog(
      shape: dialogShape,
      elevation: 8,
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Notification bell icon',
              child: Icon(
                Icons.notifications_active,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'Stay in the loop',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Get notified when friends add expenses or settle up. '
              'You can change this any time in Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: OBTColors.metaText(theme),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Semantics(
                label: 'Enable push notifications',
                button: true,
                child: FilledButton(
                  onPressed: _onEnable,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: ctaShape,
                  ),
                  child: Text(
                    'Enable Notifications',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Semantics(
                label: 'Skip enabling notifications for now',
                button: true,
                child: TextButton(
                  onPressed: _onNotNow,
                  child: Text(
                    'Not now',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: OBTColors.metaText(theme),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
