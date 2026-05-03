import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/domain/phone_normaliser.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

void main() {
  group('normaliseToE164', () {
    test('raw 10-digit number normalises to E.164', () {
      expect(normaliseToE164('9876543210'), '+919876543210');
    });

    test('already prefixed +91 stays the same', () {
      expect(normaliseToE164('+919876543210'), '+919876543210');
    });

    test('with spaces and hyphens normalises correctly', () {
      expect(normaliseToE164('+91 98765 43210'), '+919876543210');
    });

    test('with hyphens normalises correctly', () {
      expect(normaliseToE164('+91-9876-543-210'), '+919876543210');
    });

    test('non-Indian number is filtered out', () {
      expect(normaliseToE164('+447911123456'), isNull);
    });

    test('double-prefix +91+91 does not produce invalid result', () {
      // +91+919876543210 -> strip +91 -> +919876543210 -> strip +
      // digits = '919876543210' (12 digits with leading 91)
      // -> strip 91 prefix -> '9876543210' -> valid
      final result = normaliseToE164('+91+919876543210');
      expect(result, '+919876543210');
      expect(result, isNot('+91+919876543210'));
    });

    test('contact with leading zero normalises correctly', () {
      expect(normaliseToE164('09876543210'), '+919876543210');
    });

    test('number with 91 prefix and 12 digits normalises correctly', () {
      expect(normaliseToE164('919876543210'), '+919876543210');
    });

    test('number starting with 5 is rejected', () {
      expect(normaliseToE164('5678901234'), isNull);
    });

    test('number with fewer than 10 digits is rejected', () {
      expect(normaliseToE164('98765432'), isNull);
    });

    test('number with more than 10 digits (non-91 prefix) is rejected', () {
      expect(normaliseToE164('198765432100'), isNull);
    });

    test('number with parentheses and dots normalises correctly', () {
      expect(normaliseToE164('(098) 765.432.10'), '+919876543210');
    });

    test('US number with +1 prefix is rejected', () {
      expect(normaliseToE164('+12025551234'), isNull);
    });
  });

  group('normalisePhoneNumbers', () {
    test('filters out non-Indian numbers from a mixed list', () {
      final result = normalisePhoneNumbers([
        '9876543210',
        '+447911123456',
        '8765432109',
      ]);

      expect(result, ['+919876543210', '+918765432109']);
    });

    test('removes duplicate normalised numbers', () {
      final result = normalisePhoneNumbers([
        '9876543210',
        '+919876543210',
        '09876543210',
      ]);

      expect(result, ['+919876543210']);
    });

    test('returns empty list when all numbers are non-Indian', () {
      final result = normalisePhoneNumbers(['+447911123456', '+12025551234']);

      expect(result, isEmpty);
    });
  });

  group('SelectedContact', () {
    test('toMap returns correct hand-off shape', () {
      const contact = SelectedContact(
        displayName: 'Amit Kumar',
        phoneNumbers: ['+919876543210'],
      );

      final map = contact.toMap();

      expect(map, {
        'displayName': 'Amit Kumar',
        'phoneNumbers': ['+919876543210'],
      });
    });

    test('toMap keys are exactly displayName and phoneNumbers', () {
      const contact = SelectedContact(
        displayName: 'Test',
        phoneNumbers: ['+919876543210'],
      );

      final map = contact.toMap();

      expect(map.keys, containsAll(['displayName', 'phoneNumbers']));
      expect(map.keys, hasLength(2));
    });

    test('equality works for identical values', () {
      const a = SelectedContact(
        displayName: 'Amit',
        phoneNumbers: ['+919876543210'],
      );
      const b = SelectedContact(
        displayName: 'Amit',
        phoneNumbers: ['+919876543210'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality for different names', () {
      const a = SelectedContact(
        displayName: 'Amit',
        phoneNumbers: ['+919876543210'],
      );
      const b = SelectedContact(
        displayName: 'Priya',
        phoneNumbers: ['+919876543210'],
      );

      expect(a, isNot(equals(b)));
    });

    test('toString includes displayName and phoneNumbers', () {
      const contact = SelectedContact(
        displayName: 'Amit',
        phoneNumbers: ['+919876543210'],
      );

      expect(contact.toString(), contains('Amit'));
      expect(contact.toString(), contains('+919876543210'));
    });
  });
}
