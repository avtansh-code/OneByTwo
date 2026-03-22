import 'package:one_by_two/core/constants/app_constants.dart';

/// Utility functions for formatting and parsing monetary amounts.
///
/// **CRITICAL:** All monetary values in the app are stored as [int] paise.
/// Never use [double] for money calculations. The `double` return from
/// [paiseToRupees] is for display purposes only.
///
/// Indian number formatting is used: `1,00,000` (not `100,000`).
abstract final class AmountUtils {
  /// Formats [paise] as an Indian currency string with the ₹ symbol.
  ///
  /// Uses Indian number grouping (lakhs and crores).
  ///
  /// Examples:
  /// ```dart
  /// AmountUtils.formatAmount(10050);       // → '₹100.50'
  /// AmountUtils.formatAmount(100000050);   // → '₹10,00,000.50'
  /// AmountUtils.formatAmount(0);           // → '₹0.00'
  /// AmountUtils.formatAmount(-10050);      // → '-₹100.50'
  /// ```
  static String formatAmount(int paise) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupees = absPaise ~/ AppConstants.paisePrecision;
    final remainingPaise = absPaise % AppConstants.paisePrecision;
    final paiseStr = remainingPaise.toString().padLeft(2, '0');
    final rupeesFormatted = _formatIndianNumber(rupees);
    final sign = isNegative ? '-' : '';
    return '$sign${AppConstants.currencySymbol}$rupeesFormatted.$paiseStr';
  }

  /// Formats [paise] as a compact Indian currency string.
  ///
  /// Uses abbreviations: K (thousands), L (lakhs), Cr (crores).
  ///
  /// Examples:
  /// ```dart
  /// AmountUtils.formatAmountCompact(10000000);   // → '₹1L'
  /// AmountUtils.formatAmountCompact(100000000);  // → '₹10L'
  /// AmountUtils.formatAmountCompact(1000000000); // → '₹1Cr'
  /// AmountUtils.formatAmountCompact(50000);       // → '₹500'
  /// ```
  static String formatAmountCompact(int paise) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupees = absPaise / AppConstants.paisePrecision;
    final sign = isNegative ? '-' : '';

    if (rupees >= 10000000) {
      // Crores
      final crores = rupees / 10000000;
      final formatted = _formatCompactNumber(crores);
      return '$sign${AppConstants.currencySymbol}${formatted}Cr';
    }

    if (rupees >= 100000) {
      // Lakhs
      final lakhs = rupees / 100000;
      final formatted = _formatCompactNumber(lakhs);
      return '$sign${AppConstants.currencySymbol}${formatted}L';
    }

    if (rupees >= 1000) {
      // Thousands
      final thousands = rupees / 1000;
      final formatted = _formatCompactNumber(thousands);
      return '$sign${AppConstants.currencySymbol}${formatted}K';
    }

    // Below ₹1,000 — show full amount without paise for compactness
    final wholeRupees = absPaise ~/ AppConstants.paisePrecision;
    final remainingPaise = absPaise % AppConstants.paisePrecision;
    if (remainingPaise == 0) {
      return '$sign${AppConstants.currencySymbol}$wholeRupees';
    }
    return '$sign${AppConstants.currencySymbol}$wholeRupees.${remainingPaise.toString().padLeft(2, '0')}';
  }

  /// Formats [paise] with a sign prefix.
  ///
  /// Positive values are prefixed with `+`, negative with `-`, zero has no sign.
  ///
  /// Examples:
  /// ```dart
  /// AmountUtils.formatAmountWithSign(10050);    // → '+₹100.50'
  /// AmountUtils.formatAmountWithSign(-10050);   // → '-₹100.50'
  /// AmountUtils.formatAmountWithSign(0);        // → '₹0.00'
  /// ```
  static String formatAmountWithSign(int paise) {
    if (paise > 0) {
      return '+${formatAmount(paise)}';
    }
    if (paise < 0) {
      return formatAmount(paise);
    }
    return formatAmount(0);
  }

  /// Parses a user-entered rupee amount string into paise.
  ///
  /// Strips currency symbols, commas, and whitespace before parsing.
  /// Returns the amount in paise as [int], or `null` if parsing fails.
  ///
  /// Examples:
  /// ```dart
  /// AmountUtils.parseAmount('100.50');       // → 10050
  /// AmountUtils.parseAmount('₹1,00,000');    // → 10000000
  /// AmountUtils.parseAmount('invalid');       // → null
  /// ```
  static int? parseAmount(String input) {
    final cleaned = input
        .trim()
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');

    if (cleaned.isEmpty) return null;

    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;

    return (parsed * AppConstants.paisePrecision).round();
  }

  /// Converts [paise] to rupees as a [double].
  ///
  /// **WARNING:** Use only for display purposes. Never use the returned
  /// [double] in arithmetic — all calculations must remain in paise.
  static double paiseToRupees(int paise) => paise / AppConstants.paisePrecision;

  /// Converts a rupee [double] value to paise.
  ///
  /// Uses [double.round] to handle floating-point imprecision.
  ///
  /// Example:
  /// ```dart
  /// AmountUtils.rupeesToPaise(100.50); // → 10050
  /// ```
  static int rupeesToPaise(double rupees) =>
      (rupees * AppConstants.paisePrecision).round();

  /// Splits [totalPaise] equally among [count] participants using the
  /// Largest Remainder Method.
  ///
  /// This guarantees:
  /// - `sum(result) == totalPaise` (no rounding loss)
  /// - All values are `>= 0`
  /// - At most 1 paisa difference between any two shares
  ///
  /// Throws [ArgumentError] if [count] is less than 1.
  ///
  /// Example:
  /// ```dart
  /// AmountUtils.splitEqually(100, 3); // → [34, 33, 33]
  /// AmountUtils.splitEqually(10, 3);  // → [4, 3, 3]
  /// ```
  static List<int> splitEqually(int totalPaise, int count) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be at least 1');
    }

    final base = totalPaise ~/ count;
    final remainder = totalPaise - (base * count);

    final splits = <int>[
      for (var i = 0; i < count; i++) base + (i < remainder ? 1 : 0),
    ];

    // Safety assertion: sum of splits must equal total
    assert(
      splits.fold<int>(0, (sum, v) => sum + v) == totalPaise,
      'Split sum ${splits.fold<int>(0, (sum, v) => sum + v)} does not match total $totalPaise',
    );

    return splits;
  }

  /// Formats an integer using Indian number grouping.
  ///
  /// In the Indian system, the first group (from the right) has 3 digits,
  /// and subsequent groups have 2 digits each.
  ///
  /// Examples:
  /// ```dart
  /// _formatIndianNumber(1000);     // → '1,000'
  /// _formatIndianNumber(100000);   // → '1,00,000'
  /// _formatIndianNumber(10000000); // → '1,00,00,000'
  /// ```
  static String _formatIndianNumber(int number) {
    if (number < 1000) return number.toString();

    final str = number.toString();
    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);

    if (remaining.isEmpty) return lastThree;

    // Group remaining digits in pairs from the right
    final buffer = StringBuffer();
    for (var i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }

    return '$buffer,$lastThree';
  }

  /// Formats a compact number, dropping trailing `.0`.
  static String _formatCompactNumber(double value) {
    if (value == value.roundToDouble() && value < 100) {
      return value.toInt().toString();
    }
    // Show one decimal place
    final formatted = value.toStringAsFixed(1);
    // Remove trailing .0
    if (formatted.endsWith('.0')) {
      return formatted.substring(0, formatted.length - 2);
    }
    return formatted;
  }
}
