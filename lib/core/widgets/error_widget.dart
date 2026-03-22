import 'package:flutter/material.dart';

import 'package:one_by_two/core/l10n/generated/app_localizations.dart';

/// Full-screen error display with an icon, message, and optional retry button.
///
/// Use this for top-level error states that replace an entire page or section.
class ErrorDisplay extends StatelessWidget {
  /// Creates an [ErrorDisplay].
  ///
  /// [message] describes the error. [onRetry], if provided, shows a retry
  /// button that invokes the callback when pressed.
  const ErrorDisplay({super.key, required this.message, this.onRetry});

  /// A human-readable error message.
  final String message;

  /// Callback invoked when the user taps the retry button.
  ///
  /// If `null`, the retry button is hidden.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error display for smaller contexts (e.g. inside a list or card).
///
/// Shows a compact error message with an optional retry button.
class InlineErrorDisplay extends StatelessWidget {
  /// Creates an [InlineErrorDisplay].
  ///
  /// [message] describes the error. [onRetry], if provided, adds a retry
  /// icon button.
  const InlineErrorDisplay({super.key, required this.message, this.onRetry});

  /// A human-readable error message.
  final String message;

  /// Callback invoked when the user taps the retry button.
  ///
  /// If `null`, the retry button is hidden.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: onRetry,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: AppLocalizations.of(context).retry,
          ),
        ],
      ],
    );
  }
}
