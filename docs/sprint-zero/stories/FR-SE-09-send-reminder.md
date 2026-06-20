# FR-SE-09: Send Reminder

> Implementation-ready user story for the **first callable Cloud
> Function that composes the FR-AC-03 FCM module surface** with the
> simplified-balances precondition + per-friend 24-hour rate-limit
> gate. Ships the `sendReminderNotification` callable
> (`functions/src/send-reminder-notification/` — mirror of
> `lookup-user-by-phone-number/`), the new
> `notifications/send-reminder-notification.ts` helper that mirrors
> the existing `send-expense-notification.ts` /
> `send-settlement-notification.ts` helpers and is exposed through
> the public `NotificationsApi` surface, the
> `_rateLimits/{senderUid}/sends/{recipientUid}` 5-segment
> subcollection extension of the architect-canonical `_rateLimits/`
> container, the `'reminder'` event-type extension to the existing
> `activity-validator.ts` + `writeExpenseActivity` writer (the
> misnamed-but-canonical writer), a new `lib/features/reminders/`
> client feature folder (repository + domain + send controller +
> in-memory cooldown provider), the receiving-direction variant of
> `OBTSettleUpCard` (with `isReceivingDirection` /
> `onSendReminder` / `nextAllowedAt` parameters), and the
> `FriendDetailScreen` wiring on the `BalanceState.owed` branch.

---

## SRS Requirement ID(s)

