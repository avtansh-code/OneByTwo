import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/domain/entities/user.dart';
import 'package:one_by_two/domain/repositories/user_repository.dart';
import 'package:one_by_two/domain/usecases/user/get_user_use_case.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository mockUserRepository;
  late GetUserUseCase useCase;

  setUp(() {
    mockUserRepository = MockUserRepository();
    useCase = GetUserUseCase(mockUserRepository);
  });

  group('GetUserUseCase', () {
    final testUser = User(
      id: 'uid-123',
      name: 'Test User',
      phone: '+919876543210',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    // ── Happy path ──────────────────────────────────────────────────────

    group('happy path', () {
      test('should return user when uid is valid', () async {
        // Arrange
        when(
          () => mockUserRepository.getUser(any()),
        ).thenAnswer((_) async => Result.success(testUser));

        // Act
        final result = await useCase.call('uid-123');

        // Assert
        expect(result.isSuccess, isTrue);
        final success = result as Success<User>;
        expect(success.data, equals(testUser));
        verify(() => mockUserRepository.getUser('uid-123')).called(1);
      });

      test('should pass uid to repository exactly as given', () async {
        // Arrange
        when(
          () => mockUserRepository.getUser(any()),
        ).thenAnswer((_) async => Result.success(testUser));

        // Act
        await useCase.call('specific-uid-abc');

        // Assert
        verify(() => mockUserRepository.getUser('specific-uid-abc')).called(1);
      });
    });

    // ── UID validation ──────────────────────────────────────────────────

    group('uid validation', () {
      test('should return ValidationException when uid is empty', () async {
        // Act
        final result = await useCase.call('');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<User>;
        expect(failure.exception, isA<ValidationException>());
        expect(failure.exception.code, equals('empty-user-id'));
        expect(failure.exception.message, equals('User ID cannot be empty'));
        verifyNever(() => mockUserRepository.getUser(any()));
      });

      test(
        'should return ValidationException when uid is whitespace only',
        () async {
          // Act
          final result = await useCase.call('   ');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<User>;
          expect(failure.exception, isA<ValidationException>());
          expect(failure.exception.code, equals('empty-user-id'));
          verifyNever(() => mockUserRepository.getUser(any()));
        },
      );

      test(
        'should return ValidationException when uid is tab characters',
        () async {
          // Act
          final result = await useCase.call('\t');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );
    });

    // ── Repository error propagation ────────────────────────────────────

    group('repository error propagation', () {
      test('should propagate NotFoundException from repository', () async {
        // Arrange
        when(() => mockUserRepository.getUser(any())).thenAnswer(
          (_) async => Result.failure(
            const NotFoundException('User not found', code: 'not-found'),
          ),
        );

        // Act
        final result = await useCase.call('nonexistent-uid');

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<User>;
        expect(failure.exception, isA<NotFoundException>());
        expect(failure.exception.code, equals('not-found'));
      });

      test('should propagate FirestoreException from repository', () async {
        // Arrange
        when(() => mockUserRepository.getUser(any())).thenAnswer(
          (_) async => Result.failure(
            const FirestoreException('Read failed', code: 'unavailable'),
          ),
        );

        // Act
        final result = await useCase.call('uid-123');

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<FirestoreException>());
      });

      test('should propagate UnknownException from repository', () async {
        // Arrange
        when(() => mockUserRepository.getUser(any())).thenAnswer(
          (_) async => Result.failure(const UnknownException('Unexpected')),
        );

        // Act
        final result = await useCase.call('uid-123');

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<UnknownException>());
      });
    });
  });
}
