import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot connectivity check used by client features that need to
/// react to "offline" without subscribing to a continuous stream.
///
/// Returns `true` when the device is reachable via at least one
/// non-`none` connectivity transport (WiFi / mobile / ethernet / vpn /
/// bluetooth). Returns `false` when every reported transport is
/// `none`. Falls back to `true` (assume online) if the underlying
/// platform channel throws — tests that need explicit offline
/// behaviour override [connectivityCheckProvider].
typedef IsOnline = Future<bool> Function();

/// Provides an [IsOnline] check backed by `connectivity_plus`.
///
/// Production usage: features call
/// `await ref.read(connectivityCheckProvider)()` to detect offline
/// state at a specific moment (e.g. when a user taps
/// a toggle that triggers a Firestore write). Tests override the
/// provider with a fixed-return fake — this avoids any
/// `connectivity_plus` platform-channel calls in the test environment.
///
/// The default implementation swallows platform-channel exceptions
/// (which fire in unit tests without a `Connectivity` mock) and
/// returns `true`. This means tests that don't care about connectivity
/// don't need to do anything; tests that specifically exercise the
/// offline path override the provider.
final connectivityCheckProvider = Provider<IsOnline>((ref) {
  final connectivity = Connectivity();
  return () async {
    try {
      final results = await connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } on Exception {
      return true;
    }
  };
});
