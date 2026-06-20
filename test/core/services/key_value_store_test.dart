// Smoke + behaviour test for the KeyValueStore seam.
//
// Verifies the abstract type, the in-memory default, the Riverpod
// provider wiring, and the InMemoryKeyValueStore round-trips. Mirrors
// app_settings_service_test.dart.
//
// SharedPreferencesKeyValueStore is not exercised end-to-end here because
// that would require the shared_preferences platform channel. main()
// injects it in production; tests inject an InMemoryKeyValueStore via a
// Riverpod override.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/services/key_value_store.dart';

void main() {
  group('keyValueStoreProvider', () {
    test('resolves to an InMemoryKeyValueStore by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store = container.read(keyValueStoreProvider);
      expect(store, isA<KeyValueStore>());
      expect(store, isA<InMemoryKeyValueStore>());
    });

    test('can be overridden with a fake for tests', () {
      final fake = InMemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(keyValueStoreProvider), same(fake));
    });
  });

  group('InMemoryKeyValueStore', () {
    test('getBool returns null when absent, the set value otherwise', () async {
      final store = InMemoryKeyValueStore();
      expect(store.getBool('flag'), isNull);

      await store.setBool('flag', value: true);
      expect(store.getBool('flag'), isTrue);

      await store.setBool('flag', value: false);
      expect(store.getBool('flag'), isFalse);
    });

    test(
      'getString returns null when absent, the set value otherwise',
      () async {
        final store = InMemoryKeyValueStore();
        expect(store.getString('key'), isNull);

        await store.setString('key', 'value');
        expect(store.getString('key'), 'value');
      },
    );

    test('remove deletes a stored value', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('key', 'value');

      await store.remove('key');
      expect(store.getString('key'), isNull);
    });
  });
}
