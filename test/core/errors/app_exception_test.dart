import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/errors/app_exception.dart';

void main() {
  group('AppException hierarchy', () {
    // ── Shared behaviour tests ──────────────────────────────────────────

    group('common properties', () {
      test('should store message', () {
        const e = NetworkException('No internet');
        expect(e.message, equals('No internet'));
      });

      test('should store optional code', () {
        const e = AuthException('Expired', code: 'token-expired');
        expect(e.code, equals('token-expired'));
      });

      test('should default code to null', () {
        const e = NetworkException('offline');
        expect(e.code, isNull);
      });

      test('should store optional stackTrace', () {
        final trace = StackTrace.current;
        final e = FirestoreException('fail', stackTrace: trace);
        expect(e.stackTrace, equals(trace));
      });

      test('should default stackTrace to null', () {
        const e = NetworkException('offline');
        expect(e.stackTrace, isNull);
      });
    });

    // ── toString() ──────────────────────────────────────────────────────

    group('toString()', () {
      test('should include class name and message', () {
        const e = NetworkException('No internet');
        expect(
          e.toString(),
          equals('NetworkException(message: No internet, code: null)'),
        );
      });

      test('should include code when provided', () {
        const e = AuthException('Expired', code: 'token-expired');
        expect(
          e.toString(),
          equals('AuthException(message: Expired, code: token-expired)'),
        );
      });
    });

    // ── NetworkException ────────────────────────────────────────────────

    group('NetworkException', () {
      test('should be an AppException', () {
        const e = NetworkException('No internet');
        expect(e, isA<AppException>());
      });

      test('should implement Exception', () {
        const e = NetworkException('No internet');
        expect(e, isA<Exception>());
      });

      test('should store all properties', () {
        final trace = StackTrace.current;
        final e = NetworkException(
          'timeout',
          code: 'request-timeout',
          stackTrace: trace,
        );
        expect(e.message, equals('timeout'));
        expect(e.code, equals('request-timeout'));
        expect(e.stackTrace, equals(trace));
      });

      test('toString should contain NetworkException', () {
        const e = NetworkException('DNS failed', code: 'dns-error');
        expect(e.toString(), contains('NetworkException'));
        expect(e.toString(), contains('DNS failed'));
        expect(e.toString(), contains('dns-error'));
      });
    });

    // ── AuthException ───────────────────────────────────────────────────

    group('AuthException', () {
      test('should be an AppException', () {
        const e = AuthException('Invalid credentials');
        expect(e, isA<AppException>());
      });

      test('should store all properties', () {
        const e = AuthException('User not found', code: 'user-not-found');
        expect(e.message, equals('User not found'));
        expect(e.code, equals('user-not-found'));
      });

      test('toString should contain AuthException', () {
        const e = AuthException('Expired token');
        expect(e.toString(), contains('AuthException'));
        expect(e.toString(), contains('Expired token'));
      });
    });

    // ── FirestoreException ──────────────────────────────────────────────

    group('FirestoreException', () {
      test('should be an AppException', () {
        const e = FirestoreException('Write failed');
        expect(e, isA<AppException>());
      });

      test('should store all properties', () {
        const e = FirestoreException(
          'Permission denied',
          code: 'permission-denied',
        );
        expect(e.message, equals('Permission denied'));
        expect(e.code, equals('permission-denied'));
      });

      test('toString should contain FirestoreException', () {
        const e = FirestoreException('Unavailable', code: 'unavailable');
        expect(e.toString(), contains('FirestoreException'));
        expect(e.toString(), contains('Unavailable'));
      });
    });

    // ── ValidationException ─────────────────────────────────────────────

    group('ValidationException', () {
      test('should be an AppException', () {
        const e = ValidationException('Invalid input');
        expect(e, isA<AppException>());
      });

      test('should store all properties', () {
        const e = ValidationException(
          'Amount must be positive',
          code: 'invalid-amount',
        );
        expect(e.message, equals('Amount must be positive'));
        expect(e.code, equals('invalid-amount'));
      });

      test('toString should contain ValidationException', () {
        const e = ValidationException('Bad phone');
        expect(e.toString(), contains('ValidationException'));
        expect(e.toString(), contains('Bad phone'));
      });
    });

    // ── NotFoundException ───────────────────────────────────────────────

    group('NotFoundException', () {
      test('should be an AppException', () {
        const e = NotFoundException('Group not found');
        expect(e, isA<AppException>());
      });

      test('should store all properties', () {
        const e = NotFoundException('Document missing', code: 'not-found');
        expect(e.message, equals('Document missing'));
        expect(e.code, equals('not-found'));
      });

      test('toString should contain NotFoundException', () {
        const e = NotFoundException('User missing');
        expect(e.toString(), contains('NotFoundException'));
        expect(e.toString(), contains('User missing'));
      });
    });

    // ── PermissionException ─────────────────────────────────────────────

    group('PermissionException', () {
      test('should be an AppException', () {
        const e = PermissionException('Not allowed');
        expect(e, isA<AppException>());
      });

      test('should store all properties', () {
        const e = PermissionException('Admin only', code: 'admin-required');
        expect(e.message, equals('Admin only'));
        expect(e.code, equals('admin-required'));
      });

      test('toString should contain PermissionException', () {
        const e = PermissionException('Access denied');
        expect(e.toString(), contains('PermissionException'));
        expect(e.toString(), contains('Access denied'));
      });
    });

    // ── StorageException ────────────────────────────────────────────────

    group('StorageException', () {
      test('should be an AppException', () {
        const e = StorageException('Upload failed');
        expect(e, isA<AppException>());
      });

      test('should store all properties', () {
        const e = StorageException('Quota exceeded', code: 'quota-exceeded');
        expect(e.message, equals('Quota exceeded'));
        expect(e.code, equals('quota-exceeded'));
      });

      test('toString should contain StorageException', () {
        const e = StorageException('File too large');
        expect(e.toString(), contains('StorageException'));
        expect(e.toString(), contains('File too large'));
      });
    });

    // ── UnknownException ────────────────────────────────────────────────

    group('UnknownException', () {
      test('should be an AppException', () {
        const e = UnknownException('Something went wrong');
        expect(e, isA<AppException>());
      });

      test('should store all properties including originalError', () {
        const originalError = FormatException('bad format');
        const e = UnknownException(
          'Unexpected error',
          code: 'unknown',
          originalError: originalError,
        );
        expect(e.message, equals('Unexpected error'));
        expect(e.code, equals('unknown'));
        expect(e.originalError, equals(originalError));
      });

      test('should default originalError to null', () {
        const e = UnknownException('Something went wrong');
        expect(e.originalError, isNull);
      });

      test('toString should include originalError', () {
        const e = UnknownException('Crash', originalError: 'some error object');
        expect(e.toString(), contains('UnknownException'));
        expect(e.toString(), contains('Crash'));
        expect(e.toString(), contains('some error object'));
      });

      test('toString should include code', () {
        const e = UnknownException('Crash', code: 'fatal');
        expect(e.toString(), contains('fatal'));
      });

      test('toString uses custom format with originalError', () {
        const e = UnknownException('Oops', code: 'err-1', originalError: 42);
        expect(
          e.toString(),
          equals(
            'UnknownException(message: Oops, code: err-1, originalError: 42)',
          ),
        );
      });
    });

    // ── Pattern matching ────────────────────────────────────────────────

    group('pattern matching (sealed class)', () {
      test('should match NetworkException in switch', () {
        const AppException e = NetworkException('offline');

        final label = switch (e) {
          NetworkException() => 'network',
          AuthException() => 'auth',
          FirestoreException() => 'firestore',
          ValidationException() => 'validation',
          NotFoundException() => 'not-found',
          PermissionException() => 'permission',
          StorageException() => 'storage',
          UnknownException() => 'unknown',
        };

        expect(label, equals('network'));
      });

      test('should match all subclasses exhaustively', () {
        // This test verifies the sealed hierarchy is exhaustive.
        // If a new subclass is added and this switch doesn't cover it,
        // the compiler will produce an error.
        final exceptions = <AppException>[
          const NetworkException('a'),
          const AuthException('b'),
          const FirestoreException('c'),
          const ValidationException('d'),
          const NotFoundException('e'),
          const PermissionException('f'),
          const StorageException('g'),
          const UnknownException('h'),
        ];

        for (final e in exceptions) {
          final label = switch (e) {
            NetworkException() => 'network',
            AuthException() => 'auth',
            FirestoreException() => 'firestore',
            ValidationException() => 'validation',
            NotFoundException() => 'not-found',
            PermissionException() => 'permission',
            StorageException() => 'storage',
            UnknownException() => 'unknown',
          };
          expect(label, isNotEmpty);
        }
      });
    });
  });
}
