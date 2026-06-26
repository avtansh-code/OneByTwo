// Onboarding provider tests (DC-04).
//
// Unit tests for hasSeenOnboardingProvider: it hydrates synchronously from
// the KeyValueStore seam and markSeen() persists the flag then flips state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/features/auth/application/onboarding_provider.dart';

void main() {
  group('hasSeenOnboardingProvider', () {
    test('defaults to false when the flag is absent', () {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(hasSeenOnboardingProvider), isFalse);
    });

    test('hydrates true when the flag is already set', () async {
      final store = InMemoryKeyValueStore();
      await store.setBool(PreferenceKeys.hasSeenOnboarding, value: true);
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(hasSeenOnboardingProvider), isTrue);
    });

    test('markSeen persists the flag and flips state', () async {
      final store = InMemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(container.read(hasSeenOnboardingProvider), isFalse);

      await container.read(hasSeenOnboardingProvider.notifier).markSeen();

      expect(container.read(hasSeenOnboardingProvider), isTrue);
      expect(store.getBool(PreferenceKeys.hasSeenOnboarding), isTrue);
    });

    test('markSeen is idempotent once already seen', () async {
      final store = InMemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(hasSeenOnboardingProvider.notifier);

      await notifier.markSeen();
      await notifier.markSeen();

      expect(container.read(hasSeenOnboardingProvider), isTrue);
      expect(store.getBool(PreferenceKeys.hasSeenOnboarding), isTrue);
    });
  });
}
