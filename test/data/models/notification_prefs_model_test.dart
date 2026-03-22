import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/data/models/notification_prefs_model.dart';

void main() {
  group('NotificationPrefsModel', () {
    // ── Constructor defaults ────────────────────────────────────────────

    group('constructor defaults', () {
      test('should default expenses to true', () {
        const model = NotificationPrefsModel();
        expect(model.expenses, isTrue);
      });

      test('should default settlements to true', () {
        const model = NotificationPrefsModel();
        expect(model.settlements, isTrue);
      });

      test('should default reminders to true', () {
        const model = NotificationPrefsModel();
        expect(model.reminders, isTrue);
      });

      test('should default weeklyDigest to false', () {
        const model = NotificationPrefsModel();
        expect(model.weeklyDigest, isFalse);
      });
    });

    // ── Custom values ───────────────────────────────────────────────────

    group('custom values', () {
      test('should accept all flags as true', () {
        const model = NotificationPrefsModel(
          expenses: true,
          settlements: true,
          reminders: true,
          weeklyDigest: true,
        );

        expect(model.expenses, isTrue);
        expect(model.settlements, isTrue);
        expect(model.reminders, isTrue);
        expect(model.weeklyDigest, isTrue);
      });

      test('should accept all flags as false', () {
        const model = NotificationPrefsModel(
          expenses: false,
          settlements: false,
          reminders: false,
          weeklyDigest: false,
        );

        expect(model.expenses, isFalse);
        expect(model.settlements, isFalse);
        expect(model.reminders, isFalse);
        expect(model.weeklyDigest, isFalse);
      });
    });

    // ── fromJson ────────────────────────────────────────────────────────

    group('fromJson', () {
      test('should parse all fields correctly', () {
        // Arrange
        final json = <String, dynamic>{
          'expenses': false,
          'settlements': false,
          'reminders': false,
          'weeklyDigest': true,
        };

        // Act
        final model = NotificationPrefsModel.fromJson(json);

        // Assert
        expect(model.expenses, isFalse);
        expect(model.settlements, isFalse);
        expect(model.reminders, isFalse);
        expect(model.weeklyDigest, isTrue);
      });

      test('should use defaults for missing fields', () {
        // Arrange
        final json = <String, dynamic>{};

        // Act
        final model = NotificationPrefsModel.fromJson(json);

        // Assert
        expect(model.expenses, isTrue);
        expect(model.settlements, isTrue);
        expect(model.reminders, isTrue);
        expect(model.weeklyDigest, isFalse);
      });

      test('should use default when only some fields are present', () {
        // Arrange
        final json = <String, dynamic>{'expenses': false, 'weeklyDigest': true};

        // Act
        final model = NotificationPrefsModel.fromJson(json);

        // Assert
        expect(model.expenses, isFalse);
        expect(model.settlements, isTrue); // default
        expect(model.reminders, isTrue); // default
        expect(model.weeklyDigest, isTrue);
      });
    });

    // ── toJson ──────────────────────────────────────────────────────────

    group('toJson', () {
      test('should serialize all fields correctly', () {
        // Arrange
        const model = NotificationPrefsModel(
          expenses: false,
          settlements: true,
          reminders: false,
          weeklyDigest: true,
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['expenses'], isFalse);
        expect(json['settlements'], isTrue);
        expect(json['reminders'], isFalse);
        expect(json['weeklyDigest'], isTrue);
      });

      test('should serialize default values correctly', () {
        // Arrange
        const model = NotificationPrefsModel();

        // Act
        final json = model.toJson();

        // Assert
        expect(json['expenses'], isTrue);
        expect(json['settlements'], isTrue);
        expect(json['reminders'], isTrue);
        expect(json['weeklyDigest'], isFalse);
      });

      test('should contain exactly 4 keys', () {
        const model = NotificationPrefsModel();
        final json = model.toJson();

        expect(json.keys.length, equals(4));
        expect(json.containsKey('expenses'), isTrue);
        expect(json.containsKey('settlements'), isTrue);
        expect(json.containsKey('reminders'), isTrue);
        expect(json.containsKey('weeklyDigest'), isTrue);
      });
    });

    // ── JSON round-trip ─────────────────────────────────────────────────

    group('JSON round-trip', () {
      test('should produce identical JSON after round-trip with all true', () {
        // Arrange
        final originalJson = <String, dynamic>{
          'expenses': true,
          'settlements': true,
          'reminders': true,
          'weeklyDigest': true,
        };

        // Act
        final model = NotificationPrefsModel.fromJson(originalJson);
        final roundTrippedJson = model.toJson();

        // Assert
        expect(roundTrippedJson, equals(originalJson));
      });

      test('should produce identical JSON after round-trip with all false', () {
        // Arrange
        final originalJson = <String, dynamic>{
          'expenses': false,
          'settlements': false,
          'reminders': false,
          'weeklyDigest': false,
        };

        // Act
        final model = NotificationPrefsModel.fromJson(originalJson);
        final roundTrippedJson = model.toJson();

        // Assert
        expect(roundTrippedJson, equals(originalJson));
      });

      test('should produce identical JSON after round-trip with defaults', () {
        // Arrange
        const model = NotificationPrefsModel();

        // Act
        final json = model.toJson();
        final roundTripped = NotificationPrefsModel.fromJson(json);

        // Assert
        expect(roundTripped.expenses, equals(model.expenses));
        expect(roundTripped.settlements, equals(model.settlements));
        expect(roundTripped.reminders, equals(model.reminders));
        expect(roundTripped.weeklyDigest, equals(model.weeklyDigest));
      });
    });
  });
}
