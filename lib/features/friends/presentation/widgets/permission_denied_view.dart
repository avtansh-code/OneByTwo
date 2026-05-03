import 'package:flutter/material.dart';

/// View shown when the user has denied contact permission.
///
/// Displays an explanation and a CTA to either re-request permission
/// or open the device settings, depending on whether the denial is
/// permanent.
class PermissionDeniedView extends StatelessWidget {
  /// Creates a [PermissionDeniedView].
  const PermissionDeniedView({
    required this.isDeniedPermanently,
    required this.onGrantPermission,
    required this.onOpenSettings,
    super.key,
  });

  /// Whether permission has been permanently denied.
  final bool isDeniedPermanently;

  /// Called when the user taps the "Grant Permission" CTA.
  final VoidCallback onGrantPermission;

  /// Called when the user taps the "Open Settings" CTA.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
          ],
        ),
      ),
    );
  }
}
