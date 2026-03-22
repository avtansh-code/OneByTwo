import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/domain/entities/app_locale.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';
import 'package:one_by_two/domain/entities/user.dart';
import 'package:one_by_two/domain/repositories/user_repository.dart';
import 'package:one_by_two/domain/usecases/user/create_user_use_case.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository mockUserRepository;
  late CreateUserUseCase useCase;

  setUp(() {
    mockUserRepository = MockUserRepository();
    useCase = CreateUserUseCase(mockUserRepository);
  });

  // ── Helper ──────────────────────────────────────────────────────────────
  User createTestUser({
    String id = 'test-uid',
    String name = 'Test User',
    String? email,
    String phone = '+919876543210',
    String? avatarUrl,
    AppLocale language = AppLocale.en,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String> fcmTokens = const [],
    NotificationPrefs notificationPrefs = const NotificationPrefs(),
    bool isDeleted = false,
    DateTime? deletedAt,
    String? deletedBy,
  }) => User(
    id: id,
    name: name,
    email: email,
    phone: phone,
    avatarUrl: avatarUrl,
    language: language,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
    updatedAt: updatedAt ?? DateTime(2024, 1, 1),
    fcmTokens: fcmTokens,
    notificationPrefs: notificationPrefs,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
    deletedBy: deletedBy,
  );

  setUpAll(() {
    registerFallbackValue(createTestUser());
  });

  group('CreateUserUseCase', () {
    // ── Happy path ──────────────────────────────────────────────────────

    group('happy path', () {
      test('should delegate to repository when user is valid', () async {
        // Arrange
        final user = createTestUser();
        when(
          () => mockUserRepository.createUser(any()),
        ).thenAnswer((_) async => Result.success(null));

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockUserRepository.createUser(user)).called(1);
      });

      test('should accept user with all optional fields', () async {
        // Arrange
        final user = createTestUser(
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.png',
          language: AppLocale.hi,
          fcmTokens: ['token-1'],
        );
        when(
          () => mockUserRepository.createUser(any()),
        ).thenAnswer((_) async => Result.success(null));

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isSuccess, isTrue);
      });

      test('should accept user with name containing spaces', () async {
        // Arrange
        final user = createTestUser(name: 'Avtansh Gupta');
        when(
          () => mockUserRepository.createUser(any()),
        ).thenAnswer((_) async => Result.success(null));

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isSuccess, isTrue);
      });
    });

    // ── Name validation ─────────────────────────────────────────────────

    group('name validation', () {
      test('should return ValidationException when name is empty', () async {
        // Arrange
        final user = createTestUser(name: '');

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<void>;
        expect(failure.exception, isA<ValidationException>());
        expect(failure.exception.code, equals('empty-user-name'));
        expect(failure.exception.message, equals('User name cannot be empty'));
        verifyNever(() => mockUserRepository.createUser(any()));
      });

      test(
        'should return ValidationException when name is whitespace only',
        () async {
          // Arrange
          final user = createTestUser(name: '   ');

          // Act
          final result = await useCase.call(user);

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
          expect(result.exception.code, equals('empty-user-name'));
          verifyNever(() => mockUserRepository.createUser(any()));
        },
      );

      test(
        'should return ValidationException when name is tab characters',
        () async {
          // Arrange
          final user = createTestUser(name: '\t\t');

          // Act
          final result = await useCase.call(user);

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
        },
      );
    });

    // ── Phone validation ────────────────────────────────────────────────

    group('phone validation', () {
      test('should return ValidationException when phone is empty', () async {
        // Arrange
        final user = createTestUser(phone: '');

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<void>;
        expect(failure.exception, isA<ValidationException>());
        expect(failure.exception.code, equals('empty-phone-number'));
        expect(
          failure.exception.message,
          equals('Phone number cannot be empty'),
        );
        verifyNever(() => mockUserRepository.createUser(any()));
      });

      test(
        'should return ValidationException when phone is whitespace only',
        () async {
          // Arrange
          final user = createTestUser(phone: '   ');

          // Act
          final result = await useCase.call(user);

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<ValidationException>());
          expect(result.exception.code, equals('empty-phone-number'));
        },
      );
    });

    // ── Validation priority ─────────────────────────────────────────────

    group('validation priority', () {
      test('should check name before phone when both are invalid', () async {
        // Arrange
        final user = createTestUser(name: '', phone: '');

        // Act
        final result = await useCase.call(user);

        // Assert — name validation happens first
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception.code, equals('empty-user-name'));
      });
    });

    // ── Repository error propagation ────────────────────────────────────

    group('repository error propagation', () {
      test('should propagate FirestoreException from repository', () async {
        // Arrange
        final user = createTestUser();
        when(() => mockUserRepository.createUser(any())).thenAnswer(
          (_) async => Result.failure(
            const FirestoreException('Write failed', code: 'permission-denied'),
          ),
        );

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isFailure, isTrue);
        final failure = result as Failure<void>;
        expect(failure.exception, isA<FirestoreException>());
        expect(failure.exception.code, equals('permission-denied'));
      });

      test('should propagate UnknownException from repository', () async {
        // Arrange
        final user = createTestUser();
        when(() => mockUserRepository.createUser(any())).thenAnswer(
          (_) async =>
              Result.failure(const UnknownException('Unexpected error')),
        );

        // Act
        final result = await useCase.call(user);

        // Assert
        expect(result.isFailure, isTrue);
        expect((result as Failure).exception, isA<UnknownException>());
      });
    });
  });
}
