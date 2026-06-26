import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// The shared balance indicator (foundation plan section 4.2 #2; QA
/// strategy section B.3).
///
/// Signals a net balance with the **colour + icon + label trio — never
/// colour alone**, so the meaning survives greyscale and colour-blind
/// rendering:
///
/// - `> 0` owed: [OBTColors.balancePositive] + `arrow_upward` +
///   "you are owed".
/// - `< 0` owe: [OBTColors.balanceNegative] + `arrow_downward` +
///   "you owe".
/// - `== 0` settled: [OBTColors.balanceZero] + `check` + "Settled up".
///
/// Reads a **passed** signed [netBalancePaise] projection only — it never
/// writes `simplifiedBalances` (Invariant 2). The amount is the magnitude
/// rendered solely via [formatInrFromPaise] (Invariant 1); the sign is
/// carried by the icon, label and colour, not a redundant minus.
class OBTBalancePill extends StatelessWidget {
  /// Creates an [OBTBalancePill] for a signed [netBalancePaise].
  const OBTBalancePill({
    required this.netBalancePaise,
    this.positiveLabelOverride,
    this.compact = false,
    super.key,
  });

  /// Signed net balance in paise. Positive = the other party owes the
  /// current user; negative = the current user owes; zero = settled.
  final int netBalancePaise;

  /// Optional label for the positive branch (e.g. "owes you" on a friend
  /// row) in place of the default "you are owed". The icon and colour are
  /// unchanged.
  final String? positiveLabelOverride;

  /// When true, renders the label and amount inline on one line (row
  /// context); otherwise stacks the amount under the label (header form).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;

    final Color hue;
    final IconData icon;
    final String label;
    final String? amount;

    if (netBalancePaise > 0) {
      hue = obtColors.balancePositive;
      icon = Icons.arrow_upward;
      label = positiveLabelOverride ?? 'you are owed';
      amount = formatInrFromPaise(netBalancePaise.abs());
    } else if (netBalancePaise < 0) {
      hue = obtColors.balanceNegative;
      icon = Icons.arrow_downward;
      label = 'you owe';
      amount = formatInrFromPaise(netBalancePaise.abs());
    } else {
      hue = obtColors.balanceZero;
      icon = Icons.check;
      label = 'Settled up';
      amount = null;
    }

    final labelText = Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(color: hue),
    );
    final amountText = amount == null
        ? null
        : Text(amount, style: OBTText.amount(context).copyWith(color: hue));

    final Widget content = compact || amountText == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: hue),
              const SizedBox(width: 4),
              Flexible(child: labelText),
              if (amountText != null) ...<Widget>[
                const SizedBox(width: 6),
                Flexible(child: amountText),
              ],
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: hue),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[labelText, amountText],
                ),
              ),
            ],
          );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: amount == null ? label : '$label $amount',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: content,
      ),
    );
  }
}
