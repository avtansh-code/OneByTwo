import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// The shared balance indicator pill (Phase2 Components "Balance pills";
/// QA strategy section B.3).
///
/// Renders the signed net balance as a single-line `[icon] [amount]`
/// chip — it never wraps to two lines:
///
/// - `> 0` owed: [OBTColors.balancePositive] + `arrow_upward` + magnitude.
/// - `< 0` owe: [OBTColors.balanceNegative] + `arrow_downward` + magnitude.
/// - `== 0` settled: [OBTColors.balanceZero] + `check` + "Settled" (no
///   amount).
///
/// The directional **label** ("owes you" / "you owe" / "settled up") is
/// NOT inside the pill — it belongs in the host row's subtitle (see the
/// Phase3b/Phase3c friend rows). The colour + icon + label trio that
/// survives greyscale and colour-blind rendering is therefore completed
/// by the host: the pill carries the colour + icon (+ amount); the row
/// subtitle carries the label.
///
/// The amount [Text] is `maxLines: 1, softWrap: false`, and the whole
/// `[icon] [amount]` row sits inside a [FittedBox] ([BoxFit.scaleDown]),
/// so a long magnitude in a narrow slot scales DOWN rather than wrapping
/// or truncating — money is never ellipsised (QA strategy section C.2).
///
/// Reads a **passed** signed [netBalancePaise] projection only — it never
/// writes `simplifiedBalances` (Invariant 2). The amount is rendered
/// solely via [formatInrFromPaise] (Invariant 1); the sign is carried by
/// the icon and colour, not a redundant minus.
///
/// The pill is wrapped in [ExcludeSemantics]: the host row owns the
/// colour-independent `<name>, <direction>, <amount>` semantics, so the
/// pill must not re-announce a redundant label that double-reads.
class OBTBalancePill extends StatelessWidget {
  /// Creates an [OBTBalancePill] for a signed [netBalancePaise].
  const OBTBalancePill({required this.netBalancePaise, super.key});

  /// Signed net balance in paise. Positive = the other party owes the
  /// current user; negative = the current user owes; zero = settled.
  final int netBalancePaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;

    final Color hue;
    final IconData icon;
    final String text;

    if (netBalancePaise > 0) {
      hue = obtColors.balancePositive;
      icon = Icons.arrow_upward;
      text = formatInrFromPaise(netBalancePaise.abs());
    } else if (netBalancePaise < 0) {
      hue = obtColors.balanceNegative;
      icon = Icons.arrow_downward;
      text = formatInrFromPaise(netBalancePaise.abs());
    } else {
      hue = obtColors.balanceZero;
      icon = Icons.check;
      text = 'Settled';
    }

    // `[icon] [amount]` on ONE line. The amount never wraps (softWrap:
    // false, maxLines: 1) and the FittedBox shrinks the whole row to fit
    // a narrow slot, so money scales down rather than truncating.
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: hue),
          const SizedBox(width: 5),
          Text(
            text,
            style: OBTText.amountPill(context).copyWith(color: hue),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );

    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: content,
      ),
    );
  }
}
