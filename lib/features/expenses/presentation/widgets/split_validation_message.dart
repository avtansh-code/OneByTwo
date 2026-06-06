import 'package:flutter/material.dart';

/// Inline danger-coloured message used for the exact-split sum
/// mismatch error (SCR-20 / AC-7).
///
/// The wording is supplied by the controller (the widget is
/// presentation-only); see
/// `AddExpenseController._splitMismatchMessage`.
class SplitValidationMessage extends StatelessWidget {
  /// Creates a [SplitValidationMessage].
  const SplitValidationMessage({required this.message, super.key});

  /// The danger-coloured message text.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
