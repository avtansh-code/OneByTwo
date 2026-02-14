import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

/// Empty state widget with icon, title, subtitle, and optional action button.
/// 
/// Displays a full-screen empty state when there's no content to show.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Title text (e.g., "No expenses yet")
  final String title;

  /// Subtitle/description text
  final String subtitle;

  /// Optional icon to display (defaults to inbox)
  final IconData? icon;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action button callback
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.emptyStateTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.emptyStateSubtitle(context),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact empty state for use within cards or specific sections.
class CompactEmptyState extends StatelessWidget {
  const CompactEmptyState({
    required this.message,
    this.icon,
    super.key,
  });

  /// Message to display
  final String message;

  /// Optional icon to display
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTypography.bodyDefault(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
