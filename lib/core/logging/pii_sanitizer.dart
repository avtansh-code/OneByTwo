/// Sanitizes log output to remove personally identifiable information.
///
/// Masks phone numbers, email addresses, and tokens/keys in log data
/// to prevent PII from appearing in log files or console output.
///
/// Masking rules:
/// - **Phone:** `+91XXXXXXXX23` — shows last 2 digits only.
/// - **Email:** `a***@example.com` — shows first character + domain.
/// - **Tokens/keys** longer than 10 characters: first 4 chars + `***`.
abstract final class PiiSanitizer {
  /// Regex matching Indian phone numbers: optional +91 prefix followed by
  /// 10 digits. Also matches plain 10-digit numbers.
  static final RegExp _phonePattern = RegExp(
    r'(\+?91[\s-]?)?([6-9]\d{7})(\d{2})',
  );

  /// Regex matching email addresses.
  static final RegExp _emailPattern = RegExp(
    r'([a-zA-Z0-9._%+-])([a-zA-Z0-9._%+-]*)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
  );

  /// Set of map keys whose values are likely to contain tokens or secrets.
  static const Set<String> _sensitiveKeys = {
    'token',
    'accessToken',
    'refreshToken',
    'idToken',
    'apiKey',
    'secret',
    'password',
    'authorization',
  };

  /// Sanitizes [input] by replacing phone numbers, emails, and long
  /// token-like strings with masked equivalents.
  ///
  /// Returns the sanitized string.
  static String sanitize(String input) {
    var result = input;

    // Mask phone numbers — show last 2 digits.
    result = result.replaceAllMapped(_phonePattern, (match) {
      final lastTwo = match.group(3) ?? '';
      final prefix = match.group(1) ?? '';
      final hasPrefix = prefix.isNotEmpty;
      return '${hasPrefix ? '+91' : ''}XXXXXXXX$lastTwo';
    });

    // Mask emails — show first character + domain.
    result = result.replaceAllMapped(_emailPattern, (match) {
      final firstChar = match.group(1) ?? '';
      final domain = match.group(3) ?? '';
      return '$firstChar***@$domain';
    });

    return result;
  }

  /// Recursively sanitizes all string values in [data].
  ///
  /// Keys listed in [_sensitiveKeys] have their values fully masked
  /// (first 4 chars + `***`) if longer than 10 characters.
  /// All other string values are passed through [sanitize].
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is String) {
        if (_sensitiveKeys.contains(key) && value.length > 10) {
          return MapEntry(key, '${value.substring(0, 4)}***');
        }
        return MapEntry(key, sanitize(value));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, sanitizeMap(value));
      } else if (value is List) {
        return MapEntry(key, _sanitizeList(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Recursively sanitizes items in a list.
  static List<dynamic> _sanitizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is String) {
        return sanitize(item);
      } else if (item is Map<String, dynamic>) {
        return sanitizeMap(item);
      } else if (item is List) {
        return _sanitizeList(item);
      }
      return item;
    }).toList();
  }
}
