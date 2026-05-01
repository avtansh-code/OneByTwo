import 'package:flutter/material.dart';

/// Placeholder home screen displayed after successful profile
/// setup.
///
/// This screen will be replaced by the real dashboard in a
/// future PR.
class HomePlaceholderScreen extends StatelessWidget {
  /// Creates a [HomePlaceholderScreen].
  const HomePlaceholderScreen({super.key});

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
                Icons.home_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text('Home', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'The real dashboard is coming '
                'soon.',
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
