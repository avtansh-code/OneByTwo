import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/data/mappers/user_mapper.dart';
import 'package:one_by_two/data/models/notification_prefs_model.dart';
import 'package:one_by_two/data/models/user_model.dart';
import 'package:one_by_two/domain/entities/app_locale.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';
import 'package:one_by_two/domain/entities/user.dart';

void main() {
  group('UserMapper', () {
    // ── Test fixtures ───────────────────────────────────────────────────
    final fixedCreatedAt = DateTime.utc(2024, 1, 1, 12, 0, 0);
    final fixedUpdatedAt = DateTime.utc(2024, 6, 15, 10, 30, 0);
    final fixedDeletedAt = DateTime.utc(2024, 12, 25, 0, 0, 0);

    UserModel createTestModel({
      String uid = 'uid-123',
      String name = 'Test User',
      String? email = 'test@example.com',
      String phone = '+919876543210',
      String? avatarUrl = 'https://example.com/avatar.png',
      String language = 'en',
      DateTime? createdAt,
      DateTime? updatedAt,
      List<String> fcmTokens = const ['token-1'],
      NotificationPrefsModel notificationPrefs = const NotificationPrefsModel(),
      bool isDeleted = false,
      DateTime? deletedAt,
      String? deletedBy,
    }) => UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      language: language,
      createdAt: createdAt ?? fixedCreatedAt,
      updatedAt: updatedAt ?? fixedUpdatedAt,
      fcmTokens: fcmTokens,
      notificationPrefs: notificationPrefs,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
    );

    User createTestEntity({
      String id = 'uid-123',
      String name = 'Test User',
      String? email = 'test@example.com',
      String phone = '+919876543210',
      String? avatarUrl = 'https://example.com/avatar.png',
      AppLocale language = AppLocale.en,
      DateTime? createdAt,
      DateTime? updatedAt,
      List<String> fcmTokens = const ['token-1'],
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
      createdAt: createdAt ?? fixedCreatedAt,
      updatedAt: updatedAt ?? fixedUpdatedAt,
      fcmTokens: fcmTokens,
      notificationPrefs: notificationPrefs,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
    );

    // ── toEntity ────────────────────────────────────────────────────────

    group('toEntity', () {
      test('should map all fields from model to entity correctly', () {
        // Arrange
        final model = createTestModel();

        // Act
        final entity = UserMapper.toEntity(model);

        // Assert
        expect(entity.id, equals(model.uid));
        expect(entity.name, equals(model.name));
        expect(entity.email, equals(model.email));
        expect(entity.phone, equals(model.phone));
        expect(entity.avatarUrl, equals(model.avatarUrl));
        expect(entity.language, equals(AppLocale.en));
        expect(entity.createdAt, equals(model.createdAt));
        expect(entity.updatedAt, equals(model.updatedAt));
        expect(entity.fcmTokens, equals(model.fcmTokens));
        expect(entity.isDeleted, equals(model.isDeleted));
        expect(entity.deletedAt, equals(model.deletedAt));
        expect(entity.deletedBy, equals(model.deletedBy));
      });

      test('should map null optional fields correctly', () {
        // Arrange
        final model = createTestModel(
          email: null,
          avatarUrl: null,
          deletedAt: null,
          deletedBy: null,
        );

        // Act
        final entity = UserMapper.toEntity(model);

        // Assert
        expect(entity.email, isNull);
        expect(entity.avatarUrl, isNull);
        expect(entity.deletedAt, isNull);
        expect(entity.deletedBy, isNull);
      });

      test('should map soft-deleted model correctly', () {
        // Arrange
        final model = createTestModel(
          isDeleted: true,
          deletedAt: fixedDeletedAt,
          deletedBy: 'admin-uid',
        );

        // Act
        final entity = UserMapper.toEntity(model);

        // Assert
        expect(entity.isDeleted, isTrue);
        expect(entity.deletedAt, equals(fixedDeletedAt));
        expect(entity.deletedBy, equals('admin-uid'));
      });

      test('should map notificationPrefs from model to entity', () {
        // Arrange
        final model = createTestModel(
          notificationPrefs: const NotificationPrefsModel(
            expenses: false,
            settlements: true,
            reminders: false,
            weeklyDigest: true,
          ),
        );

        // Act
        final entity = UserMapper.toEntity(model);

        // Assert
        expect(entity.notificationPrefs.expenses, isFalse);
        expect(entity.notificationPrefs.settlements, isTrue);
        expect(entity.notificationPrefs.reminders, isFalse);
        expect(entity.notificationPrefs.weeklyDigest, isTrue);
      });
    });

    // ── toModel ─────────────────────────────────────────────────────────

    group('toModel', () {
      test('should map all fields from entity to model correctly', () {
        // Arrange
        final entity = createTestEntity();

        // Act
        final model = UserMapper.toModel(entity);

        // Assert
        expect(model.uid, equals(entity.id));
        expect(model.name, equals(entity.name));
        expect(model.email, equals(entity.email));
        expect(model.phone, equals(entity.phone));
        expect(model.avatarUrl, equals(entity.avatarUrl));
        expect(model.language, equals('en'));
        expect(model.createdAt, equals(entity.createdAt));
        expect(model.updatedAt, equals(entity.updatedAt));
        expect(model.fcmTokens, equals(entity.fcmTokens));
        expect(model.isDeleted, equals(entity.isDeleted));
        expect(model.deletedAt, equals(entity.deletedAt));
        expect(model.deletedBy, equals(entity.deletedBy));
      });

      test('should map null optional fields correctly', () {
        // Arrange
        final entity = createTestEntity(
          email: null,
          avatarUrl: null,
          deletedAt: null,
          deletedBy: null,
        );

        // Act
        final model = UserMapper.toModel(entity);

        // Assert
        expect(model.email, isNull);
        expect(model.avatarUrl, isNull);
        expect(model.deletedAt, isNull);
        expect(model.deletedBy, isNull);
      });

      test('should map soft-deleted entity correctly', () {
        // Arrange
        final entity = createTestEntity(
          isDeleted: true,
          deletedAt: fixedDeletedAt,
          deletedBy: 'admin-uid',
        );

        // Act
        final model = UserMapper.toModel(entity);

        // Assert
        expect(model.isDeleted, isTrue);
        expect(model.deletedAt, equals(fixedDeletedAt));
        expect(model.deletedBy, equals('admin-uid'));
      });

      test('should map notificationPrefs from entity to model', () {
        // Arrange
        final entity = createTestEntity(
          notificationPrefs: const NotificationPrefs(
            expenses: false,
            settlements: true,
            reminders: false,
            weeklyDigest: true,
          ),
        );

        // Act
        final model = UserMapper.toModel(entity);

        // Assert
        expect(model.notificationPrefs.expenses, isFalse);
        expect(model.notificationPrefs.settlements, isTrue);
        expect(model.notificationPrefs.reminders, isFalse);
        expect(model.notificationPrefs.weeklyDigest, isTrue);
      });
    });

    // ── AppLocale ↔ String conversion ───────────────────────────────────

    group('AppLocale ↔ String conversion', () {
      test('should map language "en" to AppLocale.en', () {
        final model = createTestModel(language: 'en');
        final entity = UserMapper.toEntity(model);
        expect(entity.language, equals(AppLocale.en));
      });

      test('should map language "hi" to AppLocale.hi', () {
        final model = createTestModel(language: 'hi');
        final entity = UserMapper.toEntity(model);
        expect(entity.language, equals(AppLocale.hi));
      });

      test('should default to AppLocale.en for unknown language string', () {
        final model = createTestModel(language: 'fr');
        final entity = UserMapper.toEntity(model);
        expect(entity.language, equals(AppLocale.en));
      });

      test('should default to AppLocale.en for empty language string', () {
        final model = createTestModel(language: '');
        final entity = UserMapper.toEntity(model);
        expect(entity.language, equals(AppLocale.en));
      });

      test('should map AppLocale.en to "en"', () {
        final entity = createTestEntity(language: AppLocale.en);
        final model = UserMapper.toModel(entity);
        expect(model.language, equals('en'));
      });

      test('should map AppLocale.hi to "hi"', () {
        final entity = createTestEntity(language: AppLocale.hi);
        final model = UserMapper.toModel(entity);
        expect(model.language, equals('hi'));
      });

      test('should round-trip all AppLocale values through conversion', () {
        for (final locale in AppLocale.values) {
          // Entity → Model → Entity
          final entity = createTestEntity(language: locale);
          final model = UserMapper.toModel(entity);
          final roundTripped = UserMapper.toEntity(model);

          expect(roundTripped.language, equals(locale));
        }
      });
    });

    // ── Round-trip: toEntity(toModel(entity)) ───────────────────────────

    group('round-trip', () {
      test(
        'should produce equivalent entity after entity → model → entity',
        () {
          // Arrange
          final original = createTestEntity();

          // Act
          final model = UserMapper.toModel(original);
          final roundTripped = UserMapper.toEntity(model);

          // Assert
          expect(roundTripped.id, equals(original.id));
          expect(roundTripped.name, equals(original.name));
          expect(roundTripped.email, equals(original.email));
          expect(roundTripped.phone, equals(original.phone));
          expect(roundTripped.avatarUrl, equals(original.avatarUrl));
          expect(roundTripped.language, equals(original.language));
          expect(roundTripped.createdAt, equals(original.createdAt));
          expect(roundTripped.updatedAt, equals(original.updatedAt));
          expect(roundTripped.fcmTokens, equals(original.fcmTokens));
          expect(
            roundTripped.notificationPrefs,
            equals(original.notificationPrefs),
          );
          expect(roundTripped.isDeleted, equals(original.isDeleted));
          expect(roundTripped.deletedAt, equals(original.deletedAt));
          expect(roundTripped.deletedBy, equals(original.deletedBy));
        },
      );

      test(
        'should produce equivalent entity after round-trip with all optional fields',
        () {
          // Arrange
          final original = createTestEntity(
            email: 'user@example.com',
            avatarUrl: 'https://example.com/pic.png',
            language: AppLocale.hi,
            fcmTokens: ['token-a', 'token-b'],
            notificationPrefs: const NotificationPrefs(
              expenses: false,
              weeklyDigest: true,
            ),
            isDeleted: true,
            deletedAt: fixedDeletedAt,
            deletedBy: 'admin',
          );

          // Act
          final model = UserMapper.toModel(original);
          final roundTripped = UserMapper.toEntity(model);

          // Assert — freezed equality compares all fields
          expect(roundTripped, equals(original));
        },
      );

      test(
        'should produce equivalent entity after round-trip with null optionals',
        () {
          // Arrange
          final original = createTestEntity(
            email: null,
            avatarUrl: null,
            deletedAt: null,
            deletedBy: null,
          );

          // Act
          final model = UserMapper.toModel(original);
          final roundTripped = UserMapper.toEntity(model);

          // Assert
          expect(roundTripped, equals(original));
        },
      );

      test('should produce equivalent model after model → entity → model', () {
        // Arrange
        final original = createTestModel();

        // Act
        final entity = UserMapper.toEntity(original);
        final roundTripped = UserMapper.toModel(entity);

        // Assert
        expect(roundTripped.uid, equals(original.uid));
        expect(roundTripped.name, equals(original.name));
        expect(roundTripped.email, equals(original.email));
        expect(roundTripped.phone, equals(original.phone));
        expect(roundTripped.avatarUrl, equals(original.avatarUrl));
        expect(roundTripped.language, equals(original.language));
        expect(roundTripped.createdAt, equals(original.createdAt));
        expect(roundTripped.updatedAt, equals(original.updatedAt));
        expect(roundTripped.fcmTokens, equals(original.fcmTokens));
        expect(roundTripped.isDeleted, equals(original.isDeleted));
        expect(roundTripped.deletedAt, equals(original.deletedAt));
        expect(roundTripped.deletedBy, equals(original.deletedBy));
      });
    });
  });
}
