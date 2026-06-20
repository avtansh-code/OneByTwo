// FR-SE-09 reminderCooldownProvider unit tests.
//
// The cooldown holds an optional DateTime (the server `nextAllowedAt`
// response) per friendshipId. It is now PERSISTED across launches via the
// KeyValueStore seam: build() hydrates the stored value with an expiry
// guard (a past timestamp hydrates as null and the stale key is removed),
// and set() persists. The server remains the authoritative gate
// (FR-SE-09 §2.6); the client value is a best-effort UX optimisation.

// ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/features/reminders/application/reminder_cooldown_provider.dart';

const _friendshipId = 'uid-a_uid-b';
final _future = DateTime.utc(2999, 1, 1, 12);

ProviderContainer _container([KeyValueStore? store]) {
  final container = ProviderContainer(
    overrides: [
      if (store != null) keyValueStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('reminderCooldownProvider — in-session', () {
    test('initial value is null for any friendshipId (empty store)', () {
      final container = _container();
      expect(container.read(reminderCooldownProvider(_friendshipId)), isNull);
    });

    test('set value is held for the same friendshipId', () {
      final container = _container();
      container
          .read(reminderCooldownProvider(_friendshipId).notifier)
          .set(_future);
      expect(
        container.read(reminderCooldownProvider(_friendshipId)),
        equals(_future),
      );
    });

    test('per-friendship isolation — sibling friendshipIds independent', () {
      final container = _container();
      container
          .read(reminderCooldownProvider(_friendshipId).notifier)
          .set(_future);
      expect(container.read(reminderCooldownProvider('uid-c_uid-d')), isNull);
      expect(
        container.read(reminderCooldownProvider(_friendshipId)),
        equals(_future),
      );
    });

    test('set(null) clears the cooldown', () {
      final container = _container();
      final notifier = container.read(
        reminderCooldownProvider(_friendshipId).notifier,
      );
      notifier.set(_future);
      notifier.set(null);
      expect(container.read(reminderCooldownProvider(_friendshipId)), isNull);
    });
  });

  group('reminderCooldownProvider — cross-launch persistence', () {
    test('a future cooldown survives a relaunch (same backing store)', () {
      final store = InMemoryKeyValueStore();

      final c1 = _container(store);
      c1.read(reminderCooldownProvider(_friendshipId).notifier).set(_future);

      // Simulate a relaunch: a fresh container reading the same store.
      final c2 = _container(store);
      expect(c2.read(reminderCooldownProvider(_friendshipId)), equals(_future));
    });

    test('an elapsed cooldown hydrates as null after a relaunch (expiry '
        'guard) and the stale key is removed', () async {
      final store = InMemoryKeyValueStore();
      final key = PreferenceKeys.reminderCooldown(_friendshipId);
      // Seed a clearly-past timestamp directly on the store.
      await store.setString(key, DateTime.utc(2000).toIso8601String());

      final container = _container(store);
      expect(container.read(reminderCooldownProvider(_friendshipId)), isNull);
      // Lazily removed so the stale value does not linger.
      expect(store.getString(key), isNull);
    });

    test('an unparseable stored value hydrates as null', () async {
      final store = InMemoryKeyValueStore();
      await store.setString(
        PreferenceKeys.reminderCooldown(_friendshipId),
        'not-a-date',
      );
      final container = _container(store);
      expect(container.read(reminderCooldownProvider(_friendshipId)), isNull);
    });

    test('independent stores do not share state (no cross-user leak)', () {
      final c1 = _container(InMemoryKeyValueStore())
        ..read(reminderCooldownProvider(_friendshipId).notifier).set(_future);
      // A second container with its OWN store starts clean.
      final c2 = _container(InMemoryKeyValueStore());
      expect(c2.read(reminderCooldownProvider(_friendshipId)), isNull);
      // c1 still holds its value (sanity).
      expect(c1.read(reminderCooldownProvider(_friendshipId)), equals(_future));
    });
  });
}
