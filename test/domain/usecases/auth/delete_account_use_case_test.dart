import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/domain/repositories/auth_repository.dart';
import 'package:one_by_two/domain/usecases/auth/delete_account_use_case.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late DeleteAccountUseCase useCase;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = DeleteAccountUseCase(mockAuthRepository);
  });

  group('DeleteAccountUseCase', () {
    // ── Happy path ──────────────────────────────────────────────────────

    group('happy path', () {
      test('should delegate to repository and return success', () async {
        // Arrange
        when(
          () => mockAuthRepository.deleteAccount(),
        ).thenAnswer((_) async => Result.success(null));

        // Act
        final result = await useCase.call();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockAuthRepository.deleteAccount()).called(1);
      });
    });

    // ── Error path ──────────────────────────────────────────────────────

    group('error path', () {
      test('should propagate AuthException from repository', () async {
        // Arrange
        when(() => mockAuthRepository.deleteAccount()).thenAnswer(
          (_) async => Result.failure(
            const AuthException(
              'Re-authentication required',
              code: 'requires-recent-login',
            ),
          ),
        );

        // Act
        final result = await useCase.call();

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<void>;
        expect(failure.exception, isA<AuthException>());
        expect(failure.exception.code, equals('requires-recent-login'));
        expect(
          failure.exception.message,
          equals('Re-authentication required'),
        );
      });

      test('should propagate UnknownException from repository', () async {
        // Arrange
        when(() => mockAuthRepository.deleteAccount()).thenAnswer(
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
