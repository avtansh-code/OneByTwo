import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/domain/repositories/auth_repository.dart';
import 'package:one_by_two/domain/usecases/auth/sign_out_use_case.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late SignOutUseCase useCase;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = SignOutUseCase(mockAuthRepository);
  });

  group('SignOutUseCase', () {
    // ── Happy path ──────────────────────────────────────────────────────

    group('happy path', () {
      test('should delegate to repository and return success', () async {
        // Arrange
        when(
          () => mockAuthRepository.signOut(),
        ).thenAnswer((_) async => Result.success(null));

        // Act
        final result = await useCase.call();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockAuthRepository.signOut()).called(1);
      });
    });

    // ── Error path ──────────────────────────────────────────────────────

    group('error path', () {
      test('should propagate AuthException from repository', () async {
        // Arrange
        when(() => mockAuthRepository.signOut()).thenAnswer(
          (_) async => Result.failure(
            const AuthException('Sign-out failed', code: 'sign-out-error'),
          ),
        );

        // Act
        final result = await useCase.call();

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<void>;
        expect(failure.exception, isA<AuthException>());
        expect(failure.exception.code, equals('sign-out-error'));
        expect(failure.exception.message, equals('Sign-out failed'));
      });

      test('should propagate UnknownException from repository', () async {
        // Arrange
        when(() => mockAuthRepository.signOut()).thenAnswer(
          (_) async =>
              Result.failure(const UnknownException('Unexpected error')),
        );

        // Act
        final result = await useCase.call();

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<UnknownException>());
      });
    });
  });
}
