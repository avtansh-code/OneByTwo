import 'package:flutter/material.dart';

import 'package:one_by_two/core/widgets/amount_display.dart';

/// Displays a balance with automatic color coding.
///
/// Positive balance = green (user is owed), negative = red (user owes),
/// zero = neutral gray (settled up).
///
/// This is a convenience wrapper around [AmountDisplay] with
/// [AmountColorType.auto] pre-applied.
class BalanceDisplay extends StatelessWidget {
  /// Creates a [BalanceDisplay].
  ///
  /// [balanceInPaise] is the net balance in paise (₹1 = 100 paise).
  /// Positive means the user is owed money, negative means the user owes.
  const BalanceDisplay({
    super.key,
    required this.balanceInPaise,
    this.size = AmountDisplaySize.medium,
    this.showSign = true,
    this.compact = false,
  });

  /// The net balance in paise.
  ///
  /// - Positive: the user is owed this amount (green).
  /// - Negative: the user owes this amount (red).
  /// - Zero: all settled (gray).
  final int balanceInPaise;

  /// The display size of the balance text.
  final AmountDisplaySize size;

  /// Whether to show a `+` prefix for positive balances.
  ///
  /// Defaults to `true`. The minus sign is always shown for negative values.
  final bool showSign;

  /// Whether to omit decimal places when the paise component is zero.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AmountDisplay(
      amountInPaise: balanceInPaise,
      size: size,
      colorType: AmountColorType.auto,
      showSign: showSign,
      compact: compact,
    );
  }
}