FR-SE-09 (SRS section 4.6 — "The app shall allow a user to send a
free-text reminder push notification to a friend who owes them money,
rate-limited to one reminder per friend per 24 hours"; P1). The story
also exercises the read side of FR-AC-04
(`notificationPrefs.reminder` is consulted as the prefs-filter gate
for the FCM dispatch leaf; the FR-PR-03 / FR-AC-04 user-facing
preferences UI ships in a separate PR).

## Relevant SRS Sections

- Section 4.6 — Settlements (FR-SE-09 row: send-reminder action;
  per-friend 24h rate-limit). The story IS the producer for this row.
- Section 4.7 — Activity Feed and Notifications (FR-AC-03 FCM
  consumer surface used by the dispatch leaf; FR-AC-04
  notification-preferences server-side consumption via the
  `prefs-filter.ts` reminder short-circuit; a new `'reminder'`
  activity-feed event-type extension on the existing writer).
- Section 5.10 — Observability (seven new server structured-log
  events + seven mirrored client analytics events; PII hashing via
  `hashId()` server / `hashFriendshipId()` client per ADR-0013).
- Section 7.3 — Invariant 1 (paise integer carry-through path on
  `amountPaise` from `simplifiedBalances[recipientUid][senderUid]`
  → `renderPayload('reminder', ...)` → FCM data envelope; zero
  inline `/100` on any new code path).
- Section 7.5 — Security rules (existing
  `match /_rateLimits/{document=**}` deny-all block at
  `firestore.rules:355` already covers the new 5-segment per-recipient
  variant; no rules diff in this story).

## Priority

**P1.** SRS section 4.6 row FR-SE-09 is P1. PR #53 (FR-AC-03) already
shipped the renderer template + the prefs-filter short-circuit as
forward-compat for this story; FR-SE-09 is the natural first
downstream consumer of that module surface.

## Story Points

**6.** Decomposes as:

- 3 SP — server callable
  (`functions/src/send-reminder-notification/{index,function}.ts`
  with auth + input validation + membership check +
  simplifiedBalances precondition + rate-limit pre-check + prefs
  filter + FCM dispatch + rate-limit write + activity emission +
  typed `HttpsError` codes), the FCM dispatch helper
  (`functions/src/notifications/send-reminder-notification.ts`
  mirror of the existing two helpers; exposed via `NotificationsApi`),
  the `notifications/index.ts` re-export + `notifications/types.ts`
  extension (`SendReminderNotificationParams` interface), and the
  `activity-validator.ts` extension for the new `'reminder'` event
  type discriminator + `ReminderPayload` shape.
- 2 SP — client `lib/features/reminders/` feature folder
  (`data/reminder_repository.dart` callable wrapper,
  `domain/{reminder_send_error,reminder_send_success}.dart` typed
  result hierarchy, `application/send_reminder_controller.dart`
  Riverpod `Notifier<SendReminderState>` driving the in-progress /
  success / error states with telemetry, and
  `application/reminder_cooldown_provider.dart`
  `StateProvider.family<DateTime?, String>` for the optimistic
  in-memory cooldown).
- 1 SP — `OBTSettleUpCard` receiving-direction variant
  (`isReceivingDirection: bool`, `onSendReminder: VoidCallback?`,
  `nextAllowedAt: DateTime?` parameters; existing settling-direction
  call site unaffected) and `FriendDetailScreen.BalanceState.owed`
  branch wiring (renders the receiving-direction card, wires
  `_onSendReminderTapped` into the controller, surfaces error
  snackbars per typed error variant).

Patterns reused without re-derivation:

- `functions/src/lookup-user-by-phone-number/` is the symmetric
  callable blueprint (handler factory with injected `db` + `logger`;
  `HttpsError` with `errorCode` in `details`; rate-limit document
  read-modify-write; `region: REGION` pinning).
- `functions/src/notifications/send-settlement-notification.ts` is
  the FCM-helper blueprint (single recipient; prefs-filter +
  token-read + `sendFcmToTokens` composition; structured-log
  contract).
- `functions/src/triggers/on-expense-write/activity-writer.ts` +
  `activity-validator.ts` are the activity-emission blueprint (per-
  member fan-out; the new `'reminder'` event-type extends both).
- `lib/features/friends/data/matching_repository.dart` is the
  callable-wrapper blueprint (`CloudFunctionException` →
  discriminated result hierarchy).
- `lib/features/settlements/application/settle_up_telemetry.dart`
  is the client telemetry-constants blueprint (one final-class
  abstract with `static const` event names + parameter keys).
- `lib/features/friends/presentation/widgets/obt_settle_up_card.dart`
  is the host widget that gains the receiving-direction variant in
  place (no extraction to `lib/core/widgets/cards/` — the cosmetic
  split is deferred until a second host needs it, per the
  `OBTAmountInput` precedent).

## User Story

As a **signed-in user with a friend who owes me money**,
I want **a "Send Reminder" call-to-action on the Friend Detail screen
that sends a push notification to my friend asking them to settle up,
rate-limited to one reminder per friend per 24 hours**,
so that **I can nudge them to settle without leaving the app or
sending a manual WhatsApp/SMS message**.

## Acceptance Criteria

> 22 ACs. Mirrors the FR-AC-03 cadence (positive callable contract +
> per-error-code negative branches + client UX branches + cross-
> cutting invariant guards).

### Callable contract — positive

**AC-1 — Authenticated caller sends a reminder; rate-limit doc is
written.** Given an authenticated user A who is a member of friendship
F (`memberIds = [A, B]`) with friend B, and B owes A per
`simplifiedBalances[B][A] > 0`, and B has
`notificationPrefs.reminder == true` and non-empty
`users/B.fcmTokens`, when A calls
`sendReminderNotification({ toUserId: 'B', contextType: 'friendship',
contextId: F })`, then the function returns
`{ success: true, nextAllowedAtIso: <now+24h>.toISOString() }`, AND a
document at `_rateLimits/A/sends/B` is written with
`{ lastSentAt: Timestamp, count: 1, windowStart: number,
recipientUid: 'B', senderUid: 'A', updatedAt: Timestamp }`, AND ONE
FCM message per token in `users/B.fcmTokens` is dispatched with the
rendered `reminder` payload (`type: 'reminder'`, `title: 'Reminder
from {A.displayName}'`, body `{A.displayName} is nudging you about
₹{amount}.`).

**AC-2 — Activity item is emitted to recipient.** Given the AC-1
success path, then an activity-feed document is written to
`activity/B/items/{auto-id}` with `type: 'reminder'` and a payload
containing `{ senderUid, recipientUid, contextType, contextId,
amountPaise }` sufficient for the SCR-25 row renderer to identify
the reminder and deep-link to the friendship. (Recipient-only
emission per architect §2.3 — the sender's confirmation is the
optimistic-disable button state, not an activity row.)

### Callable contract — negative (error codes)

**AC-3 — Unauthenticated caller is rejected.** Given a call without
`request.auth`, when the callable runs, then it throws
`HttpsError('unauthenticated', ...)` with
`details.errorCode === 'UNAUTHENTICATED'`. No rate-limit doc written;
no FCM dispatch; no activity emission.

**AC-4 — Malformed input is rejected.** Given a call with any of:
missing `toUserId`, empty-string `toUserId`, missing `contextId`,
empty-string `contextId`, `contextType ∉ {friendship, group}`, or
`message` length > 500 characters, when the callable runs, then it
throws `HttpsError('invalid-argument', ...)` with
`details.errorCode === 'INVALID_INPUT'`. No rate-limit doc written;
no FCM dispatch; no activity emission.

**AC-5 — Non-member caller is rejected.** Given a call from user A
where `A ∉ memberIds` on the parent context, when the callable runs,
then it throws `HttpsError('permission-denied', ...)` with
`details.errorCode === 'NOT_A_MEMBER'`. No rate-limit doc written;
no FCM dispatch; no activity emission.

**AC-6 — Recipient-doesn't-owe is rejected.** Given a call where
`simplifiedBalances[recipientUid]?.[senderUid]` is `undefined`, `0`,
or negative (the recipient doesn't owe the sender — sender is owed
by no-one in that direction or is themselves the debtor), when the
callable runs, then it throws `HttpsError('failed-precondition',
...)` with `details.errorCode === 'RECIPIENT_DOESNT_OWE'`. No
rate-limit doc written; no FCM dispatch; no activity emission.

**AC-7 — Rate-limit pre-check rejects within the 24h window.** Given
a prior rate-limit doc at `_rateLimits/A/sends/B` with `lastSentAt =
now - 12h`, when A calls the callable again with the same
`recipientUid`, then it throws `HttpsError('resource-exhausted',
...)` with `details.errorCode === 'RATE_LIMITED'` AND
`details.nextAllowedAtIso === (lastSentAt + 24h).toISOString()`. No
FCM dispatch; no new rate-limit write.

**AC-8 — Rate-limit pre-check passes after the 24h window expires.**
Given a prior rate-limit doc at `_rateLimits/A/sends/B` with
`lastSentAt = now - 25h`, when A calls the callable again with the
same `recipientUid`, then the call succeeds (per AC-1 contract) and
the rate-limit doc is rewritten with the new `lastSentAt` (the
`count` field is incremented).

**AC-9 — Prefs filter rejects when recipient has reminder=false.**
Given recipient B's `notificationPrefs.reminder === false`, when the
callable runs, then it throws `HttpsError('failed-precondition',
...)` with `details.errorCode === 'RECIPIENT_PREFS_DISABLED'`. No
FCM dispatch; no rate-limit doc written; no activity emission.

**AC-10 — Empty fcmTokens rejection.** Given recipient B's
`users/B.fcmTokens` is missing or empty, when the callable runs,
then it throws `HttpsError('failed-precondition', ...)` with
`details.errorCode === 'RECIPIENT_NO_TOKENS'`. No rate-limit doc
written (the recipient has not granted push permission — allowing
the rate-limit would silently consume the sender's quota for a no-op
send); no activity emission.

**AC-11 — Rate-limit doc NOT written when all FCM sends fail.**
Given all of B's `fcmTokens` are pruned by the FCM admin SDK with
HTTP 410 (`messaging/registration-token-not-registered`), when the
callable runs, then the callable throws
`HttpsError('unavailable', ...)` with
`details.errorCode === 'FCM_DISPATCH_FAILED'` AND no rate-limit doc
is written (per architect §2.5: rate-limit records on
`succeeded >= 1` only — full-failure dispatch is not a "send"). The
410-pruned tokens are still removed from the recipient's `fcmTokens`
array by the existing FR-AC-03 helper (defence-in-depth).

**AC-12 — Group-context path returns a forward-compat error today.**
Given a call with `contextType: 'group'` and any `contextId`, when
the callable runs in v1.0, then it throws
`HttpsError('unimplemented', ...)` with
`details.errorCode === 'GROUP_CONTEXT_NOT_SUPPORTED'`. (The Sprint 3
groups epic ratifies the full group-context path; FR-SE-09 v1.0
ships friendship-context only.)

### Client UX — positive

**AC-13 — OBTSettleUpCard receiving-direction variant renders on the
friend-owes branch.** Given `state.header.balanceState ==
BalanceState.owed` on `FriendDetailScreen` (i.e. the friend owes the
authenticated user), when the screen renders, then
`OBTSettleUpCard(isReceivingDirection: true, ...)` is rendered with
the CTA label "Send Reminder", the avatar arrow flipped (friend →
you), the friend's avatar on the left as the payer position, and
the suggested amount displaying the absolute net balance via
`formatInrFromPaise()`.

**AC-14 — Tap fires the controller; success disables button via
cooldown provider.** Given the receiving-direction card is rendered,
when the user taps "Send Reminder" and the callable returns
`{ success: true, nextAllowedAtIso }`, then the
`reminderCooldownProvider(friendshipId)` is set to the returned
`nextAllowedAt`, the button transitions to a disabled state with a
caption like "Next reminder in 23h 59m" (live countdown), and a
`reminder_send_succeeded` client telemetry event fires with
`friendship_id_hash` parameter.

**AC-15 — Rate-limited returns show inline countdown.** Given the
callable returns `RATE_LIMITED` with `nextAllowedAtIso`, when the
controller surfaces the error, then a snackbar reads "You can send
another reminder to {friend.displayName} in {h}h {m}m." (per
`notifications.md §6.1`), AND a `reminder_send_rate_limited` client
telemetry event fires with `friendship_id_hash` +
`next_allowed_in_seconds` parameters, AND the cooldown provider is
updated to the server-returned `nextAllowedAt` (so the button stays
disabled).

