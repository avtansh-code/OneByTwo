import 'package:one_by_two/core/constants/app_constants.dart';

/// Validation functions for user input throughout the app.
///
/// Each function returns `null` if the input is valid, or a [String] error
/// message describing the validation failure. This convention is compatible
/// with Flutter's `TextFormField.validator` parameter.
///
/// Example:
/// ```dart
/// TextFormField(
///   validator: (value) => Validators.phone(value),
/// );
/// ```
abstract final class Validators {
  /// Validates an Indian phone number.
  ///
  /// Accepts 10-digit numbers optionally prefixed with `+91` or `91`.
  /// Returns `null` if valid.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    // 10 digits without country code
    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return null;
    }

    // 12 digits with 91 country code
    if (digits.length == 12 &&
        digits.startsWith('91') &&
        RegExp(r'^91[6-9]\d{9}$').hasMatch(digits)) {
      return null;
    }

    return 'Enter a valid 10-digit Indian phone number';
  }

  /// Validates an email address.
  ///
  /// Uses a practical regex — not fully RFC 5322 compliant.
  /// Returns `null` if valid.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  /// Validates that a required field is not empty.
  ///
  /// [fieldName] is used in the error message (e.g., `'Description is required'`).
  /// Returns `null` if valid.
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a group name.
  ///
  /// Must be non-empty and at most [AppConstants.maxGroupNameLength]
  /// characters. Returns `null` if valid.
  static String? groupName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Group name is required';
    }

    if (value.trim().length > AppConstants.maxGroupNameLength) {
      return 'Group name must be ${AppConstants.maxGroupNameLength} characters or fewer';
    }

    return null;
  }

  /// Validates an expense description.
  ///
  /// Must be non-empty and at most [AppConstants.maxExpenseDescriptionLength]
  /// characters. Returns `null` if valid.
  static String? expenseDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }

    if (value.trim().length > AppConstants.maxExpenseDescriptionLength) {
      return 'Description must be ${AppConstants.maxExpenseDescriptionLength} characters or fewer';
    }

    return null;
  }

  /// Validates a notes field.
  ///
  /// Notes are optional, but if provided must be at most
  /// [AppConstants.maxNotesLength] characters. Returns `null` if valid.
  static String? notes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Notes are optional
    }

    if (value.trim().length > AppConstants.maxNotesLength) {
      return 'Notes must be ${AppConstants.maxNotesLength} characters or fewer';
    }

    return null;
  }

  /// Validates an expense amount string (in rupees, entered by the user).
  ///
  /// The amount must be:
  /// - Non-empty
  /// - A valid positive number
  /// - Greater than zero
  /// - At most 2 decimal places
  ///
  /// Returns `null` if valid.
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }

    final cleaned = value.trim().replaceAll(',', '').replaceAll('₹', '');

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return 'Enter a valid amount';
    }

    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }

    // Check at most 2 decimal places
    if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length == 2 && parts[1].length > 2) {
        return 'Amount can have at most 2 decimal places';
      }
    }

    return null;
  }

  /// Validates an OTP (One-Time Password).
  ///
  /// Must be exactly [AppConstants.otpLength] digits. Returns `null` if valid.
  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required';
    }

    final digits = value.trim().replaceAll(RegExp(r'\D'), '');

    if (digits.length != AppConstants.otpLength) {
      return 'OTP must be ${AppConstants.otpLength} digits';
    }

    return null;
  }

  /// Validates a display name (user's name).
  ///
  /// Must be non-empty and between 1 and 50 characters. Returns `null` if valid.
  static String? displayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length > 50) {
      return 'Name must be 50 characters or fewer';
    }

    return null;
  }

  /// Validates that a percentage value is between 0 and 100 (inclusive).
  ///
  /// Returns `null` if valid.
  static String? percentage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Percentage is required';
    }

    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (parsed < 0 || parsed > 100) {
      return 'Percentage must be between 0 and 100';
    }

    return null;
  }

  /// Validates that split shares is a positive integer.
  ///
  /// Returns `null` if valid.
  static String? shares(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Shares value is required';
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid whole number';
    }

    if (parsed <= 0) {
      return 'Shares must be greater than zero';
    }

    return null;
  }
}
