import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/utils/amount_formatter.dart';

void main() {
  group('AmountFormatter', () {
    group('formatAmount', () {
      test('formats zero correctly', () {
        expect(AmountFormatter.formatAmount(0), '₹0');
      });

      test('formats small amount with decimals', () {
        expect(AmountFormatter.formatAmount(10050), '₹100.5');
      });

      test('formats amount without decimals when decimal part is zero', () {
        expect(AmountFormatter.formatAmount(10000), '₹100');
      });

      test('formats thousand with comma', () {
        expect(AmountFormatter.formatAmount(100000), '₹1,000');
      });

      test('formats lakh with Indian number system', () {
        expect(AmountFormatter.formatAmount(10000000), '₹1,00,000');
      });

      test('formats crore with Indian number system', () {
        expect(AmountFormatter.formatAmount(1000000000), '₹1,00,00,000');
      });

      test('hides decimals when showDecimals is false', () {
        expect(AmountFormatter.formatAmount(10050, showDecimals: false), '₹101');
      });
    });

    group('formatAmountCompact', () {
      test('formats small amount normally', () {
        expect(AmountFormatter.formatAmountCompact(50000), '₹500');
      });

      test('formats thousands with K suffix', () {
        expect(AmountFormatter.formatAmountCompact(120000), '₹1.2K');
      });

      test('formats lakhs with L suffix', () {
        expect(AmountFormatter.formatAmountCompact(10000000), '₹1L');
      });

      test('formats crores with Cr suffix', () {
        expect(AmountFormatter.formatAmountCompact(10000000000), '₹10Cr');
      });
    });

    group('formatAmountWithSign', () {
      test('formats zero without sign', () {
        expect(AmountFormatter.formatAmountWithSign(0), '₹0');
      });

      test('formats positive amount with + sign', () {
        expect(AmountFormatter.formatAmountWithSign(10050), '+₹100.5');
      });

      test('formats negative amount with - sign', () {
        expect(AmountFormatter.formatAmountWithSign(-10050), '-₹100.5');
      });
    });

    group('parseAmount', () {
      test('parses simple amount', () {
        expect(AmountFormatter.parseAmount('100'), 10000);
      });

      test('parses amount with decimals', () {
        expect(AmountFormatter.parseAmount('100.50'), 10050);
      });

      test('parses amount with commas', () {
        expect(AmountFormatter.parseAmount('1,000'), 100000);
      });

      test('parses amount with rupee symbol', () {
        expect(AmountFormatter.parseAmount('₹100'), 10000);
      });

      test('returns null for invalid input', () {
        expect(AmountFormatter.parseAmount('invalid'), null);
      });
    });

    group('conversion helpers', () {
      test('paiseToRupees converts correctly', () {
        expect(AmountFormatter.paiseToRupees(10050), 100.5);
      });

      test('rupeesToPaise converts correctly', () {
        expect(AmountFormatter.rupeesToPaise(100.5), 10050);
      });
    });
  });
}
