/// Extensions on [String] for common text transformations.
extension StringExtensions on String {
  /// Capitalizes the first letter of this string.
  ///
  /// Returns the original string if it is empty.
  ///
  /// Example:
  /// ```dart
  /// 'hello'.capitalize(); // → 'Hello'
  /// ''.capitalize();      // → ''
  /// ```
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalizes the first letter of every word in this string.
  ///
  /// Words are defined as sequences separated by whitespace.
  ///
  /// Example:
  /// ```dart
  /// 'hello world'.titleCase(); // → 'Hello World'
  /// ```
  String titleCase() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  /// Truncates this string to [maxLength] characters, appending [ellipsis]
  /// if truncation occurs.
  ///
  /// If the string is shorter than or equal to [maxLength], it is returned
  /// unchanged.
  ///
  /// Example:
  /// ```dart
  /// 'Hello World'.truncate(5);  // → 'Hello…'
  /// 'Hi'.truncate(5);           // → 'Hi'
  /// ```
  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$ellipsis';
  }

  /// Returns the initials from this string (up to [count] characters).
  ///
  /// Takes the first character of each word (split by whitespace) and
  /// converts them to uppercase.
  ///
  /// Example:
  /// ```dart
  /// 'John Doe'.initials();     // → 'JD'
  /// 'Alice Bob Charlie'.initials(count: 2); // → 'AB'
  /// ```
  String initials({int count = 2}) {
    if (isEmpty) return '';
    final words = trim().split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    for (var i = 0; i < words.length && i < count; i++) {
      if (words[i].isNotEmpty) {
        buffer.write(words[i][0].toUpperCase());
      }
    }
    return buffer.toString();
  }

  /// Formats a 10-digit Indian phone number for display.
  ///
  /// Adds the +91 prefix and groups digits as `+91 XXXXX XXXXX`.
  /// If the string is not exactly 10 digits, it is returned unchanged.
  ///
  /// Example:
  /// ```dart
  /// '9876543210'.formatAsIndianPhone(); // → '+91 98765 43210'
  /// ```
  String formatAsIndianPhone() {
    final digits = replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }
    return this;
  }

  /// Returns only the digit characters from this string.
  ///
  /// Example:
  /// ```dart
  /// '+91 98765 43210'.digitsOnly(); // → '919876543210'
  /// ```
  String digitsOnly() => replaceAll(RegExp(r'\D'), '');

  /// Returns `true` if this string is a valid email address.
  ///
  /// Uses a basic regex pattern — not RFC 5322 compliant, but suitable
  /// for most practical purposes.
  bool get isValidEmail {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(this);
  }

  /// Returns `true` if this string contains only whitespace or is empty.
  bool get isBlank => trim().isEmpty;

  /// Returns `true` if this string contains at least one non-whitespace
  /// character.
  bool get isNotBlank => !isBlank;

  /// Returns `null` if this string is blank, otherwise returns the
  /// original string.
  ///
  /// Useful for converting empty form inputs to null values.
  String? get nullIfBlank => isBlank ? null : this;
}
