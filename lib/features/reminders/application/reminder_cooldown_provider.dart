import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FR-SE-09 per-friendship send-reminder cooldown.
///
/// Holds the server-returned `nextAllowedAt` timestamp from the most
/// recent successful or rate-limited send to a given recipient,
/// keyed by `friendshipId`. The OBTSettleUpCard receiving-direction
/// variant watches this provider to render the disabled-with-
/// countdown state.
///
/// v1.0 architect call (§2.6 of FR-SE-09-send-reminder.md): IN-MEMORY
/// ONLY. The provider RESETS on app launch (ProviderContainer
/// disposal). The server is the authoritative gate per
/// `notifications.md §6.1`; the client provider is a best-effort UX
/// optimisation so the user doesn't tap a button only to be told the
/// reminder was already sent.
///
/// A future PR paired with `shared_preferences` adoption (deferred
/// from PR #53 §2.6) may persist the cooldown across launches.
final reminderCooldownProvider = StateProvider.family<DateTime?, String>(
  (ref, friendshipId) => null,
);
