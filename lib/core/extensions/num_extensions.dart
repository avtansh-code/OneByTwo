import 'package:one_by_two/core/constants/app_constants.dart';
import 'package:one_by_two/core/utils/amount_utils.dart';

/// Extensions on [int] for paise-based monetary operations.
///
/// All monetary values in the app are stored as [int] paise.
/// These extensions provide convenient conversion and formatting.
extension IntMoneyExtensions on int {
  /// Converts this value from paise to rupees.
  ///
  /// **Use only for display purposes** — never use the returned [double]
  /// in calculations. All arithmetic should remain in paise.
  ///
  /// Example:
  /// ```dart
  /// 10050.toRupees(); // → 100.5
  /// ```
  double toRupees() => this / AppConstants.paisePrecision;

  /// Formats this paise value as a human-readable Indian currency string.
  ///
  /// Uses Indian number grouping (e.g., ₹1,00,000.50).
  ///
  /// Example:
  /// ```dart
  /// 10050.formatAsAmount(); // → '₹100.50'
  /// 1000000050.formatAsAmount(); // → '₹1,00,00,000.50'
  /// ```
  String formatAsAmount() => AmountUtils.formatAmount(this);

  /// Formats this paise value as a compact Indian currency string.
  ///
  /// Example:
  /// ```dart
  /// 10000000.formatAsCompactAmount(); // → '₹1L'
  /// ```
  String formatAsCompactAmount() => AmountUtils.formatAmountCompact(this);

  /// Formats this paise value with a sign prefix.
  ///
  /// Positive values get `+`, negative get `-`, zero gets no sign.
  ///
  /// Example:
  /// ```dart
  /// 10050.formatAsSignedAmount();  // → '+₹100.50'
  /// (-10050).formatAsSignedAmount(); // → '-₹100.50'
  /// ```
  String formatAsSignedAmount() => AmountUtils.formatAmountWithSign(this);
}

/// Extensions on [double] for rupee-to-paise conversions.
///
/// Used primarily for converting user input (which is typically in rupees)
/// to the internal paise representation.
extension DoubleMoneyExtensions on double {
  /// Converts this rupee value to paise.
  ///
  /// Uses [double.round] to handle floating-point imprecision.
  ///
  /// Example:
  /// ```dart
  /// 100.50.toPaise(); // → 10050
  /// 0.01.toPaise();   // → 1
  /// ```
  int toPaise() => (this * AppConstants.paisePrecision).round();
}
