import 'package:flutter/material.dart';

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
/// The card is a warm tonal hero with a subtle vertical gradient fill
/// (light `#FFFFFF → #FFF4E2`, dark `#2A2218 → #241D16`) at a 26 px radius.
/// In light it is lifted by the marigold-tinted [OBTColors.heroShadow]; in
/// dark it drops the shadow for a 1 px [ColorScheme.outline] border (the
/// Haldi dark hero treatment, DC). The direction arrow sits inside a small
/// circular badge filled with the balance-trio colour (a contrasting glyph
/// on top), ahead of the trio-coloured headline. The amount renders in the
/// Bricolage tabular amount-hero style ([OBTText.amountHero]) tinted by the
/// trio colour and wrapped in a [FittedBox] so it never clips at large
/// dynamic-type scales or for long values, and a meta subtitle states how
/// many friends the balance spans. Direction is always conveyed by the icon
/// and text label as well as colour (no colour-only meaning; SRS section
/// 5.6).
///
/// All paise → INR conversion goes through [formatInrFromPaise]; the
/// absolute amount is formatted so the textual label carries the
/// direction (Invariant 1 — no inline rupee arithmetic). The signed
/// balance is a read-only projection value (Invariant 2 — the client
/// never writes `simplifiedBalances`).
class NetBalanceHeaderCard extends StatelessWidget {
  /// Creates a [NetBalanceHeaderCard] for the signed overall
  /// [netBalancePaise].
  const NetBalanceHeaderCard({
    required this.netBalancePaise,
    this.friendCount = 0,
    super.key,
  });

  /// Signed overall net balance in paise. Positive ⇒ owed to the user;
  /// negative ⇒ the user owes; zero ⇒ all settled up.
  final int netBalancePaise;

  /// Number of friends the overall balance spans, shown in the meta
  /// subtitle ("across N friends"). Passed in from the dashboard (which
  /// already holds the friends list) so this card stays a plain,
  /// provider-free widget. Groups are intentionally omitted from the count
  /// (the Groups area is not yet built).
  final int friendCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final isDark = theme.brightness == Brightness.dark;

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

    // Contrasting glyph on the trio-filled badge: white on the saturated
    // light hues, ink (onPrimary) on the brighter dark hues — exactly the
    // pairing in the handoff (`#fff` light, `#1A1510` dark).
    final badgeIconColor = isDark ? colors.onPrimary : Colors.white;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const <Color>[Color(0xFF2A2218), Color(0xFF241D16)]
                : const <Color>[Color(0xFFFFFFFF), Color(0xFFFFF4E2)],
          ),
          borderRadius: BorderRadius.circular(26),
          // Light hero: soft marigold lift. Dark hero: no shadow, a 1 px
          // outline border instead (Haldi dark hero treatment).
          boxShadow: isDark ? null : obtColors.heroShadow,
          border: isDark ? Border.all(color: colors.outline) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  key: const ValueKey('net_balance_badge'),
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: trio,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 13, color: badgeIconColor),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      color: trio,
                    ),
                  ),
                ),
              ],
            ),
            if (amount != null) ...[
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: OBTText.amountHero(context).copyWith(color: trio),
                ),
              ),
            ],
            const SizedBox(height: 9),
            Text(
              _friendCountSubtitle(friendCount),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                color: OBTColors.metaText(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "across 1 friend" / "across N friends". Groups are omitted from the
  /// count until the Groups area ships.
  static String _friendCountSubtitle(int count) {
    final noun = count == 1 ? 'friend' : 'friends';
    return 'across $count $noun';
  }
}