**AC-16 — Prefs-disabled returns show a friendly snackbar.** Given
the callable returns `RECIPIENT_PREFS_DISABLED`, when the controller
surfaces the error, then a snackbar reads "{friend.displayName} has
notifications turned off." AND a
`reminder_send_recipient_prefs_disabled` client telemetry event
fires with `friendship_id_hash` parameter.

**AC-17 — No-tokens returns show a friendly snackbar.** Given the
callable returns `RECIPIENT_NO_TOKENS`, when the controller surfaces
the error, then a snackbar reads "{friend.displayName} hasn't
enabled push notifications yet." AND a
`reminder_send_recipient_no_tokens` client telemetry event fires
with `friendship_id_hash` parameter.

**AC-18 — Doesn't-owe returns show an error snackbar.** Given the
callable returns `RECIPIENT_DOESNT_OWE` (race condition where
`simplifiedBalances` drifted between render and tap — e.g. the friend
just settled), when the controller surfaces the error, then a
snackbar reads "{friend.displayName}'s balance has changed. Pull to
refresh." AND a `reminder_send_recipient_doesnt_owe` client
telemetry event fires with `friendship_id_hash` parameter.

### Cross-cutting and negative guards

**AC-19 — Telemetry events fire with correct PII guard.** Given any
of the new server structured-log events (`reminder_send_attempted`,
`reminder_send_succeeded`, `reminder_send_rate_limited`,
`reminder_send_skipped_by_prefs`, `reminder_send_failed_no_tokens`,
`reminder_send_recipient_doesnt_owe`, `reminder_send_failed`) OR
any of the new client events (`reminder_send_tapped`,
`reminder_send_succeeded`, `reminder_send_rate_limited`,
`reminder_send_recipient_prefs_disabled`,
`reminder_send_recipient_no_tokens`,
`reminder_send_recipient_doesnt_owe`, `reminder_send_failed`), when
the event is emitted, then any UID-derived parameter (sender, recipient,
or friendship id) is hashed through `hashId()` (server) /
`hashFriendshipId()` (client); the optional `message` body is NEVER
logged in raw form (only its presence + length if at all); FCM
tokens are NEVER logged in raw form (use `fingerprintToken()` per
FR-AC-03).

