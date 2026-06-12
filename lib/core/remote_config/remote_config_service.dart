import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/remote_config/remote_config_keys.dart';

/// Abstraction over Firebase Remote Config for testability.
///
/// This is the app's first Remote Config consumer (ADR-0006); the
/// read-with-compiled-in-default pattern established here is reused by
/// future feature-flag and remote-configuration work. Tests override
/// [remoteConfigServiceProvider] with a fake so no Firebase platform
/// channel is touched.
abstract class RemoteConfigService {
  /// Registers compiled-in defaults and kicks off a non-blocking fetch.
  ///
  /// Must be awaited at app start (it only awaits the local, fast
  /// `setDefaults`); the network fetch is fire-and-forget so the first
  /// frame never blocks on it.
  Future<void> initialise();

  /// Returns the string value for [key], guarded so an empty or missing
  /// remote value falls back to the compiled-in default
  /// (see [RemoteConfigDefaults.resolve]).
  String getString(String key);
}

/// Production [RemoteConfigService] backed by [FirebaseRemoteConfig].
class FirebaseRemoteConfigService implements RemoteConfigService {
  /// Creates a [FirebaseRemoteConfigService] wrapping [_remoteConfig].
  FirebaseRemoteConfigService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<void> initialise() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _remoteConfig.setDefaults(RemoteConfigDefaults.values);
    // Fire-and-forget: the first frame must not block on a network
    // fetch. The read path returns the compiled-in default until the
    // background fetch activates the server value.
    unawaited(_remoteConfig.fetchAndActivate());
  }

  @override
  String getString(String key) {
    return RemoteConfigDefaults.resolve(key, _remoteConfig.getString(key));
  }
}

/// Provides the app-wide [RemoteConfigService].
///
/// Overridden in `main.dart` with an initialised
/// [FirebaseRemoteConfigService]; overridden in tests with a fake.
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return FirebaseRemoteConfigService(FirebaseRemoteConfig.instance);
});
