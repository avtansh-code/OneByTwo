// FR-SE-09 reminderCooldownProvider unit tests.
//
// The cooldown provider holds an optional `DateTime` (the
// `nextAllowedAt` server response) per friendshipId. v1.0 is in-
// memory only — the provider RESETS on app launch (provider container
// disposal) per architect §2.6 of FR-SE-09-send-reminder.md. The
// server is the authoritative gate.

// ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/reminders/application/reminder_cooldown_provider.dart';

void main() {
  group('reminderCooldownProvider', () {
    test('initial value is null for any friendshipId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(reminderCooldownProvider('uid-a_uid-b')), isNull);
    });

    test('set value is held for the same friendshipId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final next = DateTime.utc(2026, 6, 9, 12);
      container.read(reminderCooldownProvider('uid-a_uid-b').notifier).state =
          next;
      expect(
        container.read(reminderCooldownProvider('uid-a_uid-b')),
        equals(next),
      );
    });

    test('per-friendship isolation — sibling friendshipIds independent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final t1 = DateTime.utc(2026, 6, 9, 12);
      container.read(reminderCooldownProvider('uid-a_uid-b').notifier).state =
          t1;
      expect(container.read(reminderCooldownProvider('uid-c_uid-d')), isNull);
      expect(
        container.read(reminderCooldownProvider('uid-a_uid-b')),
        equals(t1),
      );
    });

    test('resets to null when the container is disposed and re-created '
        '(in-memory only)', () {
      final container1 = ProviderContainer();
      container1.read(reminderCooldownProvider('uid-a_uid-b').notifier).state =
          DateTime.utc(2026, 6, 9, 12);
      container1.dispose();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      expect(container2.read(reminderCooldownProvider('uid-a_uid-b')), isNull);
    });
  });
}
