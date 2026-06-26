import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// FR-HD-01 net-balance header card — the primary visual element of the
/// Home dashboard (SCR-06 Populated State), in the Haldi visual language
/// (DC-05).
///
/// Renders one of three direction states from the signed overall net
/// balance in paise, always as the **balance trio (colour + icon + label)**
/// so the direction survives greyscale and colour-blind rendering:
///
/// - **owed** (`netBalancePaise > 0`) — [OBTColors.balancePositive] +
///   `arrow_upward` + "Overall, you are owed" + amount.
/// - **owe** (`netBalancePaise < 0`) — [OBTColors.balanceNegative] +
///   `arrow_downward` + "Overall, you owe" + amount.
/// - **settled** (`netBalancePaise == 0`) — [OBTColors.balanceZero] +
///   `check` + "You're all settled up — high five!", no amount.
///
/// The card is a tonal hero on [ColorScheme.surfaceContainerHighest] (the
/// warm Haldi surface-variant) lifted by the marigold-tinted
/// [OBTColors.heroShadow]; the amount renders in the Bricolage tabular
/// amount-hero style ([OBTText.amountHero]) tinted by the balance-trio
/// colour, and is wrapped in a [FittedBox] so it never clips at large
/// dynamic-type scales or for long values. Direction is always conveyed
/// by the icon and text label as well as colour (no colour-only meaning;
/// SRS section 5.6).
///
/// All paise → INR conversion goes through [formatInrFromPaise]; the
/// absolute amount is formatted so the textual label carries the
/// direction (Invariant 1 — no inline rupee arithmetic). The signed
/// balance is a read-only projection value (Invariant 2 — the client
/// never writes `simplifiedBalances`).
class NetBalanceHeaderCard extends StatelessWidget {
  /// Creates a [NetBalanceHeaderCard] for the signed overall
  /// [netBalancePaise].
  const NetBalanceHeaderCard({required this.netBalancePaise, super.key});

  /// Signed overall net balance in paise. Positive ⇒ owed to the user;
  /// negative ⇒ the user owes; zero ⇒ all settled up.
  final int netBalancePaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;

    final Color trio;
    final IconData icon;
    final String headline;
    final String? amount;
    final String semanticLabel;

    if (netBalancePaise > 0) {
      trio = obtColors.balancePositive;
      icon = Icons.arrow_upward;
      headline = 'Overall, you are owed';
      amount = formatInrFromPaise(netBalancePaise);
      semanticLabel = 'Overall balance: you are owed rupees $amount';
    } else if (netBalancePaise < 0) {
      trio = obtColors.balanceNegative;
      icon = Icons.arrow_downward;
      headline = 'Overall, you owe';
      amount = formatInrFromPaise(netBalancePaise.abs());
      semanticLabel = 'Overall balance: you owe rupees $amount';
    } else {
      trio = obtColors.balanceZero;
      icon = Icons.check;
      headline = "You're all settled up — high five!";
      amount = null;
      semanticLabel = 'Overall balance: all settled up';
    }

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: obtColors.heroShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: trio),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (amount != null) ...[
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: OBTText.amountHero(context).copyWith(color: trio),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
