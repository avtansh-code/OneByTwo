import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/domain/repositories/auth_repository.dart';
import 'package:one_by_two/domain/usecases/auth/verify_otp_use_case.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late VerifyOtpUseCase useCase;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = VerifyOtpUseCase(mockAuthRepository);
  });

  group('VerifyOtpUseCase', () {
    // ── Happy path ──────────────────────────────────────────────────────

    group('happy path', () {
      test('should return uid when OTP and verificationId are valid', () async {
        // Arrange
        when(
          () => mockAuthRepository.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async => Result.success('user-uid-123'));

        // Act
        final result = await useCase.call(
          verificationId: 'vid-abc',
          otp: '123456',
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect((result as Success<String>).data, equals('user-uid-123'));
        verify(
          () => mockAuthRepository.verifyOtp(
            verificationId: 'vid-abc',
            otp: '123456',
          ),
        ).called(1);
      });

      test('should accept OTP starting with 0', () async {
        // Arrange
        when(
          () => mockAuthRepository.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async => Result.success('uid'));

        // Act
        final result = await useCase.call(verificationId: 'vid', otp: '012345');

        // Assert
        expect(result.isSuccess, isTrue);
      });

      test('should accept OTP of all zeros', () async {
        // Arrange
        when(
          () => mockAuthRepository.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async => Result.success('uid'));

        // Act
        final result = await useCase.call(verificationId: 'vid', otp: '000000');

        // Assert
        expect(result.isSuccess, isTrue);
      });
    });

    // ── OTP validation ──────────────────────────────────────────────────

    group('OTP validation', () {
      test('should return ValidationException when OTP is empty', () async {
        // Act
        final result = await useCase.call(verificationId: 'vid', otp: '');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<String>;
        expect(failure.exception, isA<ValidationException>());
        expect(failure.exception.code, equals('invalid-otp'));
        expect(
          failure.exception.message,
          equals('OTP must be exactly 6 digits'),
        );
        verifyNever(
          () => mockAuthRepository.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        );
      });

      test('should return ValidationException when OTP is too short', () async {
        // Act
        final result = await useCase.call(verificationId: 'vid', otp: '12345');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<String>;
        expect(failure.exception, isA<ValidationException>());
        expect(failure.exception.code, equals('invalid-otp'));
      });

      test('should return ValidationException when OTP is too long', () async {
        // Act
        final result = await useCase.call(
          verificationId: 'vid',
          otp: '1234567',
        );

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<ValidationException>());
      });

      test(
        'should return ValidationException when OTP contains letters',
        () async {
          // Act
          final result = await useCase.call(
            verificationId: 'vid',
            otp: '12ab56',
          );

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );

      test(
        'should return ValidationException when OTP contains spaces',
        () async {
          // Act
          final result = await useCase.call(
            verificationId: 'vid',
            otp: '123 56',
          );

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );

      test(
        'should return ValidationException when OTP contains special chars',
        () async {
          // Act
          final result = await useCase.call(
            verificationId: 'vid',
            otp: '12-456',
          );

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );
    });

    // ── Verification ID validation ──────────────────────────────────────

    group('verificationId validation', () {
      test(
        'should return ValidationException when verificationId is empty',
        () async {
          // Act
          final result = await useCase.call(verificationId: '', otp: '123456');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<String>;
          expect(failure.exception, isA<ValidationException>());
          expect(failure.exception.code, equals('empty-verification-id'));
          expect(
            failure.exception.message,
            equals('Verification ID cannot be empty'),
          );
          verifyNever(
            () => mockAuthRepository.verifyOtp(
              verificationId: any(named: 'verificationId'),
              otp: any(named: 'otp'),
            ),
          );
        },
      );
    });

    // ── Validation priority ─────────────────────────────────────────────

    group('validation priority', () {
      test(
        'should check verificationId before OTP when both are invalid',
        () async {
          // Act — both invalid: empty verificationId + invalid OTP
          final result = await useCase.call(verificationId: '', otp: '123');

          // Assert — verificationId error takes priority
          expect(result.isFailure, isTrue);
          final failure = result as Failure<String>;
          expect(failure.exception.code, equals('empty-verification-id'));
        },
      );
    });

    // ── Repository error propagation ────────────────────────────────────

    group('repository error propagation', () {
      test('should propagate AuthException from repository', () async {
        // Arrange
        when(
          () => mockAuthRepository.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer(
          (_) async => Result.failure(
            const AuthException(
              'Invalid OTP',
              code: 'invalid-verification-code',
            ),
          ),
        );

        // Act
        final result = await useCase.call(verificationId: 'vid', otp: '123456');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<String>;
        expect(failure.exception, isA<AuthException>());
        expect(failure.exception.code, equals('invalid-verification-code'));
      });

      test('should propagate NetworkException from repository', () async {
        // Arrange
        when(
          () => mockAuthRepository.verifyOtp(
            verificationId: any(named: 'verificationId'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer(
          (_) async => Result.failure(const NetworkException('No internet')),
        );

        // Act
        final result = await useCase.call(verificationId: 'vid', otp: '123456');

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<NetworkException>());
      });
    });
  });
}
