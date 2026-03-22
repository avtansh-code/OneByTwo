import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';

void main() {
  group('Result', () {
    // ── Factory constructors ────────────────────────────────────────────

    group('Result.success()', () {
      test('should create a Success<T> with correct data', () {
        // Arrange & Act
        final result = Result<int>.success(42);

        // Assert
        expect(result, isA<Success<int>>());
        expect((result as Success<int>).data, equals(42));
      });

      test('should work with String type', () {
        final result = Result<String>.success('hello');

        expect(result, isA<Success<String>>());
        expect((result as Success<String>).data, equals('hello'));
      });

      test('should work with nullable type holding null', () {
        final result = Result<String?>.success(null);

        expect(result, isA<Success<String?>>());
        expect((result as Success<String?>).data, isNull);
      });

      test('should work with complex types', () {
        final data = {'user-1': 25000, 'user-2': 25000};
        final result = Result<Map<String, int>>.success(data);

        expect(result, isA<Success<Map<String, int>>>());
        expect((result as Success<Map<String, int>>).data, equals(data));
      });
    });

    group('Result.failure()', () {
      test('should create a Failure<T> with correct exception', () {
        // Arrange
        const exception = NetworkException('No internet');

        // Act
        final result = Result<int>.failure(exception);

        // Assert
        expect(result, isA<Failure<int>>());
        expect((result as Failure<int>).exception, equals(exception));
      });

      test('should preserve exception details', () {
        const exception = AuthException('Token expired', code: 'token-expired');
        final result = Result<String>.failure(exception);

        final failure = result as Failure<String>;
        expect(failure.exception.message, equals('Token expired'));
        expect(failure.exception.code, equals('token-expired'));
      });
    });

    // ── isSuccess / isFailure getters ───────────────────────────────────

    group('isSuccess', () {
      test('should return true for Success', () {
        final result = Result<int>.success(42);
        expect(result.isSuccess, isTrue);
      });

      test('should return false for Failure', () {
        final result = Result<int>.failure(const NetworkException('error'));
        expect(result.isSuccess, isFalse);
      });
    });

    group('isFailure', () {
      test('should return true for Failure', () {
        final result = Result<int>.failure(const NetworkException('error'));
        expect(result.isFailure, isTrue);
      });

      test('should return false for Success', () {
        final result = Result<int>.success(42);
        expect(result.isFailure, isFalse);
      });
    });

    // ── dataOrNull ──────────────────────────────────────────────────────

    group('dataOrNull', () {
      test('should return data for Success', () {
        final result = Result<String>.success('hello');
        expect(result.dataOrNull, equals('hello'));
      });

      test('should return null for Failure', () {
        final result = Result<String>.failure(
          const NotFoundException('not found'),
        );
        expect(result.dataOrNull, isNull);
      });

      test('should return null for Success wrapping nullable null', () {
        final result = Result<String?>.success(null);
        expect(result.dataOrNull, isNull);
      });
    });

    // ── when() ──────────────────────────────────────────────────────────

    group('when()', () {
      test('should call success branch for Success', () {
        // Arrange
        final result = Result<int>.success(42);

        // Act
        final output = result.when(
          success: (data) => 'got $data',
          failure: (e) => 'error: ${e.message}',
        );

        // Assert
        expect(output, equals('got 42'));
      });

      test('should call failure branch for Failure', () {
        // Arrange
        final result = Result<int>.failure(
          const ValidationException('bad input'),
        );

        // Act
        final output = result.when(
          success: (data) => 'got $data',
          failure: (e) => 'error: ${e.message}',
        );

        // Assert
        expect(output, equals('error: bad input'));
      });

      test('should return value of matching branch', () {
        final result = Result<int>.success(10);

        final doubled = result.when(
          success: (data) => data * 2,
          failure: (e) => -1,
        );

        expect(doubled, equals(20));
      });
    });

    // ── map() ───────────────────────────────────────────────────────────

    group('map()', () {
      test('should transform data for Success', () {
        // Arrange
        final result = Result<int>.success(42);

        // Act
        final mapped = result.map((data) => data.toString());

        // Assert
        expect(mapped, isA<Success<String>>());
        expect((mapped as Success<String>).data, equals('42'));
      });

      test('should pass through Failure unchanged', () {
        // Arrange
        const exception = NetworkException('offline');
        final result = Result<int>.failure(exception);

        // Act
        final mapped = result.map((data) => data.toString());

        // Assert
        expect(mapped, isA<Failure<String>>());
        expect((mapped as Failure<String>).exception, equals(exception));
      });

      test('should chain multiple map calls', () {
        final result = Result<int>.success(5);

        final chained = result
            .map((data) => data * 2)
            .map((data) => 'value: $data');

        expect(chained, isA<Success<String>>());
        expect((chained as Success<String>).data, equals('value: 10'));
      });
    });

    // ── flatMap() ───────────────────────────────────────────────────────

    group('flatMap()', () {
      test('should chain Success → Success', () {
        // Arrange
        final result = Result<int>.success(42);

        // Act
        final chained = result.flatMap(
          (data) => Result<String>.success('value: $data'),
        );

        // Assert
        expect(chained, isA<Success<String>>());
        expect((chained as Success<String>).data, equals('value: 42'));
      });

      test('should chain Success → Failure', () {
        // Arrange
        final result = Result<int>.success(-1);

        // Act
        final chained = result.flatMap((data) {
          if (data < 0) {
            return Result<String>.failure(
              const ValidationException('negative'),
            );
          }
          return Result<String>.success('ok');
        });

        // Assert
        expect(chained, isA<Failure<String>>());
        expect(
          (chained as Failure<String>).exception,
          isA<ValidationException>(),
        );
      });

      test('should propagate Failure without calling transform', () {
        // Arrange
        const exception = NetworkException('offline');
        final result = Result<int>.failure(exception);
        var wasCalled = false;

        // Act
        final chained = result.flatMap((data) {
          wasCalled = true;
          return Result<String>.success('should not reach');
        });

        // Assert
        expect(chained, isA<Failure<String>>());
        expect((chained as Failure<String>).exception, equals(exception));
        expect(wasCalled, isFalse);
      });
    });

    // ── Equality ────────────────────────────────────────────────────────

    group('Equality', () {
      test('two Success with same data should be equal', () {
        final a = Result<int>.success(42);
        final b = Result<int>.success(42);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two Success with different data should not be equal', () {
        final a = Result<int>.success(42);
        final b = Result<int>.success(99);

        expect(a, isNot(equals(b)));
      });

      test('two Failure with same exception should be equal', () {
        const exception = NetworkException('offline');
        final a = Result<int>.failure(exception);
        final b = Result<int>.failure(exception);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('Success and Failure should never be equal', () {
        final success = Result<int>.success(42);
        final failure = Result<int>.failure(const NetworkException('error'));

        expect(success, isNot(equals(failure)));
      });

      test('identical Success should be equal', () {
        final result = Result<int>.success(42);
        expect(result, equals(result));
      });

      test('identical Failure should be equal', () {
        final result = Result<int>.failure(const NetworkException('error'));
        expect(result, equals(result));
      });
    });

    // ── toString() ──────────────────────────────────────────────────────

    group('toString()', () {
      test('Success toString includes data', () {
        final result = Result<int>.success(42);
        expect(result.toString(), equals('Success(42)'));
      });

      test('Failure toString includes exception', () {
        const exception = NetworkException('offline', code: 'no-network');
        final result = Result<int>.failure(exception);
        expect(
          result.toString(),
          equals(
            'Failure(NetworkException(message: offline, code: no-network))',
          ),
        );
      });
    });
  });
}
