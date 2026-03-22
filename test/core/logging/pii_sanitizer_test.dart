import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/logging/pii_sanitizer.dart';

void main() {
  group('PiiSanitizer', () {
    // ── Phone number masking ────────────────────────────────────────────

    group('sanitize – phone numbers', () {
      test(
        'should mask 10-digit Indian phone number showing last 2 digits',
        () {
          final result = PiiSanitizer.sanitize('Call me at 9876543210');
          expect(result, contains('XXXXXXXX10'));
          expect(result, isNot(contains('98765432')));
        },
      );

      test('should mask +91 prefixed phone number', () {
        final result = PiiSanitizer.sanitize('Phone: +919876543210');
        expect(result, contains('+91XXXXXXXX10'));
        expect(result, isNot(contains('98765432')));
      });

      test('should mask 91 prefixed phone number (no +)', () {
        final result = PiiSanitizer.sanitize('Phone: 919876543210');
        expect(result, contains('+91XXXXXXXX10'));
      });

      test('should mask phone with spaces after +91', () {
        final result = PiiSanitizer.sanitize('Phone: +91 9876543210');
        expect(result, contains('+91XXXXXXXX10'));
      });

      test('should mask multiple phone numbers in the same string', () {
        final result = PiiSanitizer.sanitize(
          'Users: 9876543210 and 8765432109',
        );
        expect(result, contains('XXXXXXXX10'));
        expect(result, contains('XXXXXXXX09'));
      });

      test('should preserve surrounding text', () {
        final result = PiiSanitizer.sanitize('User phone is 9876543210 ok');
        expect(result, startsWith('User phone is '));
        expect(result, endsWith(' ok'));
      });

      test('should not mask numbers that do not start with 6-9', () {
        // Starts with 5, so the regex won't match the 10-digit pattern
        final result = PiiSanitizer.sanitize('Number: 5876543210');
        expect(result, contains('5876543210'));
      });
    });

    // ── Email masking ───────────────────────────────────────────────────

    group('sanitize – emails', () {
      test('should mask email showing first char and domain', () {
        final result = PiiSanitizer.sanitize('Email: john@example.com');
        expect(result, contains('j***@example.com'));
        expect(result, isNot(contains('john@')));
      });

      test('should mask email with dots in local part', () {
        final result = PiiSanitizer.sanitize('Email: john.doe@example.com');
        expect(result, contains('j***@example.com'));
      });

      test('should mask email with subdomain', () {
        final result = PiiSanitizer.sanitize('user@mail.example.co.in');
        expect(result, contains('u***@mail.example.co.in'));
      });

      test('should mask multiple emails in the same string', () {
        final result = PiiSanitizer.sanitize('alice@a.com and bob@b.com');
        expect(result, contains('a***@a.com'));
        expect(result, contains('b***@b.com'));
      });
    });

    // ── Mixed PII ───────────────────────────────────────────────────────

    group('sanitize – mixed PII', () {
      test('should mask both phone and email in same string', () {
        final result = PiiSanitizer.sanitize(
          'Contact: john@example.com or 9876543210',
        );
        expect(result, contains('j***@example.com'));
        expect(result, contains('XXXXXXXX10'));
        expect(result, isNot(contains('john@')));
        expect(result, isNot(contains('98765432')));
      });

      test('should return unchanged string with no PII', () {
        const input = 'Total expense: 500 rupees for groceries';
        expect(PiiSanitizer.sanitize(input), equals(input));
      });

      test('should handle empty string', () {
        expect(PiiSanitizer.sanitize(''), equals(''));
      });
    });

    // ── sanitizeMap ─────────────────────────────────────────────────────

    group('sanitizeMap', () {
      test('should sanitize string values in map', () {
        final data = <String, dynamic>{
          'email': 'john@example.com',
          'phone': '9876543210',
        };

        final result = PiiSanitizer.sanitizeMap(data);

        expect(result['email'], contains('j***@example.com'));
        expect(result['phone'], contains('XXXXXXXX10'));
      });

      test('should mask sensitive keys when value is long (>10 chars)', () {
        final data = <String, dynamic>{
          'token': 'abcdefghijklmnop', // 16 chars > 10
        };

        final result = PiiSanitizer.sanitizeMap(data);

        expect(result['token'], equals('abcd***'));
      });

      test(
        'should not mask sensitive keys when value is short (<=10 chars)',
        () {
          final data = <String, dynamic>{
            'token': 'short', // 5 chars <= 10
          };

          final result = PiiSanitizer.sanitizeMap(data);

          // Short sensitive values are passed through sanitize() instead
          expect(result['token'], equals('short'));
        },
      );

      test('should mask all sensitive key names', () {
        final sensitiveKeys = [
          'token',
          'accessToken',
          'refreshToken',
          'idToken',
          'apiKey',
          'secret',
          'password',
          'authorization',
        ];

        for (final key in sensitiveKeys) {
          final data = <String, dynamic>{key: 'a_very_long_secret_value'};
          final result = PiiSanitizer.sanitizeMap(data);
          expect(
            result[key],
            equals('a_ve***'),
            reason: 'Key "$key" should be masked',
          );
        }
      });

      test('should recursively sanitize nested maps', () {
        final data = <String, dynamic>{
          'user': <String, dynamic>{
            'email': 'john@example.com',
            'token': 'super_secret_token_12345',
          },
        };

        final result = PiiSanitizer.sanitizeMap(data);
        final nested = result['user'] as Map<String, dynamic>;

        expect(nested['email'], contains('j***@example.com'));
        expect(nested['token'], equals('supe***'));
      });

      test('should recursively sanitize lists', () {
        final data = <String, dynamic>{
          'emails': ['alice@a.com', 'bob@b.com'],
        };

        final result = PiiSanitizer.sanitizeMap(data);
        final emails = result['emails'] as List;

        expect(emails[0], contains('a***@a.com'));
        expect(emails[1], contains('b***@b.com'));
      });

      test('should handle lists containing maps', () {
        final data = <String, dynamic>{
          'users': [
            <String, dynamic>{'email': 'alice@a.com'},
            <String, dynamic>{'email': 'bob@b.com'},
          ],
        };

        final result = PiiSanitizer.sanitizeMap(data);
        final users = result['users'] as List;

        expect(
          (users[0] as Map<String, dynamic>)['email'],
          contains('a***@a.com'),
        );
        expect(
          (users[1] as Map<String, dynamic>)['email'],
          contains('b***@b.com'),
        );
      });

      test('should pass through non-string, non-map, non-list values', () {
        final data = <String, dynamic>{
          'count': 42,
          'active': true,
          'amount': 100.50,
          'nothing': null,
        };

        final result = PiiSanitizer.sanitizeMap(data);

        expect(result['count'], equals(42));
        expect(result['active'], equals(true));
        expect(result['amount'], equals(100.50));
        expect(result['nothing'], isNull);
      });

      test('should handle nested lists within lists', () {
        final data = <String, dynamic>{
          'nested': [
            ['alice@a.com', 'not-pii'],
            [42, true],
          ],
        };

        final result = PiiSanitizer.sanitizeMap(data);
        final nested = result['nested'] as List;
        final innerList1 = nested[0] as List;
        final innerList2 = nested[1] as List;

        expect(innerList1[0], contains('a***@a.com'));
        expect(innerList1[1], equals('not-pii'));
        expect(innerList2[0], equals(42));
        expect(innerList2[1], equals(true));
      });

      test('should handle empty map', () {
        final result = PiiSanitizer.sanitizeMap(<String, dynamic>{});
        expect(result, isEmpty);
      });
    });
  });
}
