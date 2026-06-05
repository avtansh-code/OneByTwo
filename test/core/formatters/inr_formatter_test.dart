// INR formatter tests.
//
// Tests `formatInrFromPaise(int paise)` — the SINGLE source of truth for
// converting an integer paise amount to a human-readable INR string using
// the Indian numbering system (lakh / crore separators) per SRS section 5.9.
// The formatter must use only integer arithmetic on the paise value
// (invariant 1: no `double` ever touches money).
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until `lib/core/formatters/inr_formatter.dart`
// is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';

void main() {
  group('formatInrFromPaise — small values and zero', () {
    test('0 paise → "₹0.00" (always two decimal places per SRS 5.9)', () {
      expect(formatInrFromPaise(0), '₹0.00');
    });

    test('1 paise → "₹0.01"', () {
      expect(formatInrFromPaise(1), '₹0.01');
    });

    test('99 paise → "₹0.99"', () {
      expect(formatInrFromPaise(99), '₹0.99');
    });

    test('100 paise → "₹1.00"', () {
      expect(formatInrFromPaise(100), '₹1.00');
    });

    test('12345 paise → "₹123.45"', () {
      expect(formatInrFromPaise(12345), '₹123.45');
    });
  });

  group('formatInrFromPaise — Indian numbering system (lakh / crore)', () {
    test('100000 paise → "₹1,000.00" (one-thousand rupees)', () {
      expect(formatInrFromPaise(100000), '₹1,000.00');
    });

    test('1000000 paise → "₹10,000.00"', () {
      expect(formatInrFromPaise(1000000), '₹10,000.00');
    });

    test('10000000 paise → "₹1,00,000.00" (one lakh — lakh separator)', () {
      expect(formatInrFromPaise(10000000), '₹1,00,000.00');
    });

    test('123456789 paise → "₹12,34,567.89" (Indian numbering)', () {
      expect(formatInrFromPaise(123456789), '₹12,34,567.89');
    });

    test(
      '1000000000000 paise → "₹10,00,00,00,000.00" (one thousand crore)',
      () {
        // 1,000,000,000,000 paise = 10,000,000,000 rupees = 1000 crore
        // = "10,00,00,00,000.00" in Indian numbering.
        expect(formatInrFromPaise(1000000000000), '₹10,00,00,00,000.00');
      },
    );
  });

  group('formatInrFromPaise — negative values', () {
    test('-1 paise → "−₹0.01" (Unicode minus, per SRS section 5.9)', () {
      expect(formatInrFromPaise(-1), '−₹0.01');
    });

    test('-5000 paise → "−₹50.00"', () {
      expect(formatInrFromPaise(-5000), '−₹50.00');
    });

    test('-123456789 paise → "−₹12,34,567.89"', () {
      expect(formatInrFromPaise(-123456789), '−₹12,34,567.89');
    });

    test('uses Unicode minus (U+2212), not ASCII hyphen', () {
      final formatted = formatInrFromPaise(-100);
      expect(formatted.contains('\u2212'), isTrue);
      expect(formatted.startsWith('-'), isFalse);
    });
  });

  group('formatInrFromPaise — robustness', () {
    test('does not throw for very large positive value', () {
      // A balance equivalent to roughly 9 quadrillion rupees.
      expect(() => formatInrFromPaise(900000000000000000), returnsNormally);
    });

    test('does not throw for very large negative value', () {
      expect(() => formatInrFromPaise(-900000000000000000), returnsNormally);
    });

    test('always prefixes with "₹" (never bare digits)', () {
      for (final paise in [0, 1, 100, 12345, -1, -100, 99999999]) {
        final out = formatInrFromPaise(paise);
        expect(
          out.contains('₹'),
          isTrue,
          reason: 'Missing ₹ symbol for $paise: "$out"',
        );
      }
    });

    test('always shows exactly two decimal digits', () {
      for (final paise in [0, 100, 12345, -1, -100, 99999999]) {
        final out = formatInrFromPaise(paise);
        // Strip the ₹ and any minus prefix, then check the fractional part.
        final stripped = out.replaceAll('₹', '').replaceAll('\u2212', '');
        final parts = stripped.split('.');
        expect(
          parts,
          hasLength(2),
          reason: 'Expected exactly one decimal point in "$out"',
        );
        expect(
          parts[1].length,
          2,
          reason: 'Expected two fractional digits in "$out"',
        );
      }
    });
  });
}
