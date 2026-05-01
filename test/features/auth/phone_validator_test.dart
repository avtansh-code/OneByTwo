import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/validators.dart';

void main() {
  group('validateIndianMobile', () {
    test('accepts 9876543210 (starts with 9)', () {
      expect(validateIndianMobile('9876543210'), isNull);
    });

    test('accepts 6123456789 (starts with 6)', () {
      expect(validateIndianMobile('6123456789'), isNull);
    });

    test('accepts 7000000000 (starts with 7)', () {
      expect(validateIndianMobile('7000000000'), isNull);
    });

    test('accepts 8000000000 (starts with 8)', () {
      expect(validateIndianMobile('8000000000'), isNull);
    });

    test('rejects 9-digit input with error message', () {
      expect(
        validateIndianMobile('987654321'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects 11-digit input with error message', () {
      expect(
        validateIndianMobile('98765432101'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects input starting with 0', () {
      expect(
        validateIndianMobile('0123456789'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects input starting with 1', () {
      expect(
        validateIndianMobile('1234567890'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects input starting with 2', () {
      expect(
        validateIndianMobile('2345678901'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects input starting with 3', () {
      expect(
        validateIndianMobile('3456789012'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects input starting with 4', () {
      expect(
        validateIndianMobile('4567890123'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects input starting with 5', () {
      expect(
        validateIndianMobile('5678901234'),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test('rejects empty input with error message', () {
      expect(
        validateIndianMobile(''),
        equals('Please enter a valid 10-digit mobile number.'),
      );
    });

    test(r'matches valid Indian mobile regex ^[6-9]\d{9}$', () {
      // Boundary: first valid digit is 6, last is 9.
      expect(validateIndianMobile('6000000000'), isNull);
      expect(validateIndianMobile('9999999999'), isNull);
      // Just outside boundary.
      expect(validateIndianMobile('5999999999'), isNotNull);
    });
  });
}
