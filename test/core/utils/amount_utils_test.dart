// Money invariant checks use `is int` on statically-typed ints — intentional.
// ignore_for_file: unnecessary_type_check

import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/utils/amount_utils.dart';

void main() {
  group('AmountUtils', () {
    // ── formatAmount ────────────────────────────────────────────────────

    group('formatAmount', () {
      test('should format 0 paise as ₹0.00', () {
        expect(AmountUtils.formatAmount(0), equals('₹0.00'));
      });

      test('should format 1 paisa as ₹0.01', () {
        expect(AmountUtils.formatAmount(1), equals('₹0.01'));
      });

      test('should format 100 paise as ₹1.00', () {
        expect(AmountUtils.formatAmount(100), equals('₹1.00'));
      });

      test('should format 10050 paise as ₹100.50', () {
        expect(AmountUtils.formatAmount(10050), equals('₹100.50'));
      });

      test('should format 99999 paise as ₹999.99', () {
        expect(AmountUtils.formatAmount(99999), equals('₹999.99'));
      });

      test('should format ₹1,000 with Indian grouping', () {
        expect(AmountUtils.formatAmount(100000), equals('₹1,000.00'));
      });

      test('should format ₹10,000 with Indian grouping', () {
        expect(AmountUtils.formatAmount(1000000), equals('₹10,000.00'));
      });

      test('should format ₹1,00,000 with Indian grouping', () {
        expect(AmountUtils.formatAmount(10000000), equals('₹1,00,000.00'));
      });

      test('should format ₹10,00,000 with Indian grouping', () {
        expect(AmountUtils.formatAmount(100000000), equals('₹10,00,000.00'));
      });

      test('should format ₹1,00,00,000 with Indian grouping', () {
        expect(AmountUtils.formatAmount(1000000000), equals('₹1,00,00,000.00'));
      });

      test('should format negative amount with minus sign', () {
        expect(AmountUtils.formatAmount(-10050), equals('-₹100.50'));
      });

      test('should format large negative amount', () {
        expect(AmountUtils.formatAmount(-10000000), equals('-₹1,00,000.00'));
      });

      test('should handle single-digit paise correctly', () {
        expect(AmountUtils.formatAmount(5), equals('₹0.05'));
      });

      test('should handle 10 paise correctly', () {
        expect(AmountUtils.formatAmount(10), equals('₹0.10'));
      });
    });

    // ── formatAmountCompact ─────────────────────────────────────────────

    group('formatAmountCompact', () {
      test('should format below ₹1,000 without suffix', () {
        expect(AmountUtils.formatAmountCompact(50000), equals('₹500'));
      });

      test('should format below ₹1,000 with paise', () {
        expect(AmountUtils.formatAmountCompact(50050), equals('₹500.50'));
      });

      test('should format ₹0 as ₹0', () {
        expect(AmountUtils.formatAmountCompact(0), equals('₹0'));
      });

      test('should format ₹1,000 as ₹1K', () {
        expect(AmountUtils.formatAmountCompact(100000), equals('₹1K'));
      });

      test('should format ₹5,500 as ₹5.5K', () {
        expect(AmountUtils.formatAmountCompact(550000), equals('₹5.5K'));
      });

      test('should format ₹10,000 as ₹10K', () {
        expect(AmountUtils.formatAmountCompact(1000000), equals('₹10K'));
      });

      test('should format ₹1,00,000 (1 lakh) as ₹1L', () {
        expect(AmountUtils.formatAmountCompact(10000000), equals('₹1L'));
      });

      test('should format ₹10,00,000 (10 lakhs) as ₹10L', () {
        expect(AmountUtils.formatAmountCompact(100000000), equals('₹10L'));
      });

      test('should format ₹50,00,000 (50 lakhs) as ₹50L', () {
        expect(AmountUtils.formatAmountCompact(500000000), equals('₹50L'));
      });

      test('should format ₹1,00,00,000 (1 crore) as ₹1Cr', () {
        expect(AmountUtils.formatAmountCompact(1000000000), equals('₹1Cr'));
      });

      test('should format ₹10,00,00,000 (10 crores) as ₹10Cr', () {
        expect(AmountUtils.formatAmountCompact(10000000000), equals('₹10Cr'));
      });

      test('should format ₹1.5 crores as ₹1.5Cr', () {
        expect(AmountUtils.formatAmountCompact(1500000000), equals('₹1.5Cr'));
      });

      test('should format negative compact amount', () {
        expect(AmountUtils.formatAmountCompact(-10000000), equals('-₹1L'));
      });
    });

    // ── formatAmountWithSign ────────────────────────────────────────────

    group('formatAmountWithSign', () {
      test('should prefix positive with +₹', () {
        expect(AmountUtils.formatAmountWithSign(10050), equals('+₹100.50'));
      });

      test('should prefix negative with -₹', () {
        expect(AmountUtils.formatAmountWithSign(-10050), equals('-₹100.50'));
      });

      test('should show zero without sign as ₹0.00', () {
        expect(AmountUtils.formatAmountWithSign(0), equals('₹0.00'));
      });

      test('should handle large positive amount', () {
        expect(
          AmountUtils.formatAmountWithSign(10000000),
          equals('+₹1,00,000.00'),
        );
      });

      test('should handle large negative amount', () {
        expect(
          AmountUtils.formatAmountWithSign(-10000000),
          equals('-₹1,00,000.00'),
        );
      });

      test('should handle 1 paisa positive', () {
        expect(AmountUtils.formatAmountWithSign(1), equals('+₹0.01'));
      });

      test('should handle -1 paisa', () {
        expect(AmountUtils.formatAmountWithSign(-1), equals('-₹0.01'));
      });
    });

    // ── parseAmount ─────────────────────────────────────────────────────

    group('parseAmount', () {
      test('should parse "100.50" to 10050 paise', () {
        expect(AmountUtils.parseAmount('100.50'), equals(10050));
      });

      test('should parse "₹1,000" to 100000 paise', () {
        expect(AmountUtils.parseAmount('₹1,000'), equals(100000));
      });

      test('should parse "1,00,000" to 10000000 paise', () {
        expect(AmountUtils.parseAmount('1,00,000'), equals(10000000));
      });

      test('should parse "0" to 0 paise', () {
        expect(AmountUtils.parseAmount('0'), equals(0));
      });

      test('should parse "0.01" to 1 paisa', () {
        expect(AmountUtils.parseAmount('0.01'), equals(1));
      });

      test('should parse "₹ 500" with space', () {
        expect(AmountUtils.parseAmount('₹ 500'), equals(50000));
      });

      test('should parse "  100.50  " with whitespace', () {
        expect(AmountUtils.parseAmount('  100.50  '), equals(10050));
      });

      test('should return null for empty string', () {
        expect(AmountUtils.parseAmount(''), isNull);
      });

      test('should return null for whitespace-only string', () {
        expect(AmountUtils.parseAmount('   '), isNull);
      });

      test('should return null for "invalid"', () {
        expect(AmountUtils.parseAmount('invalid'), isNull);
      });

      test('should return null for "abc"', () {
        expect(AmountUtils.parseAmount('abc'), isNull);
      });

      test('should parse whole number "500" to 50000 paise', () {
        expect(AmountUtils.parseAmount('500'), equals(50000));
      });

      test('should parse "1" to 100 paise', () {
        expect(AmountUtils.parseAmount('1'), equals(100));
      });
    });

    // ── paiseToRupees ───────────────────────────────────────────────────

    group('paiseToRupees', () {
      test('should convert 10050 paise to 100.5 rupees', () {
        expect(AmountUtils.paiseToRupees(10050), equals(100.5));
      });

      test('should convert 0 paise to 0.0 rupees', () {
        expect(AmountUtils.paiseToRupees(0), equals(0.0));
      });

      test('should convert 1 paisa to 0.01 rupees', () {
        expect(AmountUtils.paiseToRupees(1), equals(0.01));
      });

      test('should convert 100 paise to 1.0 rupees', () {
        expect(AmountUtils.paiseToRupees(100), equals(1.0));
      });

      test('should convert negative paise', () {
        expect(AmountUtils.paiseToRupees(-5000), equals(-50.0));
      });
    });

    // ── rupeesToPaise ───────────────────────────────────────────────────

    group('rupeesToPaise', () {
      test('should convert 100.5 rupees to 10050 paise', () {
        expect(AmountUtils.rupeesToPaise(100.5), equals(10050));
      });

      test('should convert 0.0 rupees to 0 paise', () {
        expect(AmountUtils.rupeesToPaise(0.0), equals(0));
      });

      test('should convert 0.01 rupees to 1 paisa', () {
        expect(AmountUtils.rupeesToPaise(0.01), equals(1));
      });

      test('should convert 1.0 rupees to 100 paise', () {
        expect(AmountUtils.rupeesToPaise(1.0), equals(100));
      });

      test('should handle floating-point imprecision via rounding', () {
        // 0.1 + 0.2 ≠ 0.3 in IEEE 754, but rounding corrects it
        expect(AmountUtils.rupeesToPaise(0.1 + 0.2), equals(30));
      });
    });

    // ── splitEqually ────────────────────────────────────────────────────

    group('splitEqually', () {
      test('should split evenly when divisible: 30000 / 3', () {
        // Arrange
        const total = 30000;
        const count = 3;

        // Act
        final splits = AmountUtils.splitEqually(total, count);

        // Assert
        expect(splits, equals([10000, 10000, 10000]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test(
        'should distribute remainder using Largest Remainder: 10000 / 3',
        () {
          // Arrange
          const total = 10000;
          const count = 3;

          // Act
          final splits = AmountUtils.splitEqually(total, count);

          // Assert — 10000 / 3 = 3333 r 1, so first person gets +1
          expect(splits, equals([3334, 3333, 3333]));
          expect(splits.reduce((a, b) => a + b), equals(total));
          expect(splits.every((s) => s >= 0), isTrue);
          expect(splits.every((s) => s is int), isTrue);
        },
      );

      test('should distribute remainder: 100 / 3', () {
        const total = 100;
        const count = 3;

        final splits = AmountUtils.splitEqually(total, count);

        expect(splits, equals([34, 33, 33]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test('should handle 1 paisa among 3 people', () {
        const total = 1;
        const count = 3;

        final splits = AmountUtils.splitEqually(total, count);

        expect(splits, equals([1, 0, 0]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test('should handle 0 paise among 3 people', () {
        const total = 0;
        const count = 3;

        final splits = AmountUtils.splitEqually(total, count);

        expect(splits, equals([0, 0, 0]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test('should handle single participant', () {
        const total = 10000;

        final splits = AmountUtils.splitEqually(total, 1);

        expect(splits, equals([10000]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test('should handle 2 paise among 5 people', () {
        const total = 2;
        const count = 5;

        final splits = AmountUtils.splitEqually(total, count);

        expect(splits, equals([1, 1, 0, 0, 0]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test('should handle large group (50+ members)', () {
        const total = 100000;
        const count = 51;

        final splits = AmountUtils.splitEqually(total, count);

        expect(splits.length, equals(count));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);

        // All values should be either floor or floor+1
        const floor = total ~/ count;
        for (final s in splits) {
          expect(s, greaterThanOrEqualTo(floor));
          expect(s, lessThanOrEqualTo(floor + 1));
        }
      });

      test('should handle remainder equal to count - 1', () {
        // 4 paise / 5 people → [1, 1, 1, 1, 0]
        const total = 4;
        const count = 5;

        final splits = AmountUtils.splitEqually(total, count);

        expect(splits, equals([1, 1, 1, 1, 0]));
        expect(splits.reduce((a, b) => a + b), equals(total));
        expect(splits.every((s) => s >= 0), isTrue);
        expect(splits.every((s) => s is int), isTrue);
      });

      test('should throw ArgumentError when count is 0', () {
        expect(
          () => AmountUtils.splitEqually(100, 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError when count is negative', () {
        expect(
          () => AmountUtils.splitEqually(100, -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('sum invariant holds for many random-ish amounts and counts', () {
        // Parametric test across various combinations
        final testCases = [
          (1001, 3),
          (7, 4),
          (9999, 7),
          (1, 1),
          (0, 10),
          (50000, 13),
          (123456, 17),
          (999999, 50),
          (3, 2),
          (100, 100),
        ];

        for (final (total, count) in testCases) {
          final splits = AmountUtils.splitEqually(total, count);

          // Money invariant: sum == total
          expect(
            splits.reduce((a, b) => a + b),
            equals(total),
            reason: 'sum($splits) should equal $total',
          );

          // All non-negative
          expect(
            splits.every((s) => s >= 0),
            isTrue,
            reason: 'All splits should be >= 0 for total=$total, count=$count',
          );

          // All integers (type system enforces this, but verify for safety)
          expect(
            splits.every((s) => s is int),
            isTrue,
            reason: 'All splits should be int',
          );

          // Max - min difference is at most 1
          final maxSplit = splits.reduce((a, b) => a > b ? a : b);
          final minSplit = splits.reduce((a, b) => a < b ? a : b);
          expect(
            maxSplit - minSplit,
            lessThanOrEqualTo(1),
            reason:
                'Max-min diff should be <= 1 for total=$total, count=$count',
          );

          // Correct count
          expect(splits.length, equals(count));
        }
      });
    });
  });
}
