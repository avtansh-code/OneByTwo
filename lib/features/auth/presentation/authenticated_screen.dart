import 'package:flutter/material.dart';

/// Placeholder authenticated screen displayed after successful
/// phone verification.
///
/// This screen is replaced by the profile setup flow in PR #8.
class AuthenticatedScreen extends StatelessWidget {
  /// Creates an [AuthenticatedScreen] showing the user [uid].
  const AuthenticatedScreen({required this.uid, super.key});

  /// The authenticated user's UID.
  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text('Authenticated', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                uid,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
