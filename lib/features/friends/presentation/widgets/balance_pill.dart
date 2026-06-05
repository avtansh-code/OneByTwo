import 'package:flutter/material.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';

/// Trailing balance pill on a friend list tile (SCR-09 component 4).
///
/// Renders one of three states depending on the sign of [netBalancePaise]:
///
/// - **owes you** — `netBalancePaise > 0`. The other user owes the
///   current user. Shows the formatted amount.
/// - **you owe** — `netBalancePaise < 0`. The current user owes the
///   other user. Shows the formatted absolute amount.
/// - **settled up** — `netBalancePaise == 0`. No amount text.
///
/// All formatting goes through `formatInrFromPaise()` — there is no
/// inline rupee arithmetic (invariant 1).
class BalancePill extends StatelessWidget {
  /// Creates a [BalancePill].
  const BalancePill({required this.netBalancePaise, super.key});

  /// Signed paise. See class doc for the colour / text mapping.
  final int netBalancePaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Color background;
    final Color foreground;
    final String label;
    final String? amount;

    if (netBalancePaise > 0) {
      background = colors.tertiaryContainer;
      foreground = colors.onTertiaryContainer;
      label = 'owes you';
      amount = formatInrFromPaise(netBalancePaise);
    } else if (netBalancePaise < 0) {
      background = colors.errorContainer;
      foreground = colors.onErrorContainer;
      label = 'you owe';
      amount = formatInrFromPaise(netBalancePaise);
    } else {
      background = colors.surfaceContainerHighest;
      foreground = colors.onSurfaceVariant;
      label = 'settled up';
      amount = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
          if (amount != null)
            Text(
              amount,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
