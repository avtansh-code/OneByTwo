# Reminders

Feature-folder that owns the client side of FR-SE-09 **Send Reminder**:
the "nudge a friend who owes you" action and its per-friendship cooldown.
The reminder itself is dispatched by the `sendReminderNotification`
Cloud Function (region `asia-south1`); this feature invokes that
callable, maps its typed result, and drives the button state.

This feature has **no `presentation/` folder** — its only UI surface is
the receiving-direction variant of the shared `OBTSettleUpCard`, hosted
by the friends feature (see Hand-off boundaries).

## Implemented scope

### Domain — typed result union

- `domain/reminder_send_error.dart` — `ReminderSendResult`, a sealed
  class with five error variants: `ReminderSendRateLimited` (carries the
  server `nextAllowedAt`), `ReminderSendRecipientDoesntOwe`,
  `ReminderSendRecipientPrefsDisabled`, `ReminderSendRecipientNoTokens`,
  and the catch-all `ReminderSendFailed`. `ReminderSendFailed.errorCode`
  holds the server-side `details.errorCode` (e.g. `INTERNAL`,
  `FCM_DISPATCH_FAILED`, `GROUP_CONTEXT_NOT_SUPPORTED`) or `'UNKNOWN'`
  for opaque non-callable failures.
- `domain/reminder_send_success.dart` — `ReminderSendSuccess`
  (`part of reminder_send_error.dart`), the sixth variant, carrying the
  server-computed `nextAllowedAt` (24 h after a successful send per
  SRS §4.6).

### Data — callable repository

- `data/reminder_repository.dart` — the `ReminderRepository` factory
  surface (`ReminderRepositoryImpl`), the `ReminderCallable` typedef, the
  `ReminderCallableException`, and `reminderRepositoryProvider`
  (`Provider<ReminderRepository>`). The repository consumes the
  `ReminderCallable` typedef directly so it is unit-testable without
  `cloud_functions`.
- `data/reminder_callable_adapter.dart` — `ReminderCallableAdapter`, the
  **only** file that imports `package:cloud_functions`. It bridges the
  `sendReminderNotification` `HttpsCallable` to the in-codebase typedef
  and translates `FirebaseFunctionsException` (with `details.errorCode`
  / `details.nextAllowedAtIso`) into `ReminderCallableException`. It is
  constructed and injected in `lib/main.dart`.

### Application — controller, cooldown, telemetry

- `application/send_reminder_controller.dart` — the sealed
  `SendReminderState` (`SendReminderIdle` / `SendReminderSending` /
  `SendReminderSuccess` / `SendReminderError`) and
  `SendReminderController` (a `StateNotifier`), exposed as
  `sendReminderControllerProvider`
  (`StateNotifierProvider.autoDispose.family<…, String>` keyed by
  `friendshipId`, so two Friend Detail screens never stomp on each
  other's send state). On success / `RATE_LIMITED` it writes the
  `nextAllowedAt` into the cooldown provider and emits the matching
  `reminder_send_*` telemetry.
- `application/reminder_cooldown_provider.dart` —
  `reminderCooldownProvider`
  (`NotifierProvider.family<ReminderCooldownNotifier, DateTime?, String>`).
  Holds the per-friendship `nextAllowedAt` so the button can render a
  disabled-with-countdown state. **Persisted across launches** via the
  `KeyValueStore` seam (`shared_preferences`): `build()` hydrates the
  stored value with an expiry guard (a past `nextAllowedAt` hydrates as
  `null` and the stale key is removed) and `set()` persists. The server
  remains the authoritative gate; the client value is a best-effort UX
  optimisation, so its writes are fire-and-forget.
- `application/reminder_telemetry.dart` — `ReminderTelemetry`, the
  event-name and parameter-key constants for the seven client events
  (`reminder_send_tapped`, `reminder_send_succeeded`,
  `reminder_send_rate_limited`, `reminder_send_recipient_prefs_disabled`,
  `reminder_send_recipient_no_tokens`, `reminder_send_recipient_doesnt_owe`,
  `reminder_send_failed`). Every payload carries a hashed
  `friendship_id_hash`.

## Layout

```
application/
  reminder_cooldown_provider.dart   # StateProvider.family<DateTime?, String> (per-friendship)
  reminder_telemetry.dart           # ReminderTelemetry event/param constants
  send_reminder_controller.dart     # sealed SendReminderState + StateNotifier + provider
data/
  reminder_callable_adapter.dart    # cloud_functions bridge (only import site)
  reminder_repository.dart          # ReminderRepository + ReminderCallable + provider
domain/
  reminder_send_error.dart          # ReminderSendResult sealed class + 5 error variants
  reminder_send_success.dart        # ReminderSendSuccess (part of error file)
```

## Invariants honoured

- **Invariant 1 (integer paise):** the controller is keyed only by
  `friendshipId` and handles no monetary values; the suggested amount
  shown on the card is owned by the host (`OBTSettleUpCard`, which
  formats via `formatInrFromPaise`).
- **Invariant 2 (`simplifiedBalances` server-maintained):** this feature
  never reads or writes the field. The server re-checks the debt
  direction and returns `RECIPIENT_DOESNT_OWE` if balances drifted
  between render and tap.
- **Invariant 3 (system share sheet only):** N/A.
- **Invariant 4 (single Firebase project):** the callable is hidden
  behind the `ReminderCallable` typedef; only `main.dart` constructs the
  `cloud_functions`-backed adapter, so tests inject a fake callable with
  no Firebase initialisation.

## Hand-off boundaries

- **In (host UI):** the only call site is the receiving-direction
  variant of `OBTSettleUpCard`, hosted by `_ReceivingDirectionCard` in
  `lib/features/friends/presentation/friend_detail_screen.dart`. That
  widget watches `reminderCooldownProvider` and listens to
  `sendReminderControllerProvider` to surface per-error-code snackbars.
- **In (DI):** `lib/main.dart` overrides `reminderRepositoryProvider`
  with a `ReminderRepository` backed by `ReminderCallableAdapter`.
- **Out (write + gate):** the `sendReminderNotification` Cloud Function
  is the authoritative 24 h rate-limit gate, recipient-preference check,
  and FCM sender; the client cooldown is a best-effort UX optimisation.
