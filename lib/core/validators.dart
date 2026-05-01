/// Validates an Indian mobile phone number.
///
/// Returns `null` when [digits] is a valid 10-digit Indian mobile number
/// (first digit 6-9). Returns an error message string otherwise.
String? validateIndianMobile(String digits) {
  final valid = RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
  if (valid) return null;
  return 'Please enter a valid 10-digit mobile number.';
}
