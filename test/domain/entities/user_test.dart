import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/domain/entities/app_locale.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';
import 'package:one_by_two/domain/entities/user.dart';

void main() {
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

  group('User entity', () {
    // ── Default values ──────────────────────────────────────────────────

    group('default values', () {
      test('should default isDeleted to false', () {
        final user = createTestUser();
        expect(user.isDeleted, isFalse);
      });

      test('should default fcmTokens to empty list', () {
        final user = createTestUser();
        expect(user.fcmTokens, isEmpty);
        expect(user.fcmTokens, isA<List<String>>());
      });

      test('should default language to AppLocale.en', () {
        final user = createTestUser();
        expect(user.language, equals(AppLocale.en));
      });

      test('should default notificationPrefs to NotificationPrefs()', () {
        final user = createTestUser();
        expect(user.notificationPrefs, equals(const NotificationPrefs()));
      });

      test('should default deletedAt to null', () {
        final user = createTestUser();
        expect(user.deletedAt, isNull);
      });

      test('should default deletedBy to null', () {
        final user = createTestUser();
        expect(user.deletedBy, isNull);
      });
    });

    // ── Required fields ─────────────────────────────────────────────────

    group('required fields', () {
      test('should store id correctly', () {
        final user = createTestUser(id: 'abc-123');
        expect(user.id, equals('abc-123'));
      });

      test('should store name correctly', () {
        final user = createTestUser(name: 'Avtansh Gupta');
        expect(user.name, equals('Avtansh Gupta'));
      });

      test('should store phone correctly', () {
        final user = createTestUser(phone: '+919876543210');
        expect(user.phone, equals('+919876543210'));
      });

      test('should store createdAt correctly', () {
        final date = DateTime(2024, 6, 15, 10, 30);
        final user = createTestUser(createdAt: date);
        expect(user.createdAt, equals(date));
      });

      test('should store updatedAt correctly', () {
        final date = DateTime(2024, 6, 15, 10, 30);
        final user = createTestUser(updatedAt: date);
        expect(user.updatedAt, equals(date));
      });
    });

    // ── Nullable fields ─────────────────────────────────────────────────

    group('nullable fields', () {
      test('should allow null email', () {
        final user = createTestUser(email: null);
        expect(user.email, isNull);
      });

      test('should store non-null email', () {
        final user = createTestUser(email: 'test@example.com');
        expect(user.email, equals('test@example.com'));
      });

      test('should allow null avatarUrl', () {
        final user = createTestUser(avatarUrl: null);
        expect(user.avatarUrl, isNull);
      });

      test('should store non-null avatarUrl', () {
        final user = createTestUser(
          avatarUrl: 'https://example.com/avatar.png',
        );
        expect(user.avatarUrl, equals('https://example.com/avatar.png'));
      });

      test('should allow null deletedAt', () {
        final user = createTestUser(deletedAt: null);
        expect(user.deletedAt, isNull);
      });

      test('should store non-null deletedAt', () {
        final deletedAt = DateTime(2024, 12, 25);
        final user = createTestUser(deletedAt: deletedAt);
        expect(user.deletedAt, equals(deletedAt));
      });

      test('should allow null deletedBy', () {
        final user = createTestUser(deletedBy: null);
        expect(user.deletedBy, isNull);
      });

      test('should store non-null deletedBy', () {
        final user = createTestUser(deletedBy: 'admin-uid');
        expect(user.deletedBy, equals('admin-uid'));
      });
    });

    // ── copyWith ────────────────────────────────────────────────────────

    group('copyWith', () {
      test('should create a new instance with changed name', () {
        final original = createTestUser(name: 'Original');
        final updated = original.copyWith(name: 'Updated');

        expect(updated.name, equals('Updated'));
        expect(original.name, equals('Original'));
      });

      test('should preserve unchanged fields', () {
        final original = createTestUser(
          id: 'uid-1',
          name: 'Test',
          phone: '+919876543210',
          email: 'test@example.com',
        );
        final updated = original.copyWith(name: 'New Name');

        expect(updated.id, equals(original.id));
        expect(updated.phone, equals(original.phone));
        expect(updated.email, equals(original.email));
        expect(updated.createdAt, equals(original.createdAt));
        expect(updated.updatedAt, equals(original.updatedAt));
        expect(updated.fcmTokens, equals(original.fcmTokens));
        expect(updated.notificationPrefs, equals(original.notificationPrefs));
        expect(updated.isDeleted, equals(original.isDeleted));
      });

      test('should update language', () {
        final user = createTestUser(language: AppLocale.en);
        final updated = user.copyWith(language: AppLocale.hi);

        expect(updated.language, equals(AppLocale.hi));
      });

      test('should update fcmTokens', () {
        final user = createTestUser(fcmTokens: []);
        final updated = user.copyWith(fcmTokens: ['token-1', 'token-2']);

        expect(updated.fcmTokens, equals(['token-1', 'token-2']));
      });

      test('should update isDeleted with deletedAt and deletedBy', () {
        final user = createTestUser();
        final deletedAt = DateTime(2024, 12, 31);
        final updated = user.copyWith(
          isDeleted: true,
          deletedAt: deletedAt,
          deletedBy: 'admin-uid',
        );

        expect(updated.isDeleted, isTrue);
        expect(updated.deletedAt, equals(deletedAt));
        expect(updated.deletedBy, equals('admin-uid'));
      });

      test('should update notificationPrefs', () {
        final user = createTestUser();
        final newPrefs = const NotificationPrefs(
          expenses: false,
          weeklyDigest: true,
        );
        final updated = user.copyWith(notificationPrefs: newPrefs);

        expect(updated.notificationPrefs.expenses, isFalse);
        expect(updated.notificationPrefs.weeklyDigest, isTrue);
      });
    });

    // ── Equality ────────────────────────────────────────────────────────

    group('equality', () {
      test('should be equal when all fields match', () {
        final user1 = createTestUser();
        final user2 = createTestUser();

        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('should not be equal when id differs', () {
        final user1 = createTestUser(id: 'uid-1');
        final user2 = createTestUser(id: 'uid-2');

        expect(user1, isNot(equals(user2)));
      });

      test('should not be equal when name differs', () {
        final user1 = createTestUser(name: 'Alice');
        final user2 = createTestUser(name: 'Bob');

        expect(user1, isNot(equals(user2)));
      });

      test('should not be equal when phone differs', () {
        final user1 = createTestUser(phone: '+919876543210');
        final user2 = createTestUser(phone: '+919876543211');

        expect(user1, isNot(equals(user2)));
      });

      test('should not be equal when language differs', () {
        final user1 = createTestUser(language: AppLocale.en);
        final user2 = createTestUser(language: AppLocale.hi);

        expect(user1, isNot(equals(user2)));
      });

      test('should not be equal when isDeleted differs', () {
        final user1 = createTestUser(isDeleted: false);
        final user2 = createTestUser(isDeleted: true);

        expect(user1, isNot(equals(user2)));
      });

      test('should not be equal when email differs', () {
        final user1 = createTestUser(email: null);
        final user2 = createTestUser(email: 'test@example.com');

        expect(user1, isNot(equals(user2)));
      });

      test('should not be equal when fcmTokens differ', () {
        final user1 = createTestUser(fcmTokens: []);
        final user2 = createTestUser(fcmTokens: ['token-1']);

        expect(user1, isNot(equals(user2)));
      });

      test('identical instance should be equal to itself', () {
        final user = createTestUser();
        expect(user, equals(user));
      });
    });

    // ── AppLocale enum ──────────────────────────────────────────────────

    group('AppLocale enum', () {
      test('should have en value', () {
        expect(AppLocale.en, isNotNull);
        expect(AppLocale.en.name, equals('en'));
      });

      test('should have hi value', () {
        expect(AppLocale.hi, isNotNull);
        expect(AppLocale.hi.name, equals('hi'));
      });

      test('should have exactly 2 values', () {
        expect(AppLocale.values.length, equals(2));
      });

      test('should be usable with User entity', () {
        for (final locale in AppLocale.values) {
          final user = createTestUser(language: locale);
          expect(user.language, equals(locale));
        }
      });
    });
  });
}
