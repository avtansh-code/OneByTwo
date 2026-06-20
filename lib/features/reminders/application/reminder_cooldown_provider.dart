import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';

/// FR-SE-09 per-friendship send-reminder cooldown.
///
/// Holds the server-returned `nextAllowedAt` timestamp from the most
/// recent successful or rate-limited send to a given recipient, keyed by
/// `friendshipId`. The OBTSettleUpCard receiving-direction variant
/// watches this provider to render the disabled-with-countdown state.
///
/// **Cross-launch persistence (FR-SE-09 §2.6 reversal).** The value is
/// persisted on-device through the [KeyValueStore] seam
/// (`shared_preferences` under the hood), so a 24-hour cooldown is still
/// honoured after an app restart. [build] hydrates the stored value and
/// applies an **expiry guard**: a persisted `nextAllowedAt` already in
/// the past hydrates as `null` (and the stale key is lazily removed) so a
/// long-closed app never shows a phantom countdown. The server
/// (`notifications.md §6.1`) remains the authoritative gate; the
/// persisted client value is a best-effort UX optimisation, so writes are
/// fire-and-forget.
class ReminderCooldownNotifier extends FamilyNotifier<DateTime?, String> {
  @override
  DateTime? build(String friendshipId) {
    final store = ref.read(keyValueStoreProvider);
    final key = PreferenceKeys.reminderCooldown(friendshipId);
    final raw = store.getString(key);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || !parsed.isAfter(DateTime.now())) {
      // Absent, unparseable, or already elapsed — never disable the
      // button on a stale value; drop the key so it does not linger.
      unawaited(store.remove(key));
      return null;
    }
    return parsed;
  }

  /// Records [value] as the new cooldown and persists it (or clears the
  /// stored key when `null`). Called by the send-reminder controller on a
  /// successful or rate-limited send. Unlike [build], no expiry filter is
  /// applied here — the value is fresh from the server and the live
  /// countdown UI handles an already-elapsed timestamp.
  void set(DateTime? value) {
    final store = ref.read(keyValueStoreProvider);
    final key = PreferenceKeys.reminderCooldown(arg);
    if (value == null) {
      unawaited(store.remove(key));
    } else {
      unawaited(store.setString(key, value.toIso8601String()));
    }
    state = value;
  }
}

/// Provides the per-friendship [ReminderCooldownNotifier].
final reminderCooldownProvider =
    NotifierProvider.family<ReminderCooldownNotifier, DateTime?, String>(
      ReminderCooldownNotifier.new,
    );
