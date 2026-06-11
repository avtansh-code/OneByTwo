import 'package:flutter/material.dart';

/// Placeholder content for the Home tab (index 0 of the authenticated
/// shell).
///
/// The real `HomeDashboardScreen` lands in a focused FR-HD-01..04 PR
/// under `lib/features/home/presentation/`; until then, this widget
/// communicates that the dashboard is coming.
///
/// The body copy is the exact text extracted from the temporary
/// `HomePlaceholderScreen` (deleted in this PR) — preserved so the
/// visual experience is unchanged. The AppBar drops the temporary
/// Activity / Profile shortcut buttons because the bottom nav now owns
/// navigation to those surfaces.
class HomeDashboardPlaceholder extends StatelessWidget {
  /// Creates the Home tab placeholder.
  const HomeDashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
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
                'The real dashboard is coming soon.',
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
