import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

/// Error state widget with icon, message, and retry button.
/// 
/// Displays a full-screen error state with an icon, error message,
/// and an optional retry button.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    required this.message,
    this.onRetry,
    this.icon,
    super.key,
  });

  /// Error message to display
  final String message;

  /// Optional callback for retry action
  final VoidCallback? onRetry;

  /// Optional custom icon (defaults to error_outline)
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.errorText(context),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error display for use within cards or lists.
/// 
/// A compact error display without the large icon.
class InlineErrorDisplay extends StatelessWidget {
  const InlineErrorDisplay({
    required this.message,
    this.onRetry,
    super.key,
  });

  /// Error message to display
  final String message;

  /// Optional callback for retry action
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.errorText(context),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
            ),
          ],
        ],
      ),
    );
  }
}
