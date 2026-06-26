import 'package:flutter/material.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';

/// View shown when the user has denied contact permission (SCR-10 /
/// Haldi 10), reskinned to the Haldi tokens (DC-06).
///
/// Displays an explanation and a CTA to either re-request permission
/// or open the device settings, depending on whether the denial is
/// permanent. Optionally surfaces a secondary "Type a number instead"
/// link that switches the parent flow to manual phone entry
/// (Option-1 fallback per architect note 2.2 of the FR-FR-01
/// manual-phone-entry story).
class PermissionDeniedView extends StatelessWidget {
  /// Creates a [PermissionDeniedView].
  const PermissionDeniedView({
    required this.isDeniedPermanently,
    required this.onGrantPermission,
    required this.onOpenSettings,
    this.onTypeNumberInstead,
    super.key,
  });

  /// Whether permission has been permanently denied.
  final bool isDeniedPermanently;

  /// Called when the user taps the "Grant Permission" CTA.
  final VoidCallback onGrantPermission;

  /// Called when the user taps the "Open Settings" CTA.
  final VoidCallback onOpenSettings;

  /// Optional callback invoked when the user taps "Type a number
  /// instead". When `null`, the link is not rendered (preserves
  /// backwards compatibility with callers that do not offer a
  /// manual-entry fallback).
  final VoidCallback? onTypeNumberInstead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 52, color: colors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Contact access helps you find friends '
              'already on One By Two.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isDeniedPermanently
                  ? onOpenSettings
                  : onGrantPermission,
              child: Text(
                isDeniedPermanently ? 'Open Settings' : 'Grant Permission',
              ),
            ),
            if (onTypeNumberInstead != null) ...<Widget>[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onTypeNumberInstead,
                style: TextButton.styleFrom(foregroundColor: obtColors.link),
                child: const Text('Type a number instead'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
