import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/domain/repositories/auth_repository.dart';
import 'package:one_by_two/domain/usecases/auth/send_otp_use_case.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late SendOtpUseCase useCase;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = SendOtpUseCase(mockAuthRepository);
  });

  group('SendOtpUseCase', () {
    // ── Happy path ──────────────────────────────────────────────────────

    group('happy path', () {
      test('should delegate to repository when phone is valid', () async {
        // Arrange
        when(
          () => mockAuthRepository.sendOtp(any()),
        ).thenAnswer((_) async => Result.success('verification-id-123'));

        // Act
        final result = await useCase.call('+919876543210');

        // Assert
        expect(result.isSuccess, isTrue);
        expect((result as Success<String>).data, equals('verification-id-123'));
        verify(() => mockAuthRepository.sendOtp('+919876543210')).called(1);
      });

      test('should accept phone starting with +916', () async {
        // Arrange
        when(
          () => mockAuthRepository.sendOtp(any()),
        ).thenAnswer((_) async => Result.success('vid'));

        // Act
        final result = await useCase.call('+916000000000');

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockAuthRepository.sendOtp('+916000000000')).called(1);
      });

      test('should accept phone starting with +917', () async {
        // Arrange
        when(
          () => mockAuthRepository.sendOtp(any()),
        ).thenAnswer((_) async => Result.success('vid'));

        // Act
        final result = await useCase.call('+917000000000');

        // Assert
        expect(result.isSuccess, isTrue);
      });

      test('should accept phone starting with +918', () async {
        // Arrange
        when(
          () => mockAuthRepository.sendOtp(any()),
        ).thenAnswer((_) async => Result.success('vid'));

        // Act
        final result = await useCase.call('+918000000000');

        // Assert
        expect(result.isSuccess, isTrue);
      });

      test('should accept phone starting with +919', () async {
        // Arrange
        when(
          () => mockAuthRepository.sendOtp(any()),
        ).thenAnswer((_) async => Result.success('vid'));

        // Act
        final result = await useCase.call('+919999999999');

        // Assert
        expect(result.isSuccess, isTrue);
      });
    });

    // ── Validation failures ─────────────────────────────────────────────

    group('validation', () {
      test('should return ValidationException when phone is empty', () async {
        // Act
        final result = await useCase.call('');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<String>;
        expect(failure.exception, isA<ValidationException>());
        expect(failure.exception.code, equals('invalid-phone-number'));
        verifyNever(() => mockAuthRepository.sendOtp(any()));
      });

      test(
        'should return ValidationException when phone has no +91 prefix',
        () async {
          // Act
          final result = await useCase.call('9876543210');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
          verifyNever(() => mockAuthRepository.sendOtp(any()));
        },
      );

      test(
        'should return ValidationException when phone starts with +915',
        () async {
          // Act — digits starting with 5 are invalid Indian mobile numbers
          final result = await useCase.call('+915876543210');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
          verifyNever(() => mockAuthRepository.sendOtp(any()));
        },
      );

      test(
        'should return ValidationException when phone starts with +910',
        () async {
          // Act
          final result = await useCase.call('+910876543210');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );

      test(
        'should return ValidationException when phone is too short',
        () async {
          // Act
          final result = await useCase.call('+91987654');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );

      test(
        'should return ValidationException when phone is too long',
        () async {
          // Act
          final result = await useCase.call('+9198765432100');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );

      test(
        'should return ValidationException when phone contains letters',
        () async {
          // Act
          final result = await useCase.call('+91987abc3210');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );

      test(
        'should return ValidationException with correct message for invalid phone',
        () async {
          // Act
          final result = await useCase.call('invalid');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<String>;
          expect(
            failure.exception.message,
            equals('Invalid phone number. Expected format: +91XXXXXXXXXX'),
          );
        },
      );

      test(
        'should return ValidationException for non-Indian country code',
        () async {
          // Act — US number
          final result = await useCase.call('+12025551234');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );
    });

    // ── Repository error propagation ────────────────────────────────────

    group('repository error propagation', () {
      test('should propagate AuthException from repository', () async {
        // Arrange
        when(() => mockAuthRepository.sendOtp(any())).thenAnswer(
          (_) async => Result.failure(
            const AuthException('Rate limited', code: 'too-many-requests'),
          ),
        );

        // Act
        final result = await useCase.call('+919876543210');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<String>;
        expect(failure.exception, isA<AuthException>());
        expect(failure.exception.code, equals('too-many-requests'));
      });

      test('should propagate NetworkException from repository', () async {
        // Arrange
        when(() => mockAuthRepository.sendOtp(any())).thenAnswer(
          (_) async => Result.failure(const NetworkException('No internet')),
        );

        // Act
        final result = await useCase.call('+919876543210');

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<NetworkException>());
      });
    });
  });
}
