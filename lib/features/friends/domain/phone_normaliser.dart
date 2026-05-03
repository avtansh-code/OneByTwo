/// Normalises a raw phone number string to E.164 Indian format.
///
/// Returns `null` if the number is not a valid Indian mobile number
/// after normalisation.
///
/// Rules:
/// - Strips spaces, hyphens, parentheses, dots.
/// - Strips leading `+91`, `91`, or `0` prefix.
/// - Result must be exactly 10 digits starting with 6, 7, 8, or 9.
/// - Returns `+91` + 10 digits.
String? normaliseToE164(String raw) {
  // Strip non-digit characters except leading +
  var digits = raw.replaceAll(RegExp(r'[^\d+]'), '');

  // Remove leading + and country code variants.
  // Loop to handle double-prefix cases like +91+919876543210.
  var changed = true;
  while (changed) {
    changed = false;
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
      changed = true;
    } else if (digits.startsWith('+')) {
      // Non-Indian international number
      return null;
    }
  }

  // Strip any remaining + (defensive)
  digits = digits.replaceAll('+', '');

  // Strip domestic trunk prefix or country code without +
  if (digits.startsWith('91') && digits.length > 10) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  // Must be exactly 10 digits
  if (digits.length != 10) return null;

  // Must start with 6, 7, 8, or 9 (Indian mobile)
  if (!RegExp('^[6-9]').hasMatch(digits)) return null;

  return '+91$digits';
}

/// Normalises a list of raw phone numbers, filtering out non-Indian numbers.
///
/// Duplicates are removed; order is preserved.
List<String> normalisePhoneNumbers(List<String> rawNumbers) {
  final results = <String>[];
  for (final raw in rawNumbers) {
    final normalised = normaliseToE164(raw);
    if (normalised != null && !results.contains(normalised)) {
      results.add(normalised);
    }
  }
  return results;
}
