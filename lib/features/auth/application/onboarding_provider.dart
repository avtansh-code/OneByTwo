import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';

/// Tracks whether the first-launch onboarding (Haldi 2) has been seen on
/// this installation (DC-04).
///
/// Hydrated synchronously from the [KeyValueStore] seam at construction —
/// the same post-`await`, sync-read pattern as
/// `NotificationPermissionController` — so the auth gate (`OneBytwoApp`)
/// can read it without an async gap. [markSeen] persists the flag before
/// flipping [state], so the cross-launch "show once" semantic survives an
/// immediate process kill; flipping the state rebuilds the gate, which
/// advances from onboarding to phone entry.
///
/// This is on-device persistence only — not a second Firebase project
/// (Invariant 4 reinforced) and not sharing (Invariant 3 N/A).
class HasSeenOnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .read(keyValueStoreProvider)
            .getBool(PreferenceKeys.hasSeenOnboarding) ??
        false;
  }

  /// Persists the "seen onboarding" flag and flips [state] to `true`.
  ///
  /// Idempotent: a no-op once already seen. Called by both Skip and
  /// "Get started" on the onboarding screen.
  Future<void> markSeen() async {
    if (state) return;
    await ref
        .read(keyValueStoreProvider)
        .setBool(PreferenceKeys.hasSeenOnboarding, value: true);
    state = true;
  }
}

/// Provides the [HasSeenOnboardingNotifier]. Defaults to `false` (onboarding
/// not yet seen) until the persisted flag is read.
final hasSeenOnboardingProvider =
    NotifierProvider<HasSeenOnboardingNotifier, bool>(
      HasSeenOnboardingNotifier.new,
    );
