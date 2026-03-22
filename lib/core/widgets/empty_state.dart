import 'package:flutter/material.dart';

/// Full empty-state widget with icon, title, subtitle, and optional action.
///
/// Use this when a screen or section has no data to display (e.g. no expenses,
/// no groups, no friends).
class EmptyState extends StatelessWidget {
  /// Creates an [EmptyState].
  ///
  /// [title] is the primary message. [icon] is shown above the title.
  /// [subtitle] provides additional guidance. [actionLabel] and [onAction]
  /// add a call-to-action button.
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  /// Primary message (e.g. "No expenses yet").
  final String title;

  /// Optional secondary message providing guidance (e.g. "Tap + to add one").
  final String? subtitle;

  /// Icon displayed above the title.
  final IconData icon;

  /// Label for the optional action button.
  ///
  /// If `null`, the action button is hidden.
  final String? actionLabel;

  /// Callback invoked when the action button is tapped.
  ///
  /// If `null`, the action button is hidden regardless of [actionLabel].
  final VoidCallback? onAction;

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
              icon,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact empty-state widget for inline use within lists.
///
/// Shows a small icon and message in a horizontal row. Suitable for
/// sections within a larger scrollable page.
class CompactEmptyState extends StatelessWidget {
  /// Creates a [CompactEmptyState].
  ///
  /// [message] is the text displayed next to the [icon].
  const CompactEmptyState({
    super.key,
    required this.message,
    required this.icon,
  });

  /// Short message describing the empty state.
  final String message;

  /// Icon displayed to the left of the message.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant.withAlpha(153),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