**AC-20 — Invariant 1 boundary contract (client + server).** Given
the PR diff, when scanned for `.toDouble()`, `parseFloat`, `/100`,
`.toFixed`, or `double` declarations on monetary fields, then ZERO
violations exist anywhere in `lib/features/reminders/**` or
`functions/src/send-reminder-notification/**`. The new client-side
grep at `test/features/reminders/reminders_boundary_contract_test.dart`
is the affirmative client-side gate; the existing Functions-side
grep at `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
auto-covers the new server files.

**AC-21 — Invariant 2 negative guard.** Given the PR diff, when
scanned, then ZERO new writes to `simplifiedBalances` exist
anywhere. The callable READS the field for the precondition check
(via `db.collection('friendships').doc(contextId).get()`); the
rate-limit write goes to `_rateLimits/{senderUid}/sends/{recipientUid}`
and the activity write goes to `activity/{recipientUid}/items/{auto}`
— neither touches `simplifiedBalances`.

**AC-22 — `notificationPrefs.reminder` is read-only on the server
side.** Given the prefs-filter consults `notificationPrefs.reminder`,
when the callable runs, then NO write to `notificationPrefs`
occurs anywhere on the server side. The client-side FR-PR-03
notification-preferences UI (separate PR) is the ONLY write path
for the field.

## Out of Scope

These are explicitly EXCLUDED to keep PR #54 surgical:

- **FR-PR-03 / FR-AC-04 notification-preferences UI** — separate P1
  story; lives on the Profile screen. The server-side prefs-filter
  shipped in PR #53; FR-SE-09 just CONSUMES it.
- **Group-context reminder producer** — Sprint 3 groups epic. The
  callable accepts `contextType: 'group'` as a forward-compat input
  but throws `GROUP_CONTEXT_NOT_SUPPORTED` today (AC-12).
- **Free-text message-compose dialog** — follow-up UX PR. The
  callable accepts an optional `message?: string` (max 500 chars)
  but the client v1.0 always omits it; the server defaults to a
  hardcoded copy ("This is a friendly reminder!" — architect
  ratifies the exact copy in `notifications.md §6.1` follow-up).
- **OBTSettleUpCard extraction to `lib/core/widgets/cards/`** —
  deferred until a second host needs it (PR #43 §2.6 precedent
  stands; mirror of `OBTAmountInput`).
- **Persistent client cooldown via `shared_preferences`** — pairs
  with the deferred PR #53 §2.6 `shared_preferences` adoption. v1.0
  cooldown is in-memory only; the server is the authoritative gate.
- **Sender-side activity emission** — recipient-only per architect
  §2.3. A future UX-research-driven PR may add sender-side activity
  if needed.
- **SCR-11 overflow-menu reminder action** — the OBTSettleUpCard is
  the primary surface; overflow-menu placement is a deferred UX
  consideration.

## Test Strategy

- **Functions unit tests** (Jest, no emulator):
  - `functions/test/send-reminder-notification/function.test.ts` —
    24+ cases covering ACs 1-12 + 19 + 21 + 22 (auth, input
    validation, non-member, recipient-doesn't-owe, rate-limit
    pre-check rejection + post-window pass, prefs-filter,
    no-tokens, full-failure non-record, group-context forward-compat
    error, happy-path rate-limit doc shape, happy-path FCM call
    shape, happy-path activity emission, PII-hashing of structured
    logs, no `simplifiedBalances` writes, no `notificationPrefs`
    writes).
  - `functions/test/notifications/send-reminder-notification.test.ts`
    — helper-level unit tests mirroring the existing two helper test
    files (prefs short-circuit; empty-tokens short-circuit;
    missing-user log; happy-path FCM dispatch call shape).
  - `functions/test/triggers/on-expense-write/activity-validator.test.ts`
    — extended with `'reminder'` event-type validator coverage
    (positive shape; per-field negative branches for `senderUid`,
    `recipientUid`, `contextType`, `contextId`, `amountPaise`,
    `message`).
- **Flutter unit tests** (no emulator):
  - `test/features/reminders/data/reminder_repository_test.dart` —
    callable wrapper success / per-error-code branches.
  - `test/features/reminders/application/send_reminder_controller_test.dart`
    — controller drives success → cooldown set; per-error-code →
    snackbar message + telemetry event.
  - `test/features/reminders/application/reminder_cooldown_provider_test.dart`
    — provider holds per-friendship `DateTime?`; resets on app
    launch (provider container disposal).
- **Flutter widget tests:**
  - `test/features/friends/presentation/widgets/obt_settle_up_card_test.dart`
    (NEW) — settling-direction renders "Settle Up"; receiving-
    direction renders "Send Reminder"; receiving-direction disabled
    during cooldown with caption; tap fires `onSendReminder`.
  - `test/features/friends/friend_detail_screen_widget_test.dart`
    (EXTEND) — `BalanceState.owed` branch renders receiving-direction
    OBTSettleUpCard; tap routes through the controller.
- **Boundary-contract grep:**
  - `test/features/reminders/reminders_boundary_contract_test.dart`
    — Inv-1 (no float arithmetic) + Inv-2 (no `simplifiedBalances`
    write) guards over `lib/features/reminders/**`. Plus a
    file-existence guard so the recursive walks have something to
    walk.
- **Integration tests:** extended with a reminder-callable round-trip
  (mocked FCM at the SDK boundary; rate-limit doc verified to be
  written; activity-feed doc verified to be written).
- **Manual smoke:** the QA matrix in §5 below covers cross-device
  send + rate-limit enforcement + prefs-filter + no-tokens + race-
  condition coverage.

## Telemetry Contract (FR-SE-09 v1.0)

**Server (structured logs, via `functions/logger`):**

| Event | Trigger | Parameters |
|---|---|---|
| `reminder_send_attempted` | Every callable invocation, before validation | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash` |
| `reminder_send_succeeded` | After successful FCM dispatch + rate-limit + activity writes | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash`, `succeeded`, `failed`, `pruned` (count only) |
| `reminder_send_rate_limited` | Pre-check rejection within 24h window | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash`, `nextAllowedAtIso` |
| `reminder_send_skipped_by_prefs` | Prefs-filter rejection | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash` |
| `reminder_send_failed_no_tokens` | Empty `fcmTokens` rejection | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash` |
| `reminder_send_recipient_doesnt_owe` | `simplifiedBalances` precondition rejection | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash` |
| `reminder_send_failed` | Any other catch-all error | `senderUidHash`, `recipientUidHash`, `contextType`, `contextIdHash`, `errorCode` |

**Client (Firebase Analytics, via `analyticsServiceProvider`):**

| Event | Trigger | Parameters |
|---|---|---|
| `reminder_send_tapped` | OBTSettleUpCard `onSendReminder` fired | `friendship_id_hash` |
| `reminder_send_succeeded` | Callable returned success | `friendship_id_hash` |
| `reminder_send_rate_limited` | Callable returned RATE_LIMITED | `friendship_id_hash`, `next_allowed_in_seconds` |
| `reminder_send_recipient_prefs_disabled` | Callable returned RECIPIENT_PREFS_DISABLED | `friendship_id_hash` |
| `reminder_send_recipient_no_tokens` | Callable returned RECIPIENT_NO_TOKENS | `friendship_id_hash` |
| `reminder_send_recipient_doesnt_owe` | Callable returned RECIPIENT_DOESNT_OWE | `friendship_id_hash` |
| `reminder_send_failed` | Network / unknown / FCM_DISPATCH_FAILED | `friendship_id_hash`, `error_code` |

PII guard (ADR-0013): every UID-derived parameter on the server side
goes through `hashId()`; every friendship-id-derived parameter on
the client side goes through `hashFriendshipId()`; FCM tokens use
`fingerprintToken()` (FR-AC-03 precedent); the optional reminder
`message` body is NEVER logged.

## Invariant Compliance

| Invariant | Applicability | How enforced |
|---|---|---|
| 1 — paise integers | Applicable on the `amountPaise` carry-through path | The callable reads `simplifiedBalances[recipientUid][senderUid]` as `int`, passes it unchanged to `renderPayload('reminder', { amountPaise, ... })`, which uses the Functions-side `format-inr.ts` helper for the body string. ZERO inline `/100` arithmetic anywhere in `functions/src/send-reminder-notification/**` or `lib/features/reminders/**`. Existing Functions-side grep + new client-side grep enforce. |
| 2 — `simplifiedBalances` server-only | Applicable as a NEGATIVE guard | The callable READS `simplifiedBalances` for the precondition check; ZERO new writers. Client-side reminders module never references the field (boundary-contract grep enforces). |
| 3 — system share sheet | N/A | Reminders use FCM push, not the share sheet. |
| 4 — single Firebase project | Defence-in-depth re-check | `.firebaserc` unchanged; FCM admin SDK uses the same `firebase-admin/app` initialisation. |

## Definition of Done

- All 22 ACs satisfied with passing tests.
- Story (this file) + Architect Notes appended.
- `dart format --set-exit-if-changed .` exits 0.
- `flutter analyze --fatal-infos` exits 0; `flutter test` 1083 + ~30
  new = ~1113 tests pass.
- `cd functions && npm run lint && npm run build && npm test` exits
  0; ~270 + ~30 new = ~300 tests pass across ~22 suites.
- `cd functions && npm run test:rules` exits 0 (188 / 9 suites
  unchanged).
- `cd functions && npm run test:integration` extended with the new
  reminder round-trip; passes.
- `docs/sprint-zero/sprint-2-plan.md` rolled forward with the PR
  #54 row (6 SP; cumulative 79 SP / 18 PRs).
- `docs/sprint-zero/next-three-prs.md` rolled forward (PR #55 TBD;
  top candidate FR-PR-03 + FR-AC-04 notification-preferences UI).
- `docs/audits/sprint-1/07-bucket-b-burndown.md` PR #54 entry
  appended (no items closed; partial PY3 progress).
- DoD checklist §7 invariant compliance verified in PR body.

## GitHub Issue This Story Closes

**None.** FR-SE-09 is a P1 SRS row; no separate GitHub issue exists.
The story is the source of truth.

---

## Architect Notes

> Appended by the architect agent at Phase 2 of the PR #54 protocol.
> These notes RATIFY the design calls flagged in the orchestrator's
> brief and pin the surface area for the Functions-dev + Flutter-dev
> implementations that follow.

### 2.1 Rate-limit doc path

**RATIFY:** `_rateLimits/{senderUid}/sends/{recipientUid}` (5-segment
path). Schema:

```typescript
interface RateLimitSendDoc {
  lastSentAt: Timestamp;       // serverTimestamp on write
  count: number;               // monotonic counter (FieldValue.increment(1))
  windowStart: number;         // ms epoch of the first send in the
                               // current rolling window
  recipientUid: string;        // denormalised for queryability
  senderUid: string;           // denormalised for queryability
  updatedAt: Timestamp;        // serverTimestamp on write
}
```

The path extends the architect-canonical
`_rateLimits/{userId}/{category}/{key-or-counter}` container ratified
in the PR #45 chore (§2.1 / §2.9 of
`CHORE-pr45-lookup-rate-limit-and-pr38-cleanup.md`). The recipient
UID replaces the literal `counter` doc-ID in the 4-segment lookup
variant because reminders are per-pair, not per-sender. The existing
`firestore.rules:355` deny-all block (`match
/_rateLimits/{document=**}`) already covers the new path — no rules
diff is required.

The legacy `reminders/{senderUid}_{toUserId}` shape documented in
`cloud-functions-catalogue.md §7` is SUPERSEDED by this 5-segment
path. The catalogue is documentation, not source-of-truth; a
docs-roll-up PR may update the catalogue post-merge (not in scope
here per §2.10 below).

### 2.2 FCM dispatch helper placement

**RATIFY:** Add `functions/src/notifications/send-reminder-notification.ts`
mirroring `send-expense-notification.ts` /
`send-settlement-notification.ts`. The helper composes:

1. `db.collection('users').doc(toUserId).get()` for prefs + tokens.
2. `isNotificationAllowed('reminder', prefs)` short-circuit (returns
   suppressed-by-prefs branch).
3. `tokens.length === 0` short-circuit (returns empty-tokens branch).
4. `renderPayload('reminder', { senderName, amountPaise, contextType,
   contextId, createdAt })`.
5. `sendFcmToTokens(deps, { userId: toUserId, notificationType:
   'reminder', tokens, payload })`.

The helper returns the standard `NotificationDispatchResult`. It
does NOT throw — the callable wraps each branch decision and maps to
its typed `HttpsError` codes itself. (Unlike the trigger-side
callers, the callable WANTS to distinguish "prefs disabled" from
"no tokens" from "delivery failed" — so the callable consumes the
result's tally fields directly and the helper is a pure dispatch
leaf, not a decision-maker.)

Extend `notifications/index.ts` with `export
{sendReminderNotification} from "./send-reminder-notification"` and
`notifications/types.ts` with `SendReminderNotificationParams`
interface mirroring `SendSettlementNotificationParams`:

```typescript
export interface SendReminderNotificationParams {
  fromUserId: string;          // sender — for log correlation; NOT a recipient
  toUserId: string;            // recipient
  contextType: 'friendship' | 'group';
  contextId: string;
  senderName: string;          // resolved displayName of the sender
  amountPaise: number;         // OWED amount per simplifiedBalances
  eventTimestamp: Date;        // server-side now()
}
```

Extend `NotificationsApi` with:

```typescript
sendReminderNotification(
  deps: NotificationsDependencies,
  params: SendReminderNotificationParams,
): Promise<NotificationDispatchResult>;
```

### 2.3 Activity-feed emission target

**RATIFY:** Recipient-only emission. The reminder is delivered to
the recipient via FCM; the in-app activity row at
`activity/{recipientUid}/items/{auto-id}` is the recipient's record
of receipt. The sender's confirmation is the optimistic-disable
button state on the OBTSettleUpCard receiving-direction variant
(via `reminderCooldownProvider`).

A future UX-research-driven PR may add sender-side activity emission
("you sent a reminder to {friend}") if user research shows senders
want a paper-trail. v1.0 keeps the surface minimal.

### 2.4 Validator extension scope

**RATIFY:** The `activity-validator.ts` extension for the
`'reminder'` event-type ships in this PR — it's a small,
backward-compatible extension and ships alongside the only producer
that needs it. The reminder activity payload shape:

```typescript
export interface ReminderPayload {
  senderUid: string;
  recipientUid: string;
  contextType: 'friendship' | 'group';
  contextId: string;
  amountPaise: number;         // positive integer paise
  message?: string;            // optional free-text (max 500 chars)
}
```

Add to `payload-builder.ts`:

- Extend `ActivityItemType` discriminated union with `'reminder'`.
- Export `ReminderPayload` interface.
- Add `'reminder'` to `ActivityPayload` discriminated union.

Add to `activity-validator.ts`:

- Add `case 'reminder':` branch to the `validateActivityPayload`
  switch.
- New `validateReminderPayload(payload)` function asserting:
  - `senderUid`, `recipientUid`, `contextType`, `contextId` are
    non-empty strings.
  - `contextType ∈ {'friendship', 'group'}`.
  - `amountPaise` is a positive integer.
  - `message`, when present, is a string of length ≤ 500.

Existing activity items remain valid (no breaking change).

The `writeExpenseActivity` writer name is misleading post-PR #52 (it
now writes settlement and reminder activities too) but the rename
remains DEFERRED per FR-AC-01 architect §2.3 — outside the scope of
this PR.

### 2.5 Default vs custom message + rate-limit-on-failure

**RATIFY default message:** The callable accepts an optional
`message?: string` (max 500 chars) but the client v1.0 always omits
it; the server defaults to `"This is a friendly reminder!"` when
`message` is absent. The message-compose dialog is deferred to a
follow-up UX PR.

The default message is currently NOT embedded in the FCM body
string (the body string is templated from the renderer:
`{senderName} is nudging you about ₹{amount}.`); the `message`
field is propagated through to the activity-feed payload only.
That keeps the FCM body deterministic and the user-customisation
surface contained to the in-app row.

**RATIFY rate-limit-on-failure:** Record the rate-limit document on
`succeeded >= 1` (i.e. at least one FCM `send()` resolved). If
every token 410-pruned, the dispatch is a "no-op send" and the
sender's quota is NOT consumed — they can retry later if the
recipient enables push. The callable throws
`HttpsError('unavailable', ...)` with
`details.errorCode === 'FCM_DISPATCH_FAILED'` in this case (AC-11).

### 2.6 Client cooldown persistence

**RATIFY in-memory only.** The cooldown is a Riverpod
`StateProvider.family<DateTime?, String>` keyed by `friendshipId`.
It RESETS on app launch (provider container disposal). The server
is the authoritative gate per `notifications.md §6.1`; the client
provider is a best-effort UX optimisation.

A future PR (paired with the `shared_preferences` adoption deferred
from PR #53 §2.6) may persist the cooldown across launches. Out of
scope here.

> **Reconciled (`shared_preferences` cross-launch persistence chore,
> ADR-0020):** this deferral is now **CLOSED**. `reminderCooldownProvider`
> is a `NotifierProvider.family` persisted via the core `KeyValueStore`
> seam, with a past-`nextAllowedAt` expiry guard applied at hydration so a
> stale value never disables the button. The server (`notifications.md
> §6.1`) remains the authoritative gate; the persisted client value stays a
> best-effort UX optimisation.

### 2.7 OBTSettleUpCard extension

**RATIFY in-place extension.** Add three new parameters:

```dart
const OBTSettleUpCard({
  required this.payerDisplayName,
  required this.payerPhotoUrl,
  required this.payeeDisplayName,
  required this.payeePhotoUrl,
  required this.suggestedAmountPaise,
  required this.onSettleUp,
  this.isReceivingDirection = false,
  this.onSendReminder,
  this.nextAllowedAt,
  super.key,
});
```

Semantics:

- `isReceivingDirection: false` (default) — settling-direction
  (existing). CTA reads "Settle Up"; tapping fires `onSettleUp`.
- `isReceivingDirection: true` — receiving-direction. CTA reads
  "Send Reminder"; tapping fires `onSendReminder` (which MUST be
  provided when `isReceivingDirection: true`). The avatar arrow
  semantic label flips from "pays" to "owes". When `nextAllowedAt`
  is in the future, the button is disabled with a caption like
  "Next reminder in {h}h {m}m" (live countdown).

The existing settling-direction call site
(`FriendDetailScreen` `BalanceState.owes` branch) is unaffected — it
omits the new parameters and gets the existing behaviour.

Extraction of the widget to `lib/core/widgets/cards/` remains
DEFERRED until a second host needs it (PR #43 §2.6 ratification
stands; precedent: `OBTAmountInput` extraction landed in PR #38 only
when the FR-SE-05 settle-up sheet became the second host).

### 2.8 Files to touch (exhaustive)

Anything outside this set is scope creep. New files marked NEW;
extended files marked EXTEND.

**Functions side (server):**

- NEW `functions/src/send-reminder-notification/index.ts` — `onCall`
  wrapper, region-pinned to `asia-south1`.
- NEW `functions/src/send-reminder-notification/function.ts` — handler
  factory `createSendReminderHandler(deps)` returning the async
  handler. Validates inputs, throws typed `HttpsError` codes,
  orchestrates the flow per §1 of the orchestrator's brief.
- NEW `functions/src/notifications/send-reminder-notification.ts` —
  FCM dispatch helper per §2.2.
- EXTEND `functions/src/notifications/index.ts` — re-export
  `sendReminderNotification`.
- EXTEND `functions/src/notifications/types.ts` —
  `SendReminderNotificationParams` interface;
  `NotificationsApi.sendReminderNotification` method signature.
- EXTEND `functions/src/triggers/on-expense-write/payload-builder.ts`
  — extend `ActivityItemType` with `'reminder'`; export
  `ReminderPayload` interface; extend `ActivityPayload` union.
- EXTEND `functions/src/triggers/on-expense-write/activity-validator.ts`
  — `case 'reminder':` branch + `validateReminderPayload`.
- EXTEND `functions/src/index.ts` — re-export
  `sendReminderNotification`.

**Functions side (tests):**

- NEW `functions/test/send-reminder-notification/function.test.ts` —
  24+ cases per the AC matrix.
- NEW `functions/test/notifications/send-reminder-notification.test.ts`
  — helper-level unit tests mirroring the existing two helper test
  files.
- EXTEND `functions/test/triggers/on-expense-write/activity-validator.test.ts`
  — `'reminder'` event-type coverage.

**Flutter side (client):**

- NEW `lib/features/reminders/data/reminder_repository.dart` —
  callable wrapper; `CloudFunctionException` → typed result.
- NEW `lib/features/reminders/domain/reminder_send_error.dart` — sealed
  hierarchy mirroring the server typed-error codes.
- NEW `lib/features/reminders/domain/reminder_send_success.dart` —
  `{ nextAllowedAt: DateTime }`.
- NEW `lib/features/reminders/application/send_reminder_controller.dart`
  — Riverpod `Notifier<SendReminderState>` driving in-progress /
  success / error states; emits the client telemetry events per §3.
- NEW `lib/features/reminders/application/reminder_cooldown_provider.dart`
  — `StateProvider.family<DateTime?, String>` per §2.6.
- NEW `lib/features/reminders/application/reminder_telemetry.dart` —
  event-name + parameter-key constants (mirror of
  `settle_up_telemetry.dart`).
- EXTEND `lib/features/friends/presentation/widgets/obt_settle_up_card.dart`
  — three new parameters per §2.7.
- EXTEND `lib/features/friends/presentation/friend_detail_screen.dart`
  — `BalanceState.owed` branch wires the receiving-direction card.

**Flutter side (tests):**

- NEW `test/features/reminders/data/reminder_repository_test.dart`
- NEW `test/features/reminders/application/send_reminder_controller_test.dart`
- NEW `test/features/reminders/application/reminder_cooldown_provider_test.dart`
- NEW `test/features/friends/presentation/widgets/obt_settle_up_card_test.dart`
  (the file does not exist today — the FR-FR-04 widget was shipped
  without its own dedicated test file; both directional variants
  ship together here).
- EXTEND `test/features/friends/friend_detail_screen_widget_test.dart`
  — `BalanceState.owed` branch coverage.
- NEW `test/features/reminders/reminders_boundary_contract_test.dart`
  — mirror of `test/features/notifications/notifications_boundary_contract_test.dart`.

**Docs:**

- NEW `docs/sprint-zero/stories/FR-SE-09-send-reminder.md` (this file).
- EXTEND `docs/sprint-zero/sprint-2-plan.md` — PR #54 row.
- EXTEND `docs/sprint-zero/next-three-prs.md` — PR #54 merged; PR
  #55 candidates.
- EXTEND `docs/audits/sprint-1/07-bucket-b-burndown.md` — PR #54
  entry.

### 2.9 Files explicitly NOT to touch

- `firestore.rules` — UNCHANGED (existing `_rateLimits/{document=**}`
  deny-all already covers the new path).
- `firestore.indexes.json` — UNCHANGED.
- `storage.rules` — UNCHANGED.
- `pubspec.yaml`, `functions/package.json` — UNCHANGED.
- `lib/features/expenses/**`, `lib/features/settlements/**`,
  `lib/features/activity/**`, `lib/features/notifications/**` (the
  FR-AC-03 surface stays stable) — UNCHANGED.
- `functions/src/triggers/**` (the PR #51/52/53 trigger wiring is
  stable) — UNCHANGED except for `payload-builder.ts` +
  `activity-validator.ts` per §2.4.
- `functions/src/notifications/{fcm-send,payload-renderer,prefs-filter,send-expense-notification,send-settlement-notification}.ts`
  — UNCHANGED. `index.ts` + `types.ts` touched only for the new
  exports per §2.2.
- `.github/workflows/*.yml` — UNCHANGED.
- `docs/design/**` — read-only references; no spec updates in this
  PR (a docs roll-up PR may follow per §2.10).

### 2.10 Anticipated reconciliations

1. `cloud-functions-catalogue.md §7` storage path
   `reminders/{senderUid}_{toUserId}` is OBSOLETED by the
   architect-canonical `_rateLimits/{senderUid}/sends/{recipientUid}`
   path. The catalogue is documentation, not source-of-truth; the
   architect notes here are the canonical record. A docs roll-up PR
   may update the catalogue post-merge.
2. `cloud-functions-catalogue.md §7` says the `RECIPIENT_NO_TOKENS`
   case "returns `success: true`"; the architect-ratified contract
   here throws `HttpsError('failed-precondition')` with
   `RECIPIENT_NO_TOKENS` so the client can show a friendly snackbar
   (AC-17). Same docs-roll-up PR addresses this.
3. The default-message copy `"This is a friendly reminder!"` is
   architect-ratifiable; UX may revise in a future PR.
4. Group-context support is forward-compat-stub-only in v1.0; Sprint
   3 groups epic ratifies the full path.
5. The optimistic-disable UI does not survive app restart in v1.0;
   future `shared_preferences` adoption (deferred from PR #53) may
   persist.
6. The free-text message-compose dialog is deferred to a follow-up
   UX PR.
7. `writeExpenseActivity` is the misnamed-but-canonical writer
   (handles expense + settlement + reminder activities now); the
   rename remains DEFERRED per FR-AC-01 architect §2.3.
