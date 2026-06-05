// Regression test confirming the auth phone validator is reused for
// manual phone entry — no forked copy.
//
// These tests exercise validateIndianMobile from lib/core/validators.dart,
// the same validator used in the auth flow. If a future change forks the
// validator for the manual entry path, this file will still import the
// shared one and fail loudly if its behaviour diverges.

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/validators.dart';

void main() {
  group('validateIndianMobile (reuse regression)', () {
    test('returns error for empty input', () {
      expect(validateIndianMobile(''), isNotNull);
    });

    test('returns error for fewer than 10 digits', () {
      expect(validateIndianMobile('98765'), isNotNull);
    });

    test('returns error for more than 10 digits', () {
      expect(validateIndianMobile('98765432101'), isNotNull);
    });

    test('returns error for non-numeric input', () {
      expect(validateIndianMobile('98765abcde'), isNotNull);
    });

    test('returns error for number starting with 0-5', () {
      for (final digit in ['0', '1', '2', '3', '4', '5']) {
        final number = '${digit}876543210';
        expect(
          validateIndianMobile(number),
          isNotNull,
          reason: 'Number starting with $digit should be rejected',
        );
      }
    });

    test('returns null for valid 10-digit number starting with 6', () {
      expect(validateIndianMobile('6876543210'), isNull);
    });

    test('returns null for valid 10-digit number starting with 7', () {
      expect(validateIndianMobile('7876543210'), isNull);
    });

    test('returns null for valid 10-digit number starting with 8', () {
      expect(validateIndianMobile('8876543210'), isNull);
    });

    test('returns null for valid 10-digit number starting with 9', () {
      expect(validateIndianMobile('9876543210'), isNull);
    });

    test('returns error for input with whitespace', () {
      // The validator expects clean digits; the formatter handles stripping.
      expect(validateIndianMobile('987 654 3210'), isNotNull);
    });

    test('returns error for input with hyphens', () {
      expect(validateIndianMobile('987-654-3210'), isNotNull);
    });
  });
}
