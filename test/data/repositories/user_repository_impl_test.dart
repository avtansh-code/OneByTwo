import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/data/models/notification_prefs_model.dart';
import 'package:one_by_two/data/models/user_model.dart';
import 'package:one_by_two/data/remote/firestore/user_firestore_source.dart';
import 'package:one_by_two/data/repositories/user_repository_impl.dart';
import 'package:one_by_two/domain/entities/app_locale.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';
import 'package:one_by_two/domain/entities/user.dart';

class MockUserFirestoreSource extends Mock implements UserFirestoreSource {}

void main() {
  late MockUserFirestoreSource mockUserSource;
  late UserRepositoryImpl repository;

  setUp(() {
    mockUserSource = MockUserFirestoreSource();
    repository = UserRepositoryImpl(mockUserSource);
  });

  // ── Test fixtures ───────────────────────────────────────────────────────
  final fixedCreatedAt = DateTime.utc(2024, 1, 1, 12, 0, 0);
  final fixedUpdatedAt = DateTime.utc(2024, 6, 15, 10, 30, 0);

  UserModel createTestModel({
    String uid = 'uid-123',
    String name = 'Test User',
    String? email = 'test@example.com',
    String phone = '+919876543210',
  }) => UserModel(
    uid: uid,
    name: name,
    email: email,
    phone: phone,
    createdAt: fixedCreatedAt,
    updatedAt: fixedUpdatedAt,
  );

  User createTestEntity({
    String id = 'uid-123',
    String name = 'Test User',
    String? email = 'test@example.com',
    String phone = '+919876543210',
  }) => User(
    id: id,
    name: name,
    email: email,
    phone: phone,
    createdAt: fixedCreatedAt,
    updatedAt: fixedUpdatedAt,
  );

  setUpAll(() {
    registerFallbackValue(createTestModel());
  });

  group('UserRepositoryImpl', () {
    // ── getUser ─────────────────────────────────────────────────────────

    group('getUser', () {
      test(
        'should return Success with User entity when source returns model',
        () async {
          // Arrange
          final model = createTestModel();
          when(
            () => mockUserSource.getUser(any()),
          ).thenAnswer((_) async => model);

          // Act
          final result = await repository.getUser('uid-123');

          // Assert
          expect(result.isSuccess, isTrue);
          final user = (result as Success<User>).data;
          expect(user.id, equals('uid-123'));
          expect(user.name, equals('Test User'));
          expect(user.email, equals('test@example.com'));
          expect(user.phone, equals('+919876543210'));
          expect(user.language, equals(AppLocale.en));
          verify(() => mockUserSource.getUser('uid-123')).called(1);
        },
      );

      test(
        'should return Failure with NotFoundException when source returns null',
        () async {
          // Arrange
          when(
            () => mockUserSource.getUser(any()),
          ).thenAnswer((_) async => null);

          // Act
          final result = await repository.getUser('nonexistent-uid');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<User>;
          expect(failure.exception, isA<NotFoundException>());
          expect(failure.exception.code, equals('not-found'));
          expect(failure.exception.message, equals('User not found'));
        },
      );

      test(
        'should return Failure with FirestoreException when source throws FirestoreException',
        () async {
          // Arrange
          when(() => mockUserSource.getUser(any())).thenThrow(
            const FirestoreException('Read failed', code: 'unavailable'),
          );

          // Act
          final result = await repository.getUser('uid-123');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<User>;
          expect(failure.exception, isA<FirestoreException>());
          expect(failure.exception.code, equals('unavailable'));
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          when(
            () => mockUserSource.getUser(any()),
          ).thenThrow(Exception('Unexpected'));

          // Act
          final result = await repository.getUser('uid-123');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<User>;
          expect(failure.exception, isA<UnknownException>());
          final unknown = failure.exception as UnknownException;
          expect(unknown.originalError, isA<Exception>());
        },
      );

      test('should correctly map all model fields to entity', () async {
        // Arrange
        final model = UserModel(
          uid: 'uid-full',
          name: 'Full User',
          email: 'full@example.com',
          phone: '+918765432100',
          avatarUrl: 'https://example.com/avatar.png',
          language: 'hi',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
          fcmTokens: ['token-a'],
          notificationPrefs: const NotificationPrefsModel(
            expenses: false,
            weeklyDigest: true,
          ),
          isDeleted: false,
        );
        when(
          () => mockUserSource.getUser(any()),
        ).thenAnswer((_) async => model);

        // Act
        final result = await repository.getUser('uid-full');

        // Assert
        expect(result.isSuccess, isTrue);
        final user = (result as Success<User>).data;
        expect(user.id, equals('uid-full'));
        expect(user.avatarUrl, equals('https://example.com/avatar.png'));
        expect(user.language, equals(AppLocale.hi));
        expect(user.fcmTokens, equals(['token-a']));
        expect(user.notificationPrefs.expenses, isFalse);
        expect(user.notificationPrefs.weeklyDigest, isTrue);
      });
    });

    // ── createUser ──────────────────────────────────────────────────────

    group('createUser', () {
      test('should return Success when source succeeds', () async {
        // Arrange
        final entity = createTestEntity();
        when(() => mockUserSource.createUser(any())).thenAnswer((_) async {});

        // Act
        final result = await repository.createUser(entity);

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockUserSource.createUser(any())).called(1);
      });

      test('should map entity to model before calling source', () async {
        // Arrange
        final entity = createTestEntity(
          id: 'uid-new',
          name: 'New User',
          phone: '+919000000000',
        );
        when(() => mockUserSource.createUser(any())).thenAnswer((_) async {});

        // Act
        await repository.createUser(entity);

        // Assert
        final captured = verify(
          () => mockUserSource.createUser(captureAny()),
        ).captured;
        final capturedModel = captured.first as UserModel;
        expect(capturedModel.uid, equals('uid-new'));
        expect(capturedModel.name, equals('New User'));
        expect(capturedModel.phone, equals('+919000000000'));
      });

      test(
        'should return Failure with FirestoreException when source throws',
        () async {
          // Arrange
          final entity = createTestEntity();
          when(() => mockUserSource.createUser(any())).thenThrow(
            const FirestoreException('Write failed', code: 'permission-denied'),
          );

          // Act
          final result = await repository.createUser(entity);

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<void>;
          expect(failure.exception, isA<FirestoreException>());
          expect(failure.exception.code, equals('permission-denied'));
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          final entity = createTestEntity();
          when(
            () => mockUserSource.createUser(any()),
          ).thenThrow(Exception('Unexpected'));

          // Act
          final result = await repository.createUser(entity);

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<UnknownException>());
        },
      );
    });

    // ── updateUser ──────────────────────────────────────────────────────

    group('updateUser', () {
      test('should return Success when source succeeds', () async {
        // Arrange
        final entity = createTestEntity();
        when(() => mockUserSource.updateUser(any())).thenAnswer((_) async {});

        // Act
        final result = await repository.updateUser(entity);

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockUserSource.updateUser(any())).called(1);
      });

      test('should map entity to model before calling source', () async {
        // Arrange
        final entity = createTestEntity(id: 'uid-update', name: 'Updated Name');
        when(() => mockUserSource.updateUser(any())).thenAnswer((_) async {});

        // Act
        await repository.updateUser(entity);

        // Assert
        final captured = verify(
          () => mockUserSource.updateUser(captureAny()),
        ).captured;
        final capturedModel = captured.first as UserModel;
        expect(capturedModel.uid, equals('uid-update'));
        expect(capturedModel.name, equals('Updated Name'));
      });

      test(
        'should return Failure with FirestoreException when source throws',
        () async {
          // Arrange
          final entity = createTestEntity();
          when(() => mockUserSource.updateUser(any())).thenThrow(
            const FirestoreException('Update failed', code: 'unavailable'),
          );

          // Act
          final result = await repository.updateUser(entity);

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<void>;
          expect(failure.exception, isA<FirestoreException>());
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          final entity = createTestEntity();
          when(
            () => mockUserSource.updateUser(any()),
          ).thenThrow(Exception('Unexpected'));

          // Act
          final result = await repository.updateUser(entity);

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<UnknownException>());
        },
      );
    });

    // ── userExists ──────────────────────────────────────────────────────

    group('userExists', () {
      test('should return Success(true) when user exists', () async {
        // Arrange
        when(
          () => mockUserSource.userExists(any()),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.userExists('uid-123');

        // Assert
        expect(result.isSuccess, isTrue);
        expect((result as Success<bool>).data, isTrue);
        verify(() => mockUserSource.userExists('uid-123')).called(1);
      });

      test('should return Success(false) when user does not exist', () async {
        // Arrange
        when(
          () => mockUserSource.userExists(any()),
        ).thenAnswer((_) async => false);

        // Act
        final result = await repository.userExists('nonexistent');

        // Assert
        expect(result.isSuccess, isTrue);
        expect((result as Success<bool>).data, isFalse);
      });

      test(
        'should return Failure with FirestoreException when source throws',
        () async {
          // Arrange
          when(() => mockUserSource.userExists(any())).thenThrow(
            const FirestoreException('Check failed', code: 'unavailable'),
          );

          // Act
          final result = await repository.userExists('uid-123');

          // Assert
          expect(result.isFailure, isTrue);
          final failure = result as Failure<bool>;
          expect(failure.exception, isA<FirestoreException>());
        },
      );

      test(
        'should return Failure with UnknownException for unexpected errors',
        () async {
          // Arrange
          when(
            () => mockUserSource.userExists(any()),
          ).thenThrow(Exception('Unexpected'));

          // Act
          final result = await repository.userExists('uid-123');

          // Assert
          expect(result.isFailure, isTrue);
          expect((result as Failure).exception, isA<UnknownException>());
        },
      );
    });

    // ── watchUser ───────────────────────────────────────────────────────

    group('watchUser', () {
      test('should map stream of models to stream of entities', () {
        // Arrange
        final model = createTestModel(uid: 'uid-watch', name: 'Watch User');
        when(
          () => mockUserSource.watchUser(any()),
        ).thenAnswer((_) => Stream.value(model));

        // Act
        final stream = repository.watchUser('uid-watch');

        // Assert
        expect(
          stream,
          emits(
            isA<User>()
                .having((u) => u.id, 'id', equals('uid-watch'))
                .having((u) => u.name, 'name', equals('Watch User')),
          ),
        );
      });

      test('should emit null when source emits null', () {
        // Arrange
        when(
          () => mockUserSource.watchUser(any()),
        ).thenAnswer((_) => Stream.value(null));

        // Act
        final stream = repository.watchUser('nonexistent');

        // Assert
        expect(stream, emits(isNull));
      });

      test('should emit multiple values from source', () {
        // Arrange
        final model1 = createTestModel(name: 'Name 1');
        final model2 = createTestModel(name: 'Name 2');
        when(
          () => mockUserSource.watchUser(any()),
        ).thenAnswer((_) => Stream.fromIterable([model1, null, model2]));

        // Act
        final stream = repository.watchUser('uid-123');

        // Assert
        expect(
          stream,
          emitsInOrder([
            isA<User>().having((u) => u.name, 'name', equals('Name 1')),
            isNull,
            isA<User>().having((u) => u.name, 'name', equals('Name 2')),
          ]),
        );
      });

      test('should correctly map model fields in stream', () {
        // Arrange
        final model = UserModel(
          uid: 'uid-stream',
          name: 'Stream User',
          email: 'stream@example.com',
          phone: '+917777777777',
          language: 'hi',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
          notificationPrefs: const NotificationPrefsModel(
            expenses: false,
            weeklyDigest: true,
          ),
        );
        when(
          () => mockUserSource.watchUser(any()),
        ).thenAnswer((_) => Stream.value(model));

        // Act
        final stream = repository.watchUser('uid-stream');

        // Assert
        expect(
          stream,
          emits(
            isA<User>()
                .having((u) => u.id, 'id', equals('uid-stream'))
                .having((u) => u.language, 'language', equals(AppLocale.hi))
                .having(
                  (u) => u.notificationPrefs,
                  'notificationPrefs',
                  equals(
                    const NotificationPrefs(
                      expenses: false,
                      weeklyDigest: true,
                    ),
                  ),
                ),
          ),
        );
      });
    });
  });
}
