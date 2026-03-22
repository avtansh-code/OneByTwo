import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/data/models/notification_prefs_model.dart';
import 'package:one_by_two/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    // ── Test fixtures ─────────────────────────────────────────────────────
    final fixedCreatedAt = DateTime.utc(2024, 1, 1, 12, 0, 0);
    final fixedUpdatedAt = DateTime.utc(2024, 6, 15, 10, 30, 0);
    final fixedDeletedAt = DateTime.utc(2024, 12, 25, 0, 0, 0);

    Map<String, dynamic> createFullJson({
      String uid = 'uid-123',
      String name = 'Test User',
      String? email = 'test@example.com',
      String phone = '+919876543210',
      String? avatarUrl = 'https://example.com/avatar.png',
      String language = 'en',
      DateTime? createdAt,
      DateTime? updatedAt,
      List<String> fcmTokens = const ['token-1', 'token-2'],
      Map<String, dynamic>? notificationPrefs,
      bool isDeleted = false,
      DateTime? deletedAt,
      String? deletedBy,
    }) => <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'language': language,
      'createdAt': (createdAt ?? fixedCreatedAt).toIso8601String(),
      'updatedAt': (updatedAt ?? fixedUpdatedAt).toIso8601String(),
      'fcmTokens': fcmTokens,
      'notificationPrefs':
          notificationPrefs ??
          {
            'expenses': true,
            'settlements': true,
            'reminders': true,
            'weeklyDigest': false,
          },
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': deletedAt.toIso8601String(),
      if (deletedBy != null) 'deletedBy': deletedBy,
    };

    UserModel createTestModel({
      String uid = 'uid-123',
      String name = 'Test User',
      String? email = 'test@example.com',
      String phone = '+919876543210',
      String? avatarUrl = 'https://example.com/avatar.png',
      String language = 'en',
      DateTime? createdAt,
      DateTime? updatedAt,
      List<String> fcmTokens = const ['token-1', 'token-2'],
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

    // ── Constructor defaults ────────────────────────────────────────────

    group('constructor defaults', () {
      test('should default language to en', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.language, equals('en'));
      });

      test('should default fcmTokens to empty list', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.fcmTokens, isEmpty);
      });

      test('should default notificationPrefs to NotificationPrefsModel()', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.notificationPrefs.expenses, isTrue);
        expect(model.notificationPrefs.settlements, isTrue);
        expect(model.notificationPrefs.reminders, isTrue);
        expect(model.notificationPrefs.weeklyDigest, isFalse);
      });

      test('should default isDeleted to false', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.isDeleted, isFalse);
      });

      test('should default email to null', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.email, isNull);
      });

      test('should default avatarUrl to null', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.avatarUrl, isNull);
      });

      test('should default deletedAt to null', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.deletedAt, isNull);
      });

      test('should default deletedBy to null', () {
        final model = UserModel(
          uid: 'uid',
          name: 'Name',
          phone: '+919876543210',
          createdAt: fixedCreatedAt,
          updatedAt: fixedUpdatedAt,
        );
        expect(model.deletedBy, isNull);
      });
    });

    // ── fromJson ────────────────────────────────────────────────────────

    group('fromJson', () {
      test('should parse all fields correctly', () {
        // Arrange
        final json = createFullJson();

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.uid, equals('uid-123'));
        expect(model.name, equals('Test User'));
        expect(model.email, equals('test@example.com'));
        expect(model.phone, equals('+919876543210'));
        expect(model.avatarUrl, equals('https://example.com/avatar.png'));
        expect(model.language, equals('en'));
        expect(model.createdAt, equals(fixedCreatedAt));
        expect(model.updatedAt, equals(fixedUpdatedAt));
        expect(model.fcmTokens, equals(['token-1', 'token-2']));
        expect(model.notificationPrefs.expenses, isTrue);
        expect(model.isDeleted, isFalse);
        expect(model.deletedAt, isNull);
        expect(model.deletedBy, isNull);
      });

      test('should handle nullable fields as null', () {
        // Arrange
        final json = <String, dynamic>{
          'uid': 'uid-123',
          'name': 'Test',
          'phone': '+919876543210',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.email, isNull);
        expect(model.avatarUrl, isNull);
        expect(model.deletedAt, isNull);
        expect(model.deletedBy, isNull);
      });

      test('should use default values for missing optional fields', () {
        // Arrange
        final json = <String, dynamic>{
          'uid': 'uid',
          'name': 'Name',
          'phone': '+919876543210',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.language, equals('en'));
        expect(model.fcmTokens, isEmpty);
        expect(model.isDeleted, isFalse);
        expect(model.notificationPrefs.expenses, isTrue);
        expect(model.notificationPrefs.weeklyDigest, isFalse);
      });

      test('should parse deletedAt and deletedBy when present', () {
        // Arrange
        final json = createFullJson(
          isDeleted: true,
          deletedAt: fixedDeletedAt,
          deletedBy: 'admin-uid',
        );

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.isDeleted, isTrue);
        expect(model.deletedAt, equals(fixedDeletedAt));
        expect(model.deletedBy, equals('admin-uid'));
      });

      test('should parse hindi language', () {
        // Arrange
        final json = createFullJson(language: 'hi');

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.language, equals('hi'));
      });
    });

    // ── toJson ──────────────────────────────────────────────────────────

    group('toJson', () {
      test('should serialize all fields correctly', () {
        // Arrange
        final model = createTestModel();

        // Act
        final json = model.toJson();

        // Assert
        expect(json['uid'], equals('uid-123'));
        expect(json['name'], equals('Test User'));
        expect(json['email'], equals('test@example.com'));
        expect(json['phone'], equals('+919876543210'));
        expect(json['avatarUrl'], equals('https://example.com/avatar.png'));
        expect(json['language'], equals('en'));
        expect(json['createdAt'], equals(fixedCreatedAt.toIso8601String()));
        expect(json['updatedAt'], equals(fixedUpdatedAt.toIso8601String()));
        expect(json['fcmTokens'], equals(['token-1', 'token-2']));
        expect(json['notificationPrefs'], isA<Map<String, dynamic>>());
        expect(json['isDeleted'], isFalse);
        expect(json['deletedAt'], isNull);
        expect(json['deletedBy'], isNull);
      });

      test('should serialize notificationPrefs as nested map', () {
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
        final json = model.toJson();
        final prefsJson = json['notificationPrefs'] as Map<String, dynamic>;

        // Assert
        expect(prefsJson['expenses'], isFalse);
        expect(prefsJson['settlements'], isTrue);
        expect(prefsJson['reminders'], isFalse);
        expect(prefsJson['weeklyDigest'], isTrue);
      });

      test('should serialize null optional fields', () {
        // Arrange
        final model = createTestModel(
          email: null,
          avatarUrl: null,
          deletedAt: null,
          deletedBy: null,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['email'], isNull);
        expect(json['avatarUrl'], isNull);
        expect(json['deletedAt'], isNull);
        expect(json['deletedBy'], isNull);
      });

      test('should serialize deletedAt when present', () {
        // Arrange
        final model = createTestModel(
          isDeleted: true,
          deletedAt: fixedDeletedAt,
          deletedBy: 'admin-uid',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['isDeleted'], isTrue);
        expect(json['deletedAt'], equals(fixedDeletedAt.toIso8601String()));
        expect(json['deletedBy'], equals('admin-uid'));
      });
    });

    // ── fromJson → toJson round-trip ────────────────────────────────────

    group('JSON round-trip', () {
      test(
        'should produce identical JSON after round-trip with all fields',
        () {
          // Arrange
          final originalJson = createFullJson();

          // Act
          final model = UserModel.fromJson(originalJson);
          final roundTrippedJson = model.toJson();

          // Assert
          expect(roundTrippedJson['uid'], equals(originalJson['uid']));
          expect(roundTrippedJson['name'], equals(originalJson['name']));
          expect(roundTrippedJson['email'], equals(originalJson['email']));
          expect(roundTrippedJson['phone'], equals(originalJson['phone']));
          expect(
            roundTrippedJson['avatarUrl'],
            equals(originalJson['avatarUrl']),
          );
          expect(
            roundTrippedJson['language'],
            equals(originalJson['language']),
          );
          expect(
            roundTrippedJson['createdAt'],
            equals(originalJson['createdAt']),
          );
          expect(
            roundTrippedJson['updatedAt'],
            equals(originalJson['updatedAt']),
          );
          expect(
            roundTrippedJson['fcmTokens'],
            equals(originalJson['fcmTokens']),
          );
          expect(
            roundTrippedJson['isDeleted'],
            equals(originalJson['isDeleted']),
          );
        },
      );

      test(
        'should produce identical JSON after round-trip with minimal fields',
        () {
          // Arrange
          final originalJson = <String, dynamic>{
            'uid': 'uid-minimal',
            'name': 'Minimal',
            'phone': '+916000000000',
            'createdAt': fixedCreatedAt.toIso8601String(),
            'updatedAt': fixedUpdatedAt.toIso8601String(),
          };

          // Act
          final model = UserModel.fromJson(originalJson);
          final roundTrippedJson = model.toJson();

          // Assert
          expect(roundTrippedJson['uid'], equals('uid-minimal'));
          expect(roundTrippedJson['name'], equals('Minimal'));
          expect(roundTrippedJson['phone'], equals('+916000000000'));
          expect(roundTrippedJson['language'], equals('en'));
          expect(roundTrippedJson['isDeleted'], isFalse);
          expect(roundTrippedJson['fcmTokens'], isEmpty);
        },
      );

      test('should preserve soft-delete fields after round-trip', () {
        // Arrange
        final originalJson = createFullJson(
          isDeleted: true,
          deletedAt: fixedDeletedAt,
          deletedBy: 'admin-uid',
        );

        // Act
        final model = UserModel.fromJson(originalJson);
        final roundTrippedJson = model.toJson();

        // Assert
        expect(roundTrippedJson['isDeleted'], isTrue);
        expect(
          roundTrippedJson['deletedAt'],
          equals(fixedDeletedAt.toIso8601String()),
        );
        expect(roundTrippedJson['deletedBy'], equals('admin-uid'));
      });
    });

    // ── toFirestore ─────────────────────────────────────────────────────

    group('toFirestore', () {
      test('should remove uid field (stored as document ID)', () {
        // Arrange
        final model = createTestModel();

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert
        expect(firestoreMap.containsKey('uid'), isFalse);
      });

      test(
        'should set createdAt and updatedAt to server timestamps when isNew',
        () {
          // Arrange
          final model = createTestModel();

          // Act
          final firestoreMap = model.toFirestore(isNew: true);

          // Assert
          expect(firestoreMap['createdAt'], isA<FieldValue>());
          expect(firestoreMap['updatedAt'], isA<FieldValue>());
        },
      );

      test(
        'should remove createdAt and set updatedAt to server timestamp when not isNew',
        () {
          // Arrange
          final model = createTestModel();

          // Act
          final firestoreMap = model.toFirestore(isNew: false);

          // Assert
          expect(firestoreMap.containsKey('createdAt'), isFalse);
          expect(firestoreMap['updatedAt'], isA<FieldValue>());
        },
      );

      test('should default isNew to false', () {
        // Arrange
        final model = createTestModel();

        // Act
        final firestoreMap = model.toFirestore();

        // Assert
        expect(firestoreMap.containsKey('createdAt'), isFalse);
        expect(firestoreMap['updatedAt'], isA<FieldValue>());
      });

      test('should remove null deletedAt field', () {
        // Arrange
        final model = createTestModel(deletedAt: null);

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert
        expect(firestoreMap.containsKey('deletedAt'), isFalse);
      });

      test('should remove null deletedBy field', () {
        // Arrange
        final model = createTestModel(deletedBy: null);

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert
        expect(firestoreMap.containsKey('deletedBy'), isFalse);
      });

      test('should include deletedAt when not null', () {
        // Arrange
        final model = createTestModel(
          isDeleted: true,
          deletedAt: fixedDeletedAt,
          deletedBy: 'admin',
        );

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert
        expect(firestoreMap.containsKey('deletedAt'), isTrue);
        expect(firestoreMap['deletedBy'], equals('admin'));
      });

      test('should preserve all non-timestamp, non-uid fields', () {
        // Arrange
        final model = createTestModel();

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert
        expect(firestoreMap['name'], equals('Test User'));
        expect(firestoreMap['email'], equals('test@example.com'));
        expect(firestoreMap['phone'], equals('+919876543210'));
        expect(
          firestoreMap['avatarUrl'],
          equals('https://example.com/avatar.png'),
        );
        expect(firestoreMap['language'], equals('en'));
        expect(firestoreMap['fcmTokens'], equals(['token-1', 'token-2']));
        expect(firestoreMap['isDeleted'], isFalse);
      });

      // Regression test: toFirestore(isNew: true) must contain all fields
      // required by Firestore security rules for user creation, and must NOT
      // contain 'uid' (which is the document ID, not a document field).
      // Previously, the rules required 'uid' in the document body, causing
      // every user creation to be PERMISSION_DENIED.
      test('regression: toFirestore(isNew: true) should contain all fields '
          'required by security rules and exclude uid', () {
        // Arrange — the security rules require these fields for create:
        //   hasRequiredFields(['name', 'phone', 'createdAt', 'updatedAt', 'isDeleted'])
        const requiredByRules = [
          'name',
          'phone',
          'createdAt',
          'updatedAt',
          'isDeleted',
        ];
        final model = createTestModel();

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert — all rule-required fields must be present
        for (final field in requiredByRules) {
          expect(
            firestoreMap.containsKey(field),
            isTrue,
            reason:
                'Missing required field "$field" — '
                'Firestore security rules will deny the write',
          );
        }
        // uid must NOT be in the document body (it is the document ID)
        expect(
          firestoreMap.containsKey('uid'),
          isFalse,
          reason:
              'uid should not be a document field — '
              'it is stored as the document ID',
        );
      });

      test('should include notificationPrefs as nested map', () {
        // Arrange
        final model = createTestModel();

        // Act
        final firestoreMap = model.toFirestore(isNew: true);

        // Assert
        expect(firestoreMap['notificationPrefs'], isA<Map<String, dynamic>>());
        final prefs = firestoreMap['notificationPrefs'] as Map<String, dynamic>;
        expect(prefs['expenses'], isTrue);
        expect(prefs['settlements'], isTrue);
        expect(prefs['reminders'], isTrue);
        expect(prefs['weeklyDigest'], isFalse);
      });
    });
  });
}
