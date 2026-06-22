import 'package:flutter/services.dart';

/// A [TextInputFormatter] for Indian mobile numbers.
///
/// Strips non-digit characters, removes leading country-code prefixes
/// (+91, 91, 091) from pasted input, and caps the result at 10 digits.
class IndianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip all non-digit characters.
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Strip leading country-code prefixes only when the raw digit string
    // is longer than 10 characters (to avoid stripping "91..." that is
    // genuinely part of a short number the user is still typing).
    if (digits.length > 10) {
      if (digits.startsWith('091')) {
        digits = digits.substring(3);
      } else if (digits.startsWith('91')) {
        digits = digits.substring(2);
      }
    }

    // Cap at 10 digits.
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// A [TextInputFormatter] that renders an Indian mobile number in the
/// `XXXXX XXXXX` display grouping (a single space after the fifth digit).
///
/// Strips non-digit characters and caps the result at 10 digits, then
/// inserts a single separating space once more than five digits are
/// present. The grouping is for display only; callers should strip the
/// space before storing or validating (see
/// `PhoneEntryController.updatePhoneNumber`). Intended to be chained after
/// [IndianPhoneInputFormatter], which strips any pasted country-code prefix.
class IndianPhoneDisplayFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    final formatted = digits.length > 5
        ? '${digits.substring(0, 5)} ${digits.substring(5)}'
        : digits;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
