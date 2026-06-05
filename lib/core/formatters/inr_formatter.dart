import 'package:intl/intl.dart';

/// Formats an integer paise amount as a human-readable INR string using
/// the Indian numbering system (lakh / crore separators) per
/// SRS section 5.9 and FR-EX-09.
///
/// This is the **single source of truth** for paise → INR conversion
/// in the application. Every widget that displays a balance must call
/// this function; no inline arithmetic of the form `paise / 100` is
/// permitted anywhere else in the codebase (invariant 1).
///
/// Formatting rules:
///
/// - Always shows exactly two decimal digits (e.g. `₹0.00`, `₹1.00`).
/// - Uses Indian-numbering grouping for the rupee component
///   (`₹1,23,456.78`).
/// - Negative values are prefixed with the Unicode minus sign
///   (U+2212): `−₹50.00`. The ASCII hyphen-minus is not used.
/// - The currency symbol is always `₹`. Callers cannot override it.
///
/// All arithmetic is performed on `int` values via integer division
/// (`~/`) and modulo (`%`); no `double` value is ever computed from a
/// paise amount.
String formatInrFromPaise(int paise) {
  final absPaise = paise.abs();
  final rupees = absPaise ~/ 100;
  final remainderPaise = absPaise % 100;

  final rupeeFormatter = NumberFormat.decimalPattern('en_IN');
  final rupeeStr = rupeeFormatter.format(rupees);
  final paiseStr = remainderPaise.toString().padLeft(2, '0');

  final prefix = paise < 0 ? '\u2212' : '';
  return '$prefix₹$rupeeStr.$paiseStr';
}
