import 'package:flutter/material.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';

/// FR-HD-01 net-balance header card — the primary visual element of the
/// Home dashboard (SCR-06 Populated State).
///
/// Renders one of three direction states from the signed overall net
/// balance in paise:
///
/// - **owed** (`netBalancePaise > 0`) — "Overall, you are owed" + amount.
/// - **owe** (`netBalancePaise < 0`) — "Overall, you owe" + amount.
/// - **settled** (`netBalancePaise == 0`) — "You're all settled up —
///   high five!", no amount.
///
/// Colour mapping reuses the app's semantic `ColorScheme` roles
/// (`tertiaryContainer` for owed, `errorContainer` for owe,
/// `surfaceContainerHighest` for settled) — the same mapping as
/// `balance_pill.dart` and `friend_detail_header.dart` — rather than the
/// raw SCR-06 hex tints, so the card is dark-mode-safe and consistent
/// with every other balance surface. Direction is always conveyed by
/// text as well as colour (SRS section 5.6 — no colour-only meaning).
///
/// All paise → INR conversion goes through [formatInrFromPaise]; the
/// absolute amount is formatted so the textual label carries the
/// direction (invariant 1 — no inline rupee arithmetic).
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

    final Color background;
    final Color foreground;
    final String headline;
    final String? amount;
    final String semanticLabel;

    if (netBalancePaise > 0) {
      background = colors.tertiaryContainer;
      foreground = colors.onTertiaryContainer;
      headline = 'Overall, you are owed';
      amount = formatInrFromPaise(netBalancePaise);
      semanticLabel = 'Overall balance: you are owed rupees $amount';
    } else if (netBalancePaise < 0) {
      background = colors.errorContainer;
      foreground = colors.onErrorContainer;
      headline = 'Overall, you owe';
      amount = formatInrFromPaise(netBalancePaise.abs());
      semanticLabel = 'Overall balance: you owe rupees $amount';
    } else {
      background = colors.surfaceContainerHighest;
      foreground = colors.onSurfaceVariant;
      headline = "You're all settled up — high five!";
      amount = null;
      semanticLabel = 'Overall balance: all settled up';
    }

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        elevation: 1,
        color: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: theme.textTheme.titleMedium?.copyWith(color: foreground),
              ),
              if (amount != null) ...[
                const SizedBox(height: 8),
                Text(
                  amount,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
