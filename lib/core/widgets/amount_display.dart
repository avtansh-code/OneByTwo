import 'package:flutter/material.dart';

import 'package:one_by_two/core/theme/app_colors.dart';
import 'package:one_by_two/core/theme/app_typography.dart';
import 'package:one_by_two/core/utils/amount_utils.dart';

/// Available sizes for [AmountDisplay].
enum AmountDisplaySize {
  /// 14 px, medium weight.
  small,

  /// 20 px, semi-bold.
  medium,

  /// 32 px, bold.
  large,
}

/// How to determine the color of the displayed amount.
enum AmountColorType {
  /// Red — the user owes money.
  owe,

  /// Green — the user is owed money.
  owed,

  /// Gray — neutral, no directional meaning.
  neutral,

  /// Automatically determined from the sign of [AmountDisplay.amountInPaise].
  ///
  /// Positive → green (owed), negative → red (owe), zero → gray (settled).
  auto,
}

/// Displays a monetary amount with proper Indian formatting and color coding.
///
/// Automatically formats the amount in paise to rupees with the `₹` symbol
/// and Indian number grouping (e.g. `₹1,00,050`).
///
/// The amount color is determined by [colorType]:
/// - [AmountColorType.owe] — red
/// - [AmountColorType.owed] — green
/// - [AmountColorType.neutral] — default text color
/// - [AmountColorType.auto] — derived from the sign of [amountInPaise]
class AmountDisplay extends StatelessWidget {
  /// Creates an [AmountDisplay].
  ///
  /// [amountInPaise] is the monetary value in paise (₹1 = 100 paise).
  const AmountDisplay({
    super.key,
    required this.amountInPaise,
    this.size = AmountDisplaySize.medium,
    this.colorType = AmountColorType.auto,
    this.showSign = false,
    this.compact = false,
  });

  /// The monetary amount in paise.
  ///
  /// For example, ₹100.50 is represented as `10050`.
  final int amountInPaise;

  /// The display size of the amount text.
  final AmountDisplaySize size;

  /// How the text color is determined.
  ///
  /// When set to [AmountColorType.auto], the color is derived from the sign
  /// of [amountInPaise]: positive → green, negative → red, zero → gray.
  final AmountColorType colorType;

  /// Whether to show a `+` or `-` sign prefix.
  ///
  /// The minus sign is always shown for negative amounts. When `true`, a `+`
  /// prefix is added for positive amounts.
  final bool showSign;

  /// Whether to omit decimal places when the paise component is zero.
  ///
  /// For example, `₹100` instead of `₹100.00`.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String formattedAmount;
    if (showSign) {
      formattedAmount = AmountUtils.formatAmountWithSign(amountInPaise);
    } else if (compact) {
      formattedAmount = AmountUtils.formatAmountCompact(amountInPaise);
    } else {
      formattedAmount = AmountUtils.formatAmount(amountInPaise);
    }

    final textStyle = _resolveTextStyle(context);
    final color = _resolveColor(context);

    return Text(
      formattedAmount,
      style: textStyle.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Resolves the [TextStyle] based on [size].
  TextStyle _resolveTextStyle(BuildContext context) {
    return switch (size) {
      AmountDisplaySize.small => AppTypography.amountSmall(context),
      AmountDisplaySize.medium => AppTypography.amountMedium(context),
      AmountDisplaySize.large => AppTypography.amountLarge(context),
    };
  }

  /// Resolves the display color based on [colorType].
  Color _resolveColor(BuildContext context) {
    final appColors = context.appColors;

    return switch (colorType) {
      AmountColorType.owe => appColors.oweColor,
      AmountColorType.owed => appColors.owedColor,
      AmountColorType.neutral => Theme.of(context).colorScheme.onSurface,
      AmountColorType.auto => _colorFromSign(appColors),
    };
  }

  /// Determines color from the sign of [amountInPaise].
  Color _colorFromSign(AppColorsExtension appColors) {
    if (amountInPaise > 0) return appColors.owedColor;
    if (amountInPaise < 0) return appColors.oweColor;
    return appColors.settledColor;
  }
}
