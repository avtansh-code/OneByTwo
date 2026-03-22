import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/extensions/num_extensions.dart';

void main() {
  group('IntMoneyExtensions', () {
    // ── toRupees() ──────────────────────────────────────────────────────

    group('toRupees()', () {
      test('should convert 10050 paise to 100.50 rupees', () {
        expect(10050.toRupees(), equals(100.50));
      });

      test('should convert 0 paise to 0.0 rupees', () {
        expect(0.toRupees(), equals(0.0));
      });

      test('should convert 1 paisa to 0.01 rupees', () {
        expect(1.toRupees(), equals(0.01));
      });

      test('should convert 100 paise to 1.0 rupees', () {
        expect(100.toRupees(), equals(1.0));
      });

      test('should convert negative paise to negative rupees', () {
        expect((-5000).toRupees(), equals(-50.0));
      });

      test('should convert 99 paise to 0.99 rupees', () {
        expect(99.toRupees(), equals(0.99));
      });
    });

    // ── formatAsAmount() ────────────────────────────────────────────────

    group('formatAsAmount()', () {
      test('should format 10050 paise as ₹100.50', () {
        expect(10050.formatAsAmount(), equals('₹100.50'));
      });

      test('should format 0 paise as ₹0.00', () {
        expect(0.formatAsAmount(), equals('₹0.00'));
      });

      test('should format 1 paisa as ₹0.01', () {
        expect(1.formatAsAmount(), equals('₹0.01'));
      });

      test('should format with Indian grouping', () {
        expect(10000000.formatAsAmount(), equals('₹1,00,000.00'));
      });

      test('should format negative amount', () {
        expect((-10050).formatAsAmount(), equals('-₹100.50'));
      });
    });

    // ── formatAsCompactAmount() ─────────────────────────────────────────

    group('formatAsCompactAmount()', () {
      test('should format 10000000 paise as ₹1L', () {
        expect(10000000.formatAsCompactAmount(), equals('₹1L'));
      });

      test('should format 1000000000 paise as ₹1Cr', () {
        expect(1000000000.formatAsCompactAmount(), equals('₹1Cr'));
      });

      test('should format 100000 paise as ₹1K', () {
        expect(100000.formatAsCompactAmount(), equals('₹1K'));
      });

      test('should format small amount without suffix', () {
        expect(50000.formatAsCompactAmount(), equals('₹500'));
      });

      test('should format zero as ₹0', () {
        expect(0.formatAsCompactAmount(), equals('₹0'));
      });
    });

    // ── formatAsSignedAmount() ──────────────────────────────────────────

    group('formatAsSignedAmount()', () {
      test('should prefix positive amount with +', () {
        expect(10050.formatAsSignedAmount(), equals('+₹100.50'));
      });

      test('should prefix negative amount with -', () {
        expect((-10050).formatAsSignedAmount(), equals('-₹100.50'));
      });

      test('should show zero without sign', () {
        expect(0.formatAsSignedAmount(), equals('₹0.00'));
      });
    });
  });

  group('DoubleMoneyExtensions', () {
    // ── toPaise() ───────────────────────────────────────────────────────

    group('toPaise()', () {
      test('should convert 100.50 rupees to 10050 paise', () {
        expect(100.50.toPaise(), equals(10050));
      });

      test('should convert 0.0 rupees to 0 paise', () {
        expect(0.0.toPaise(), equals(0));
      });

      test('should convert 0.01 rupees to 1 paisa', () {
        expect(0.01.toPaise(), equals(1));
      });

      test('should convert 1.0 rupees to 100 paise', () {
        expect(1.0.toPaise(), equals(100));
      });

      test('should handle floating-point imprecision via rounding', () {
        // 0.1 + 0.2 = 0.30000000000000004 in IEEE 754
        expect((0.1 + 0.2).toPaise(), equals(30));
      });

      test('should convert large amount', () {
        expect(100000.0.toPaise(), equals(10000000));
      });

      test('should convert negative rupees to negative paise', () {
        expect((-50.0).toPaise(), equals(-5000));
      });
    });
  });
}
