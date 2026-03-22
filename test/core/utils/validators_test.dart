import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/utils/validators.dart';

void main() {
  group('Validators', () {
    // ── phone ───────────────────────────────────────────────────────────

    group('phone', () {
      test('should accept valid 10-digit Indian number starting with 9', () {
        expect(Validators.phone('9876543210'), isNull);
      });

      test('should accept valid 10-digit Indian number starting with 8', () {
        expect(Validators.phone('8876543210'), isNull);
      });

      test('should accept valid 10-digit Indian number starting with 7', () {
        expect(Validators.phone('7876543210'), isNull);
      });

      test('should accept valid 10-digit Indian number starting with 6', () {
        expect(Validators.phone('6876543210'), isNull);
      });

      test('should accept +91 prefixed number', () {
        expect(Validators.phone('+919876543210'), isNull);
      });

      test('should accept 91 prefixed number without +', () {
        expect(Validators.phone('919876543210'), isNull);
      });

      test('should reject number starting with 5', () {
        expect(Validators.phone('5876543210'), isNotNull);
      });

      test('should reject number starting with 0', () {
        expect(Validators.phone('0876543210'), isNotNull);
      });

      test('should reject too short number', () {
        expect(Validators.phone('98765'), isNotNull);
      });

      test('should reject too long number', () {
        expect(Validators.phone('98765432100'), isNotNull);
      });

      test('should reject letters in number', () {
        expect(Validators.phone('98765abcde'), isNotNull);
      });

      test('should reject null', () {
        expect(Validators.phone(null), equals('Phone number is required'));
      });

      test('should reject empty string', () {
        expect(Validators.phone(''), equals('Phone number is required'));
      });

      test('should reject whitespace-only', () {
        expect(Validators.phone('   '), equals('Phone number is required'));
      });
    });

    // ── email ───────────────────────────────────────────────────────────

    group('email', () {
      test('should accept valid email', () {
        expect(Validators.email('john@example.com'), isNull);
      });

      test('should accept email with dots', () {
        expect(Validators.email('john.doe@example.com'), isNull);
      });

      test('should accept email with plus', () {
        expect(Validators.email('john+tag@example.com'), isNull);
      });

      test('should accept email with subdomain', () {
        expect(Validators.email('user@mail.example.co.in'), isNull);
      });

      test('should reject email without @', () {
        expect(Validators.email('johnexample.com'), isNotNull);
      });

      test('should reject email without domain', () {
        expect(Validators.email('john@'), isNotNull);
      });

      test('should reject email without TLD', () {
        expect(Validators.email('john@example'), isNotNull);
      });

      test('should reject email with single char TLD', () {
        expect(Validators.email('john@example.c'), isNotNull);
      });

      test('should reject email with spaces', () {
        expect(Validators.email('john @example.com'), isNotNull);
      });

      test('should reject null', () {
        expect(Validators.email(null), equals('Email is required'));
      });

      test('should reject empty string', () {
        expect(Validators.email(''), equals('Email is required'));
      });
    });

    // ── required ────────────────────────────────────────────────────────

    group('required', () {
      test('should accept non-empty string', () {
        expect(Validators.required('hello'), isNull);
      });

      test('should reject null', () {
        expect(Validators.required(null), equals('This field is required'));
      });

      test('should reject empty string', () {
        expect(Validators.required(''), equals('This field is required'));
      });

      test('should reject whitespace-only', () {
        expect(Validators.required('   '), equals('This field is required'));
      });

      test('should use custom fieldName in error', () {
        expect(
          Validators.required(null, fieldName: 'Description'),
          equals('Description is required'),
        );
      });
    });

    // ── groupName ───────────────────────────────────────────────────────

    group('groupName', () {
      test('should accept valid group name', () {
        expect(Validators.groupName('Weekend Trip'), isNull);
      });

      test('should accept single character name', () {
        expect(Validators.groupName('A'), isNull);
      });

      test('should accept name at max length (50 chars)', () {
        final name = 'A' * 50;
        expect(Validators.groupName(name), isNull);
      });

      test('should reject name exceeding max length', () {
        final name = 'A' * 51;
        expect(Validators.groupName(name), isNotNull);
        expect(
          Validators.groupName(name),
          contains('50 characters or fewer'),
        );
      });

      test('should reject null', () {
        expect(
          Validators.groupName(null),
          equals('Group name is required'),
        );
      });

      test('should reject empty string', () {
        expect(Validators.groupName(''), equals('Group name is required'));
      });

      test('should reject whitespace-only', () {
        expect(
          Validators.groupName('   '),
          equals('Group name is required'),
        );
      });
    });

    // ── expenseDescription ──────────────────────────────────────────────

    group('expenseDescription', () {
      test('should accept valid description', () {
        expect(Validators.expenseDescription('Lunch'), isNull);
      });

      test('should accept description at max length (100 chars)', () {
        final desc = 'A' * 100;
        expect(Validators.expenseDescription(desc), isNull);
      });

      test('should reject description exceeding max length', () {
        final desc = 'A' * 101;
        expect(Validators.expenseDescription(desc), isNotNull);
        expect(
          Validators.expenseDescription(desc),
          contains('100 characters or fewer'),
        );
      });

      test('should reject null', () {
        expect(
          Validators.expenseDescription(null),
          equals('Description is required'),
        );
      });

      test('should reject empty string', () {
        expect(
          Validators.expenseDescription(''),
          equals('Description is required'),
        );
      });
    });

    // ── notes ───────────────────────────────────────────────────────────

    group('notes', () {
      test('should accept null (notes are optional)', () {
        expect(Validators.notes(null), isNull);
      });

      test('should accept empty string (notes are optional)', () {
        expect(Validators.notes(''), isNull);
      });

      test('should accept whitespace-only (notes are optional)', () {
        expect(Validators.notes('   '), isNull);
      });

      test('should accept valid notes', () {
        expect(Validators.notes('Dinner at restaurant'), isNull);
      });

      test('should accept notes at max length (500 chars)', () {
        final notes = 'A' * 500;
        expect(Validators.notes(notes), isNull);
      });

      test('should reject notes exceeding max length', () {
        final notes = 'A' * 501;
        expect(Validators.notes(notes), isNotNull);
        expect(Validators.notes(notes), contains('500 characters or fewer'));
      });
    });

    // ── amount ──────────────────────────────────────────────────────────

    group('amount', () {
      test('should accept valid positive amount "100.50"', () {
        expect(Validators.amount('100.50'), isNull);
      });

      test('should accept whole number "500"', () {
        expect(Validators.amount('500'), isNull);
      });

      test('should accept "0.01"', () {
        expect(Validators.amount('0.01'), isNull);
      });

      test('should accept amount with comma "1,000"', () {
        expect(Validators.amount('1,000'), isNull);
      });

      test('should accept amount with ₹ symbol', () {
        expect(Validators.amount('₹500'), isNull);
      });

      test('should reject "0" (must be greater than zero)', () {
        expect(Validators.amount('0'), isNotNull);
        expect(
          Validators.amount('0'),
          equals('Amount must be greater than zero'),
        );
      });

      test('should reject negative amount', () {
        expect(Validators.amount('-100'), isNotNull);
        expect(
          Validators.amount('-100'),
          equals('Amount must be greater than zero'),
        );
      });

      test('should reject non-numeric input', () {
        expect(Validators.amount('abc'), isNotNull);
        expect(Validators.amount('abc'), equals('Enter a valid amount'));
      });

      test('should reject more than 2 decimal places', () {
        expect(Validators.amount('100.505'), isNotNull);
        expect(
          Validators.amount('100.505'),
          equals('Amount can have at most 2 decimal places'),
        );
      });

      test('should accept exactly 2 decimal places', () {
        expect(Validators.amount('100.50'), isNull);
      });

      test('should accept exactly 1 decimal place', () {
        expect(Validators.amount('100.5'), isNull);
      });

      test('should reject null', () {
        expect(Validators.amount(null), equals('Amount is required'));
      });

      test('should reject empty string', () {
        expect(Validators.amount(''), equals('Amount is required'));
      });
    });

    // ── otp ─────────────────────────────────────────────────────────────

    group('otp', () {
      test('should accept valid 6-digit OTP', () {
        expect(Validators.otp('123456'), isNull);
      });

      test('should accept 6-digit OTP starting with 0', () {
        expect(Validators.otp('012345'), isNull);
      });

      test('should reject 5-digit OTP', () {
        expect(Validators.otp('12345'), isNotNull);
        expect(Validators.otp('12345'), contains('6 digits'));
      });

      test('should reject 7-digit OTP', () {
        expect(Validators.otp('1234567'), isNotNull);
        expect(Validators.otp('1234567'), contains('6 digits'));
      });

      test('should reject OTP with letters', () {
        expect(Validators.otp('12ab56'), isNotNull);
        expect(Validators.otp('12ab56'), contains('6 digits'));
      });

      test('should reject null', () {
        expect(Validators.otp(null), equals('OTP is required'));
      });

      test('should reject empty string', () {
        expect(Validators.otp(''), equals('OTP is required'));
      });
    });

    // ── displayName ─────────────────────────────────────────────────────

    group('displayName', () {
      test('should accept valid name', () {
        expect(Validators.displayName('Avtansh'), isNull);
      });

      test('should accept name at max length (50 chars)', () {
        final name = 'A' * 50;
        expect(Validators.displayName(name), isNull);
      });

      test('should reject name exceeding 50 characters', () {
        final name = 'A' * 51;
        expect(Validators.displayName(name), isNotNull);
        expect(
          Validators.displayName(name),
          contains('50 characters or fewer'),
        );
      });

      test('should reject null', () {
        expect(Validators.displayName(null), equals('Name is required'));
      });

      test('should reject empty string', () {
        expect(Validators.displayName(''), equals('Name is required'));
      });
    });

    // ── percentage ──────────────────────────────────────────────────────

    group('percentage', () {
      test('should accept 0', () {
        expect(Validators.percentage('0'), isNull);
      });

      test('should accept 100', () {
        expect(Validators.percentage('100'), isNull);
      });

      test('should accept 50.5', () {
        expect(Validators.percentage('50.5'), isNull);
      });

      test('should reject negative', () {
        expect(Validators.percentage('-1'), isNotNull);
        expect(
          Validators.percentage('-1'),
          contains('between 0 and 100'),
        );
      });

      test('should reject above 100', () {
        expect(Validators.percentage('101'), isNotNull);
        expect(
          Validators.percentage('101'),
          contains('between 0 and 100'),
        );
      });

      test('should reject non-numeric', () {
        expect(Validators.percentage('abc'), isNotNull);
        expect(Validators.percentage('abc'), contains('valid number'));
      });

      test('should reject null', () {
        expect(
          Validators.percentage(null),
          equals('Percentage is required'),
        );
      });

      test('should reject empty string', () {
        expect(Validators.percentage(''), equals('Percentage is required'));
      });
    });

    // ── shares ──────────────────────────────────────────────────────────

    group('shares', () {
      test('should accept positive integer "3"', () {
        expect(Validators.shares('3'), isNull);
      });

      test('should accept "1"', () {
        expect(Validators.shares('1'), isNull);
      });

      test('should reject "0"', () {
        expect(Validators.shares('0'), isNotNull);
        expect(
          Validators.shares('0'),
          contains('greater than zero'),
        );
      });

      test('should reject negative integer', () {
        expect(Validators.shares('-1'), isNotNull);
        expect(
          Validators.shares('-1'),
          contains('greater than zero'),
        );
      });

      test('should reject non-integer "3.5"', () {
        expect(Validators.shares('3.5'), isNotNull);
        expect(Validators.shares('3.5'), contains('whole number'));
      });

      test('should reject non-numeric', () {
        expect(Validators.shares('abc'), isNotNull);
        expect(Validators.shares('abc'), contains('whole number'));
      });

      test('should reject null', () {
        expect(
          Validators.shares(null),
          equals('Shares value is required'),
        );
      });

      test('should reject empty string', () {
        expect(
          Validators.shares(''),
          equals('Shares value is required'),
        );
      });
    });
  });
}
