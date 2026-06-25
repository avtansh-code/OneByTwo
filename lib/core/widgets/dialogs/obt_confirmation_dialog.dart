import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';

/// Reusable confirmation dialog from the OneByTwo design system
/// catalogue (item 24).
///
/// Use [OBTConfirmationDialog.show] for the common `await` pattern;
/// returns `true` on confirm, `false` on cancel / scrim dismiss / back
/// gesture.
///
/// When [isDestructive] is true, the confirm button uses the theme's
/// error colour (mapped from the design-system `danger` token) and
/// surfaces a `'Destructive action.'` semantic hint. Back gesture and
/// Escape key always dismiss as cancel per SCR-22 §Accessibility.
///
/// Extracted on first use per architect §2.5 (FR-EX-06), mirroring the
/// `OBTAmountInput` precedent from PR #38: the catalogue contract is
/// locked the moment a second use site (SCR-13 "Leave group") needs it.
class OBTConfirmationDialog extends StatelessWidget {
  /// Creates an [OBTConfirmationDialog].
  const OBTConfirmationDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.onCancel,
    this.onConfirm,
    super.key,
  });

  /// Dialog title (heading-role announced).
  final String title;

  /// Body text (single paragraph; the design-system contract is
  /// `Text` content, not arbitrary children).
  final String body;

  /// Confirm button label.
  final String confirmLabel;

  /// Cancel button label. Defaults to `'Cancel'`.
  final String cancelLabel;

  /// When `true`, the confirm button is styled with the theme's
  /// error colour and announces the `'Destructive action.'` semantic
  /// hint.
  final bool isDestructive;

  /// Called when the user taps the cancel button. The widget itself
  /// does not pop; the caller (or the [show] static helper) owns the
  /// dismiss decision.
  final VoidCallback? onCancel;

  /// Called when the user taps the confirm button. Same ownership
  /// rule as [onCancel].
  final VoidCallback? onConfirm;

  /// Convenience launcher. Returns `true` when the user taps confirm,
  /// `false` otherwise (cancel, scrim dismiss, back gesture).
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => OBTConfirmationDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destructiveColor = theme.colorScheme.error;
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusCard)),
      ),
      title: Semantics(header: true, child: Text(title)),
      content: Text(body),
      actions: [
        TextButton(onPressed: onCancel, child: Text(cancelLabel)),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: destructiveColor,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: onConfirm,
          child: Semantics(
            hint: isDestructive ? 'Destructive action.' : null,
            button: true,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
