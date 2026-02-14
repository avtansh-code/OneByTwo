import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/amount_formatter.dart';

/// Widget that displays monetary amounts in ₹ format.
/// 
/// Converts amounts from paise (integer) to rupees and formats them
/// using Indian number grouping. Supports color-coding based on
/// balance state (owe/owed/settled).
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    required this.amountInPaise,
    this.size = AmountDisplaySize.medium,
    this.colorType = AmountColorType.neutral,
    this.showSign = false,
    this.showDecimals = true,
    this.compact = false,
    super.key,
  });

  /// Amount in paise (integer)
  final int amountInPaise;

  /// Size of the amount display
  final AmountDisplaySize size;

  /// Color type based on balance state
  final AmountColorType colorType;

  /// Whether to show + or - sign prefix
  final bool showSign;

  /// Whether to show decimal places
  final bool showDecimals;

  /// Whether to use compact format for large amounts (e.g., ₹1.2K)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final colorScheme = Theme.of(context).colorScheme;

    // Determine color based on color type
    final Color textColor = switch (colorType) {
      AmountColorType.owe => appColors.oweColor,
      AmountColorType.owed => appColors.owedColor,
      AmountColorType.settled => appColors.settledColor,
      AmountColorType.neutral => colorScheme.onSurface,
    };

    // Determine text style based on size
    final TextStyle textStyle = switch (size) {
      AmountDisplaySize.large => AppTypography.amountLarge(context, color: textColor),
      AmountDisplaySize.medium => AppTypography.amountMedium(context, color: textColor),
      AmountDisplaySize.small => AppTypography.amountSmall(context, color: textColor),
    };

    // Format the amount
    final String formattedAmount = compact
        ? AmountFormatter.formatAmountCompact(amountInPaise)
        : showSign
            ? AmountFormatter.formatAmountWithSign(
                amountInPaise,
                showDecimals: showDecimals,
              )
            : AmountFormatter.formatAmount(
                amountInPaise,
                showDecimals: showDecimals,
              );

    return Text(
      formattedAmount,
      style: textStyle,
    );
  }
}

/// Size options for amount display
enum AmountDisplaySize {
  /// Large size (32px) - for big displays like total balance
  large,

  /// Medium size (20px) - for list items
  medium,

  /// Small size (14px) - for secondary amounts
  small,
}

/// Color type based on balance state
enum AmountColorType {
  /// User owes money (red)
  owe,

  /// User is owed money (green)
  owed,

  /// Balance is settled/zero (neutral gray)
  settled,

  /// Neutral color (default theme color)
  neutral,
}

/// Widget that displays a balance with appropriate color coding.
/// 
/// Positive amounts are shown in green (owed), negative in red (owe),
/// and zero in neutral gray.
class BalanceDisplay extends StatelessWidget {
  const BalanceDisplay({
    required this.balanceInPaise,
    this.size = AmountDisplaySize.medium,
    this.showSign = true,
    this.showDecimals = true,
    this.compact = false,
    super.key,
  });

  /// Balance in paise (can be positive, negative, or zero)
  final int balanceInPaise;

  /// Size of the amount display
  final AmountDisplaySize size;

  /// Whether to show + or - sign prefix
  final bool showSign;

  /// Whether to show decimal places
  final bool showDecimals;

  /// Whether to use compact format for large amounts
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AmountColorType colorType;
    
    if (balanceInPaise > 0) {
      colorType = AmountColorType.owed; // Positive = user is owed
    } else if (balanceInPaise < 0) {
      colorType = AmountColorType.owe; // Negative = user owes
    } else {
      colorType = AmountColorType.settled; // Zero = settled
    }

    return AmountDisplay(
      amountInPaise: balanceInPaise.abs(),
      size: size,
      colorType: colorType,
      showSign: showSign && balanceInPaise != 0,
      showDecimals: showDecimals,
      compact: compact,
    );
  }
}
