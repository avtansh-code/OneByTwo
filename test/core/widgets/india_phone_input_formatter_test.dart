import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/widgets/india_phone_input_formatter.dart';

void main() {
  late IndianPhoneInputFormatter formatter;

  setUp(() {
    formatter = IndianPhoneInputFormatter();
  });

  /// Helper that simulates a [TextInputFormatter.formatEditUpdate] call.
  TextEditingValue applyFormatter(String newText) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );
  }

  group('IndianPhoneInputFormatter', () {
    test('strips non-digit input (letters)', () {
      final result = applyFormatter('98abc76543');
      expect(result.text, equals('9876543'));
    });

    test('strips non-digit input (special characters)', () {
      final result = applyFormatter('98-765+4321!0');
      expect(result.text, equals('9876543210'));
    });

    test('caps total length at 10 digits', () {
      final result = applyFormatter('98765432101234');
      expect(result.text, equals('9876543210'));
      expect(result.text.length, equals(10));
    });

    test('strips leading "+91" prefix from pasted numbers', () {
      final result = applyFormatter('+919876543210');
      expect(result.text, equals('9876543210'));
    });

    test('strips leading "91" prefix from pasted numbers', () {
      final result = applyFormatter('919876543210');
      expect(result.text, equals('9876543210'));
    });

    test('strips leading "091" prefix from pasted numbers', () {
      final result = applyFormatter('0919876543210');
      expect(result.text, equals('9876543210'));
    });

    test('empty input returns empty string', () {
      final result = applyFormatter('');
      expect(result.text, equals(''));
    });

    test('does not strip "91" when result would be <= 10 digits', () {
      // "9112345" is only 7 digits — the "91" is part of the number.
      final result = applyFormatter('9112345');
      expect(result.text, equals('9112345'));
    });
  });

  group('IndianPhoneDisplayFormatter', () {
    late IndianPhoneDisplayFormatter displayFormatter;

    setUp(() {
      displayFormatter = IndianPhoneDisplayFormatter();
    });

    TextEditingValue applyDisplay(String newText) {
      return displayFormatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('inserts a space after the fifth digit', () {
      expect(applyDisplay('9876543210').text, equals('98765 43210'));
    });

    test('no space for five or fewer digits', () {
      expect(applyDisplay('98765').text, equals('98765'));
      expect(applyDisplay('9876').text, equals('9876'));
    });

    test('groups partial input beyond five digits', () {
      expect(applyDisplay('987654').text, equals('98765 4'));
    });

    test('strips non-digits before grouping', () {
      expect(applyDisplay('98765-43210').text, equals('98765 43210'));
    });

    test('caps at ten digits', () {
      expect(applyDisplay('98765432109999').text, equals('98765 43210'));
    });

    test('collapses the cursor to the end of the formatted text', () {
      final result = applyDisplay('9876543210');
      expect(result.selection.baseOffset, equals('98765 43210'.length));
    });

    test('empty input returns empty string', () {
      expect(applyDisplay('').text, equals(''));
    });
  });
}
