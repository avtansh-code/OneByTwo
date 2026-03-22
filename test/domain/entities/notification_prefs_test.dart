import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';

void main() {
  group('NotificationPrefs entity', () {
    // ── Default values ──────────────────────────────────────────────────

    group('default values', () {
      test('should default expenses to true', () {
        const prefs = NotificationPrefs();
        expect(prefs.expenses, isTrue);
      });

      test('should default settlements to true', () {
        const prefs = NotificationPrefs();
        expect(prefs.settlements, isTrue);
      });

      test('should default reminders to true', () {
        const prefs = NotificationPrefs();
        expect(prefs.reminders, isTrue);
      });

      test('should default weeklyDigest to false', () {
        const prefs = NotificationPrefs();
        expect(prefs.weeklyDigest, isFalse);
      });
    });

    // ── Custom values ───────────────────────────────────────────────────

    group('custom values', () {
      test('should accept all flags set to true', () {
        const prefs = NotificationPrefs(
          expenses: true,
          settlements: true,
          reminders: true,
          weeklyDigest: true,
        );

        expect(prefs.expenses, isTrue);
        expect(prefs.settlements, isTrue);
        expect(prefs.reminders, isTrue);
        expect(prefs.weeklyDigest, isTrue);
      });

      test('should accept all flags set to false', () {
        const prefs = NotificationPrefs(
          expenses: false,
          settlements: false,
          reminders: false,
          weeklyDigest: false,
        );

        expect(prefs.expenses, isFalse);
        expect(prefs.settlements, isFalse);
        expect(prefs.reminders, isFalse);
        expect(prefs.weeklyDigest, isFalse);
      });

      test('should accept mixed flags', () {
        const prefs = NotificationPrefs(
          expenses: true,
          settlements: false,
          reminders: true,
          weeklyDigest: true,
        );

        expect(prefs.expenses, isTrue);
        expect(prefs.settlements, isFalse);
        expect(prefs.reminders, isTrue);
        expect(prefs.weeklyDigest, isTrue);
      });
    });

    // ── copyWith ────────────────────────────────────────────────────────

    group('copyWith', () {
      test('should create new instance with changed expenses', () {
        const original = NotificationPrefs();
        final updated = original.copyWith(expenses: false);

        expect(updated.expenses, isFalse);
        expect(original.expenses, isTrue);
      });

      test('should preserve unchanged fields', () {
        const original = NotificationPrefs(
          expenses: true,
          settlements: false,
          reminders: true,
          weeklyDigest: true,
        );
        final updated = original.copyWith(expenses: false);

        expect(updated.settlements, equals(original.settlements));
        expect(updated.reminders, equals(original.reminders));
        expect(updated.weeklyDigest, equals(original.weeklyDigest));
      });

      test('should update weeklyDigest', () {
        const prefs = NotificationPrefs();
        final updated = prefs.copyWith(weeklyDigest: true);

        expect(updated.weeklyDigest, isTrue);
      });

      test('should update multiple fields at once', () {
        const prefs = NotificationPrefs();
        final updated = prefs.copyWith(
          expenses: false,
          reminders: false,
          weeklyDigest: true,
        );

        expect(updated.expenses, isFalse);
        expect(updated.settlements, isTrue); // unchanged
        expect(updated.reminders, isFalse);
        expect(updated.weeklyDigest, isTrue);
      });
    });

    // ── Equality ────────────────────────────────────────────────────────

    group('equality', () {
      test('should be equal when all fields match', () {
        const prefs1 = NotificationPrefs();
        const prefs2 = NotificationPrefs();

        expect(prefs1, equals(prefs2));
        expect(prefs1.hashCode, equals(prefs2.hashCode));
      });

      test('should be equal with explicit default values', () {
        const prefs1 = NotificationPrefs();
        const prefs2 = NotificationPrefs(
          expenses: true,
          settlements: true,
          reminders: true,
          weeklyDigest: false,
        );

        expect(prefs1, equals(prefs2));
      });

      test('should not be equal when expenses differs', () {
        const prefs1 = NotificationPrefs(expenses: true);
        const prefs2 = NotificationPrefs(expenses: false);

        expect(prefs1, isNot(equals(prefs2)));
      });

      test('should not be equal when settlements differs', () {
        const prefs1 = NotificationPrefs(settlements: true);
        const prefs2 = NotificationPrefs(settlements: false);

        expect(prefs1, isNot(equals(prefs2)));
      });

      test('should not be equal when reminders differs', () {
        const prefs1 = NotificationPrefs(reminders: true);
        const prefs2 = NotificationPrefs(reminders: false);

        expect(prefs1, isNot(equals(prefs2)));
      });

      test('should not be equal when weeklyDigest differs', () {
        const prefs1 = NotificationPrefs(weeklyDigest: false);
        const prefs2 = NotificationPrefs(weeklyDigest: true);

        expect(prefs1, isNot(equals(prefs2)));
      });

      test('identical instance should be equal to itself', () {
        const prefs = NotificationPrefs();
        expect(prefs, equals(prefs));
      });
    });
  });
}
