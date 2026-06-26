import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// Inline split-sum validation pill (Haldi 21; SCR-20 / AC-7).
///
/// Two tones, never colour alone — each pairs a tinted bed with a glyph
/// and the supplied [message]:
///
/// - [isError] `true` (default): the red over/under mismatch, on a
///   [ColorScheme.error] bed with `error_outline`. The detailed wording is
///   supplied by the controller (see
///   `AddExpenseController._splitMismatchMessage`).
/// - [isError] `false`: the green "adds up" success variant on an
///   [OBTColors.balancePositive] bed with `check_circle_outline`.
///
/// The live over-under / adds-up summary in Step 2 is owned by the shared
/// `OBTSegmentedSplitControl`; this pill surfaces the controller's detailed
/// exact-split mismatch message beneath the split rows.
class SplitValidationMessage extends StatelessWidget {
  /// Creates a [SplitValidationMessage].
  const SplitValidationMessage({
    required this.message,
    this.isError = true,
    super.key,
  });

  /// The message text (announced as a live region).
  final String message;

  /// Whether this is the red over/under error (`true`) or the green
  /// "adds up" success variant (`false`).
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final signal = isError
        ? theme.colorScheme.error
        : obtColors.balancePositive;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: signal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: signal, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: signal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
