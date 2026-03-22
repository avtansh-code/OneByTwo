import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/extensions/string_extensions.dart';

void main() {
  group('StringExtensions', () {
    // ── capitalize() ────────────────────────────────────────────────────

    group('capitalize()', () {
      test('should capitalize first letter of lowercase string', () {
        expect('hello'.capitalize(), equals('Hello'));
      });

      test('should return same string if already capitalized', () {
        expect('Hello'.capitalize(), equals('Hello'));
      });

      test('should return empty string for empty input', () {
        expect(''.capitalize(), equals(''));
      });

      test('should handle single character', () {
        expect('a'.capitalize(), equals('A'));
      });

      test('should handle all-uppercase string', () {
        expect('HELLO'.capitalize(), equals('HELLO'));
      });

      test('should handle string starting with number', () {
        expect('123abc'.capitalize(), equals('123abc'));
      });
    });

    // ── titleCase() ─────────────────────────────────────────────────────

    group('titleCase()', () {
      test('should capitalize first letter of each word', () {
        expect('hello world'.titleCase(), equals('Hello World'));
      });

      test('should handle single word', () {
        expect('hello'.titleCase(), equals('Hello'));
      });

      test('should return empty string for empty input', () {
        expect(''.titleCase(), equals(''));
      });

      test('should handle already title-cased string', () {
        expect('Hello World'.titleCase(), equals('Hello World'));
      });

      test('should handle multiple spaces between words', () {
        // split(' ') will create empty strings for consecutive spaces
        expect('hello  world'.titleCase(), equals('Hello  World'));
      });

      test('should handle three words', () {
        expect('foo bar baz'.titleCase(), equals('Foo Bar Baz'));
      });
    });

    // ── truncate() ──────────────────────────────────────────────────────

    group('truncate()', () {
      test('should truncate long string and add ellipsis', () {
        expect('Hello World'.truncate(5), equals('Hello…'));
      });

      test('should return unchanged if shorter than maxLength', () {
        expect('Hi'.truncate(5), equals('Hi'));
      });

      test('should return unchanged if equal to maxLength', () {
        expect('Hello'.truncate(5), equals('Hello'));
      });

      test('should use custom ellipsis', () {
        expect('Hello World'.truncate(5, ellipsis: '...'), equals('Hello...'));
      });

      test('should handle empty string', () {
        expect(''.truncate(5), equals(''));
      });

      test('should handle maxLength of 0', () {
        expect('Hello'.truncate(0), equals('…'));
      });

      test('should handle maxLength of 1', () {
        expect('Hello'.truncate(1), equals('H…'));
      });
    });

    // ── initials() ──────────────────────────────────────────────────────

    group('initials()', () {
      test('should return first 2 initials by default', () {
        expect('John Doe'.initials(), equals('JD'));
      });

      test('should return single initial for single word', () {
        expect('John'.initials(), equals('J'));
      });

      test('should return empty string for empty input', () {
        expect(''.initials(), equals(''));
      });

      test('should uppercase initials', () {
        expect('john doe'.initials(), equals('JD'));
      });

      test('should respect count parameter', () {
        expect('Alice Bob Charlie'.initials(count: 3), equals('ABC'));
      });

      test('should limit to count even with more words', () {
        expect('Alice Bob Charlie'.initials(count: 2), equals('AB'));
      });

      test('should handle extra whitespace', () {
        expect('  John   Doe  '.initials(), equals('JD'));
      });

      test('should handle single character name', () {
        expect('A'.initials(), equals('A'));
      });
    });

    // ── formatAsIndianPhone() ───────────────────────────────────────────

    group('formatAsIndianPhone()', () {
      test('should format 10-digit number with +91 prefix', () {
        expect('9876543210'.formatAsIndianPhone(), equals('+91 98765 43210'));
      });

      test('should format 12-digit number with 91 prefix', () {
        expect('919876543210'.formatAsIndianPhone(), equals('+91 98765 43210'));
      });

      test('should format +91 prefixed number', () {
        expect(
          '+919876543210'.formatAsIndianPhone(),
          equals('+91 98765 43210'),
        );
      });

      test('should return unchanged for non-10-digit string', () {
        expect('12345'.formatAsIndianPhone(), equals('12345'));
      });

      test('should return unchanged for empty string', () {
        expect(''.formatAsIndianPhone(), equals(''));
      });

      test('should handle number with spaces', () {
        expect('98765 43210'.formatAsIndianPhone(), equals('+91 98765 43210'));
      });
    });

    // ── digitsOnly() ────────────────────────────────────────────────────

    group('digitsOnly()', () {
      test('should extract digits from phone with symbols', () {
        expect('+91 98765 43210'.digitsOnly(), equals('919876543210'));
      });

      test('should return same string if already all digits', () {
        expect('12345'.digitsOnly(), equals('12345'));
      });

      test('should return empty string for no digits', () {
        expect('abc'.digitsOnly(), equals(''));
      });

      test('should handle mixed content', () {
        expect('a1b2c3'.digitsOnly(), equals('123'));
      });

      test('should handle empty string', () {
        expect(''.digitsOnly(), equals(''));
      });
    });

    // ── isValidEmail ────────────────────────────────────────────────────

    group('isValidEmail', () {
      test('should return true for valid email', () {
        expect('john@example.com'.isValidEmail, isTrue);
      });

      test('should return true for email with dots in local', () {
        expect('john.doe@example.com'.isValidEmail, isTrue);
      });

      test('should return true for email with plus tag', () {
        expect('john+tag@example.com'.isValidEmail, isTrue);
      });

      test('should return false for email without @', () {
        expect('johnexample.com'.isValidEmail, isFalse);
      });

      test('should return false for email without domain', () {
        expect('john@'.isValidEmail, isFalse);
      });

      test('should return false for email without TLD', () {
        expect('john@example'.isValidEmail, isFalse);
      });

      test('should return false for empty string', () {
        expect(''.isValidEmail, isFalse);
      });
    });

    // ── isBlank ─────────────────────────────────────────────────────────

    group('isBlank', () {
      test('should return true for empty string', () {
        expect(''.isBlank, isTrue);
      });

      test('should return true for whitespace-only', () {
        expect('   '.isBlank, isTrue);
      });

      test('should return true for tab and newline', () {
        expect('\t\n'.isBlank, isTrue);
      });

      test('should return false for non-blank string', () {
        expect('hello'.isBlank, isFalse);
      });

      test('should return false for string with leading space and text', () {
        expect(' hello'.isBlank, isFalse);
      });
    });

    // ── isNotBlank ──────────────────────────────────────────────────────

    group('isNotBlank', () {
      test('should return true for non-blank string', () {
        expect('hello'.isNotBlank, isTrue);
      });

      test('should return false for empty string', () {
        expect(''.isNotBlank, isFalse);
      });

      test('should return false for whitespace-only', () {
        expect('   '.isNotBlank, isFalse);
      });
    });

    // ── nullIfBlank ─────────────────────────────────────────────────────

    group('nullIfBlank', () {
      test('should return null for empty string', () {
        expect(''.nullIfBlank, isNull);
      });

      test('should return null for whitespace-only', () {
        expect('   '.nullIfBlank, isNull);
      });

      test('should return original string for non-blank', () {
        expect('hello'.nullIfBlank, equals('hello'));
      });

      test('should return original string with whitespace if non-blank', () {
        expect(' hello '.nullIfBlank, equals(' hello '));
      });
    });
  });
}
