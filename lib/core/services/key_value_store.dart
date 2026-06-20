import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, synchronously-readable abstraction over `shared_preferences`.
///
/// The production implementation ([SharedPreferencesKeyValueStore]) wraps
/// an **already-loaded** [SharedPreferences] instance, so reads are
/// synchronous and safe to call from a sync `Notifier.build()`. The
/// instance is loaded once in `main()` (after `Firebase.initializeApp()`,
/// before `runApp`) and injected via a [ProviderScope] override of
/// [keyValueStoreProvider] — the established post-`await`, pre-`runApp`
/// bootstrap pattern (mirroring Remote Config).
///
/// Features bind to this seam and never call `shared_preferences`
/// directly, so the platform channel (unavailable in `flutter test`) is
/// replaced by an [InMemoryKeyValueStore] in tests. Mirrors the
/// `UrlLauncherService` / `AppSettingsService` shim pattern under
/// `lib/core/services/`.
///
/// This is on-device storage only — not sharing (Invariant 3 N/A) and
/// not a second Firebase project (Invariant 4 reinforced). Keys are
/// declared in `lib/core/persistence/preference_keys.dart`.
abstract class KeyValueStore {
  /// The stored boolean for [key], or `null` if absent.
  bool? getBool(String key);

  /// Persists [value] under [key].
  Future<void> setBool(String key, {required bool value});

  /// The stored string for [key], or `null` if absent.
  String? getString(String key);

  /// Persists [value] under [key].
  Future<void> setString(String key, String value);

  /// Removes any value stored under [key].
  Future<void> remove(String key);
}

/// Production [KeyValueStore] backed by an already-loaded
/// [SharedPreferences] instance.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  /// Creates a store over the already-loaded `SharedPreferences`
  /// instance.
  const SharedPreferencesKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// In-memory [KeyValueStore]. Used as the safe default (production
/// always overrides [keyValueStoreProvider] with a
/// [SharedPreferencesKeyValueStore]) and as the fake injected by tests.
///
/// Persistence degrades to session-only when this default is used — the
/// same behaviour the app had before `shared_preferences` was adopted.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _store = <String, Object>{};

  @override
  bool? getBool(String key) {
    final value = _store[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> setBool(String key, {required bool value}) async {
    _store[key] = value;
  }

  @override
  String? getString(String key) {
    final value = _store[key];
    return value is String ? value : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}

/// Provides the app-wide [KeyValueStore].
///
/// Defaults to an [InMemoryKeyValueStore] so tests and any un-wired
/// context never touch the platform channel. `main()` overrides this
/// with a [SharedPreferencesKeyValueStore] over the loaded
/// [SharedPreferences] instance, which is what gives cross-launch
/// persistence in production.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => InMemoryKeyValueStore(),
);
