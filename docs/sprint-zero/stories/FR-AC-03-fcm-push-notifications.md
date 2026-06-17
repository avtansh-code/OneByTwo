# FR-AC-03 + FR-AC-05: FCM Push Notifications + Cold-Start Deep-Link

> Implementation-ready user story for the **first integration of Firebase
> Cloud Messaging end-to-end** in the OneByTwo application. Ships the
> server FCM send module (admin-SDK helper + per-event-type renderer +
> preferences filter + token-cleanup-on-410), the two trigger-extension
> hooks (`emitExpenseFcm` at `functions/src/triggers/on-expense-write/
> function.ts:167` + `emitSettlementFcm` at `functions/src/triggers/
> on-settlement-write/function.ts:237`), the client FCM token lifecycle
> (acquisition after profile-setup-complete, `onTokenRefresh`, sign-out
> cleanup), the pre-permission dialog ("Stay in the loop"), the
> foreground in-app banner, the background `onBackgroundMessage` handler
> for the system notification, and the cold-start `getInitialMessage`
> deep-link resolver that reuses the FR-AC-01 in-app routing surface
> through a new shared `lib/core/routing/notification_deep_links.dart`
> helper. FR-AC-05 (cold-start deep-link) is bundled as the natural pair
> because FCM IS the cold-start signal; without the FCM tap event there
> is no cold-start intent to resolve.

---

## SRS Requirement ID(s)

FR-AC-03 (SRS section 4.7 lines 236-240 — "The app shall send push
notifications via Firebase Cloud Messaging for events relevant to the
user"; P0), FR-AC-05 (SRS section 4.7 — "Tapping a notification shall
deep-link the user to the relevant screen, even from a cold start";
P0). FR-AC-04 (notification preferences) is partially exercised on the
server-side prefs-filter path (the filter is implemented; the Profile
preferences UI is FR-PR-03 and ships in a separate P1 PR).

## Relevant SRS Sections

- Section 4.7 — Activity Feed and Notifications (FR-AC-03, FR-AC-05,
  FR-AC-04 server-side enforcement).
- Section 4.2 — Profile and preferences (FR-PR-03 reads / writes
  `notificationPrefs`; this story only READS).
- Section 5.6 — Accessibility (pre-permission dialog focus trap; 48 dp
  tap targets; in-app banner live-region announcement).
- Section 5.10 — Observability (seven new analytics events: four
  server, three client).
- Section 6.2 — Visual system tokens (banner 16 dp radius, 4 dp
  elevation, 300 ms ease-in-out; dialog 24 dp radius, 8 dp elevation).
- Section 6.3 — Core screens (the pre-permission dialog is part of the
  Home dashboard first-session flow).
- Section 7.2 — Firestore schema (`fcmTokens: string[]`,
  `notificationPrefs: { newExpense, settlement, reminder }` on
  `users/{userId}`; both fields already declared with default values).
- Section 7.3 — Invariant 1 (amount-paise to rupee conversion on the
  FCM payload-render boundary uses a Functions-side helper mirroring
  `formatInrFromPaise()`).
- Section 7.5 — Security rules (`users/{userId}` rules unchanged;
  owner-only read/write already permits client to manage own
  `fcmTokens`; admin SDK bypasses rules for server-side reads).

## Priority

**P0 — Must have.** Both FR-AC-03 and FR-AC-05 are flagged P0 in SRS
section 4.7. The activity-feed read-side shipped in the predecessor PR
gives the user an in-app view of events; FCM push notifications give
the user out-of-app awareness. Without FCM the user must open the app
to see new expenses and settlements — the SRS contract explicitly
requires push.

## Story Points

**10.** Decomposes as:

- 3 SP — server FCM module (`fcm-send.ts` admin-SDK wrapper with
  parallel send + 410 token cleanup, `payload-renderer.ts` per-event-
  type templates, `prefs-filter.ts` notification-preferences short-
  circuit, `notifications/index.ts` public surface, Functions-side
  `format-inr.ts` helper for Invariant 1 preservation).
- 2 SP — trigger-extension hooks (`emitExpenseFcm` + `emitSettlementFcm`
  mirroring the FR-EX-07 / FR-AC-01 activity-emission contract; error
  containment per architect §2.9 item 2).
- 3 SP — client FCM lifecycle (`fcm_token_service.dart` with `arrayUnion`
  / `arrayRemove` / `onTokenRefresh`, `notification_handler.dart` with
  the three platform handlers, `notification_payload.dart` domain
  parsing, `deep_link_handler.dart` routing dispatcher,
  `pending_deep_link_provider.dart` cold-start intent provider).
- 1 SP — pre-permission dialog + permission controller (custom Notifier
  driving the "Stay in the loop" flow + session-scoped "Not now"
  suppression).
- 1 SP — in-app banner + cold-start deep-link handler + shared routing
  helper (`in_app_notification_banner.dart`,
  `core/routing/notification_deep_links.dart` extracted from the
  FR-AC-01 `_onRowTap` logic + consumed by both the activity-feed row
  tap and the FCM tap).

Patterns from FR-EX-07 (trigger-extension error containment,
structured logging, per-member fan-out, PII guard), FR-AC-01
(client feature-folder layout, StreamProvider, deep-link routing),
and FR-AU-06 (UserRepository CRUD pattern) are reused; this story
does not re-derive them.

## User Story

As a **signed-in user**,
I want **a push notification on my phone whenever a friend adds,
edits, or deletes an expense involving me, or settles up with me**,
so that **I am aware of changes to my shared finances without having
to open the app**;

and as **the same user**,
I want **tapping any notification to take me directly to the relevant
screen, even if the app was fully closed**,
so that **I can act on the notification (view the expense, send a
reminder, settle up) without having to manually navigate after
opening the app**.

## Preconditions

1. The signed-in user has a Firestore document at `users/{uid}` with
   the schema-default `fcmTokens: []` and `notificationPrefs:
   { newExpense: true, settlement: true, reminder: true }` (shipped
   with FR-AU-06).
2. The Firebase Cloud Messaging service is configured for the production
   Firebase project (only project per Invariant 4).
3. The OS-level push notification permission has been requested at least
   once (this story ships the pre-permission dialog and OS request flow
   that establish the precondition).
4. The reusable `activity-writer.ts`, `payload-builder.ts`,
   `activity-validator.ts` modules and the trigger handlers at
   `functions/src/triggers/on-expense-write/function.ts` and
   `functions/src/triggers/on-settlement-write/function.ts` are
   deployed to `asia-south1` per SRS section 7.1.
5. The Firebase Emulator Suite is available for pre-merge integration
   testing (FCM emulator is NOT part of the suite; tests mock at the
   SDK boundary).

---

## Acceptance Criteria

### FCM token lifecycle — positive ACs

#### AC-1 — FCM token is acquired AFTER profile setup, NOT at launch

> Given a freshly-signed-up user completes the profile-setup screen
> When they land on the `HomePlaceholderScreen` for the first time in
> the session
> Then the pre-permission dialog ("Stay in the loop") is displayed
> per the wireframes section 1.1
> And on tap of "Enable Notifications" the OS-level permission prompt
> is triggered
> And on grant a new FCM token is acquired via
> `FirebaseMessaging.instance.getToken()`
> And the token is written to `users/{uid}.fcmTokens` via Firestore
> `arrayUnion` (idempotent)

#### AC-2 — Token refresh updates the array via arrayRemove + arrayUnion in one batched write

> Given the app is running with an existing FCM token registered on
> `users/{uid}.fcmTokens`
> When `FirebaseMessaging.onTokenRefresh` fires with a new token
> Then the old token is removed via `arrayRemove`
> And the new token is added via `arrayUnion`
> And both operations execute in a SINGLE batched write
> (`Firestore.batch().commit()`) so there is no window where no valid
> token exists on the document

#### AC-3 — Sign-out removes the current device token before FirebaseAuth.signOut

> Given the user taps Sign Out
> When the sign-out flow runs
> Then the current device's FCM token is removed from
> `users/{uid}.fcmTokens` via `arrayRemove`
> And `FirebaseAuth.signOut()` is called AFTER the arrayRemove write
> resolves (success or failure — sign-out is not blocked by an
> arrayRemove timeout)

### Server-side FCM send — positive ACs

#### AC-4 — Expense trigger sends FCM to non-author members

> Given an expense is created at `friendships/{fid}/expenses/{eid}`
> When the trigger completes the success branch (post-recompute)
> Then `emitExpenseFcm` is called with
> `recipients = memberIds - authorUid`
> And for each recipient with `notificationPrefs.newExpense == true`
> AND non-empty `fcmTokens`
> Then ONE FCM data message is sent per token with the
> `expense_added` template per `notifications.md` §2.2
> And the FCM call site is placed inside the success branch — never
> on the stale-event, CONTEXT_NOT_FOUND, or BALANCE_INVARIANT_VIOLATED
> branches

#### AC-5 — Settlement trigger sends FCM to toUserId only

> Given a settlement is recorded at `settlements/{settlementId}`
> When the trigger completes the success branch
> Then `emitSettlementFcm` is called with
> `recipient = toUserId` (the payee; the payer is the actor and is
> NOT notified of their own action)
> And if `notificationPrefs.settlement == true` AND `fcmTokens` is
> non-empty
> Then ONE FCM data message is sent per token with the
> `settlement_received` template per `notifications.md` §2.2

#### AC-6 — Stale FCM tokens are pruned on 410

> Given an FCM send returns
> `messaging/registration-token-not-registered` (HTTP 410)
> When the send-helper handles the per-token error
> Then the offending token is removed from `users/{uid}.fcmTokens`
> via `arrayRemove`
> And subsequent sends to the same user do NOT re-attempt the pruned
> token
> And a structured-log event `fcm_token_pruned` is emitted with the
> hashed `userIdHash` and the SHA-256-hashed token fingerprint (NOT
> the raw token — defence-in-depth against token leakage in logs)

#### AC-7 — Notification preference flag short-circuits the send

> Given a user has `notificationPrefs.newExpense == false`
> When the expense-trigger attempts to send the `expense_added`
> notification to that user
> Then ZERO FCM sends are issued for that user
> And a structured-log event `fcm_send_suppressed_by_prefs` is emitted
> with the hashed `userIdHash` and the notification type
> And other recipients of the same trigger event with
> `notificationPrefs.newExpense == true` ARE still sent the
> notification (per-recipient short-circuit, not per-event)

#### AC-8 — Amount formatting through Functions-side INR helper preserves Invariant 1

> Given an expense with `amountPaise = 120000`
> When the payload renderer constructs the `body` template
> Then the rendered string contains `"₹1,200"` (Indian numbering
> convention)
> And ZERO inline `/100` arithmetic exists anywhere in
> `functions/src/notifications/**`
> And the new `functions/src/utils/format-inr.ts` helper is the SOLE
> paise→rupee converter on the Functions side
> And the existing Functions-side boundary-contract grep at
> `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
> returns ZERO violations on the new files

### Client foreground / background / cold-start — positive ACs

#### AC-9 — Foreground in-app banner renders on FCM data message

> Given the app is in the foreground
> When `FirebaseMessaging.onMessage` fires with a valid data payload
> Then the in-app notification banner (per wireframes §2) slides in
> from the top with a 300 ms ease-in-out animation
> And auto-dismisses after 4 seconds
> And exposes the title + body + category icon per the wireframes
> banner anatomy table (§2.2)
> And on tap routes to the deep-link target via the shared
> `lib/core/routing/notification_deep_links.dart` helper

#### AC-10 — Background system notification renders

> Given the app is backgrounded
> When `FirebaseMessaging.onBackgroundMessage` fires (top-level
> handler registered before `runApp`)
> Then the system notification tray displays the notification with
> the rendered `title` and `body` per `notifications.md` §3.2
> And tapping the notification opens the app and routes to the
> deep-link target via the shared routing helper

#### AC-11 — Cold-start deep-link resolves the target after auth check

> Given the app is fully terminated
> When the user taps a notification and the OS launches the app
> Then `FirebaseMessaging.instance.getInitialMessage()` returns the
> payload
> And the splash screen is shown for at most 2 seconds while Firebase
> Auth restores the persisted session (per FR-AU-07)
> And if authenticated AND the user has a profile, the deep-link
> target screen is pushed onto the Navigator stack via the shared
> routing helper
> And if NOT authenticated, the payload is stored in
> `pendingDeepLinkProvider` and replayed after the next successful
> sign-in
> And if the target entity no longer exists, the SCR-25 "This item
> is no longer available" snackbar is shown and the user remains on
> the Home dashboard

### Cross-cutting and negative ACs

#### AC-12 — Pre-permission dialog suppresses re-show after "Not now"

> Given the user dismissed the pre-permission dialog via "Not now"
> earlier in the session
> When the same dialog trigger fires again in the same session
> Then the dialog does NOT re-appear
> And the suppression flag persists for the session lifetime only
> (cleared on app restart so the dialog has another chance to land
> on the next launch if the user did not permanently deny)

#### AC-13 — Permission denial does NOT acquire a token

> Given the user denies the OS-level permission prompt
> When the prompt result is handled
> Then no FCM token is acquired
> And no write to `users/{uid}.fcmTokens` occurs
> And a local flag records the denial so the pre-permission dialog
> is NOT shown again automatically (the user may re-enable via the
> notification-preferences screen — out of scope for this PR)

#### AC-14 — Telemetry events fire with correct PII guard

> Given any of the new structured-log events (`fcm_send_attempted`,
> `fcm_send_succeeded`, `fcm_send_failed`, `fcm_token_pruned`,
> `fcm_send_suppressed_by_prefs`) on the server side
> Or any of the new client-side events
> (`fcm_token_registered`, `fcm_permission_prompt_shown`,
> `fcm_notification_tapped`)
> When the event is emitted
> Then any UID-derived parameter (recipient `userIdHash`, sender
> `senderIdHash`, friendship composite `contextIdHash`) is hashed via
> the existing helper (`hashId()` on the server,
> `hashFriendshipId()` / equivalent on the client)
> And FCM tokens themselves are NOT hashed via `hashId()` — they are
> opaque platform-issued strings that are not deterministic UIDs
> (per ADR-0013); however the per-event log MAY include a SHA-256
> fingerprint of the token (truncated to 8 hex chars) for
> diagnosability of which token was pruned without leaking the
> credential itself

#### AC-15 — Invariant 1 boundary contract (client + server)

> Given the PR diff
> When scanned for `.toDouble()`, `parseFloat`, `/100`, `.toFixed`,
> or `double` declarations on monetary fields
> Then ZERO violations exist anywhere in:
>   - `lib/features/notifications/**`
>   - `lib/core/routing/notification_deep_links.dart`
>   - `functions/src/notifications/**`
> And the new affirmative client-side grep test at
> `test/features/notifications/notifications_boundary_contract_test.dart`
> passes
> And the existing Functions-side grep at
> `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
> passes (auto-covers the new Functions files)

#### AC-16 — Invariant 2 negative guard

> Given the PR diff
> When scanned for new writes to `simplifiedBalances`
> Then ZERO new writers exist
> And the FCM module touches only:
>   - `users/{uid}.fcmTokens` (write — server cleanup on 410, client
>     `arrayUnion` on acquisition / `arrayRemove` on sign-out)
>   - `users/{uid}.notificationPrefs` (read — server-side prefs
>     filter; client-side cache for foreground banner suppression)

#### AC-17 — Trigger error containment (architect §2.9 item 2)

> Given any FCM-send failure (network error, admin-SDK throw,
> validator throw, malformed payload, missing user doc)
> When the trigger's `emitExpenseFcm` / `emitSettlementFcm` helper
> runs
> Then the failure is CONTAINED inside the helper's own `try/catch`
> And the trigger's success branch is preserved (recompute already
> done; FCM failure must not retry the whole invocation)
> And a structured-log event `fcm_emission_internal_error` is emitted
> with the hashed `contextIdHash` and the error message
> And Cloud Functions does NOT retry the whole trigger invocation due
> to an FCM-side failure

#### AC-18 — FCM is NOT called on stale-event / CONTEXT_NOT_FOUND / BALANCE_INVARIANT_VIOLATED branches

> Given the trigger handler drops on any of the three negative
> branches above (stale-event guard, CONTEXT_NOT_FOUND from
> recomputeAndWrite, BALANCE_INVARIANT_VIOLATED from
> recomputeAndWrite)
> When the trigger handler returns or throws
> Then `emitExpenseFcm` / `emitSettlementFcm` is NOT called
> And this is symmetric with the FR-EX-07 AC-5 + FR-AC-01 AC-12
> contracts for `emitExpenseActivity` / `emitSettlementActivity`

#### AC-19 — Group invite notifications bypass the preferences filter

> Given a `group_invite` notification type
> When the prefs-filter is consulted
> Then the send proceeds regardless of `notificationPrefs` values
> (per `notifications.md` §2.3 — group invites are not user-
> suppressible because they grant access; they are NOT subject to
> FR-AC-04)
> Note: the `group_invite` SEND path is NOT implemented in this PR
> (group invites are part of the Sprint 3 groups epic). The
> prefs-filter forward-compatibility for `group_invite` is asserted
> via a unit test only.

#### AC-20 — Pre-permission dialog accessibility

> Given a screen reader is active (VoiceOver or TalkBack)
> When the pre-permission dialog displays
> Then the heading "Stay in the loop" is announced as a heading
> (Semantics(header: true))
> And both buttons ("Enable Notifications", "Not now") have a
> minimum 48x48 dp tap target
> And focus is trapped within the dialog (back gesture / scrim tap
> dismisses without focus escape)

---

## Test Plan

### Functions unit tests

- `functions/test/notifications/fcm-send.test.ts` — admin-SDK helper
  with mocked `getMessaging().sendEach(...)`:
  - Sends one message per token (parallel via `Promise.allSettled`).
  - Returns aggregated success / failure counts.
  - On `messaging/registration-token-not-registered`, calls
    `arrayRemove` on `users/{uid}.fcmTokens`.
  - On other errors (network, invalid argument), does NOT prune the
    token; logs `fcm_send_failed`.
  - Empty `tokens` array → no-op (no admin-SDK call, no log).
- `functions/test/notifications/payload-renderer.test.ts` — per-template
  rendering for all six types:
  - `expense_added`, `expense_edited`, `expense_deleted`,
    `settlement_received`, `reminder`, `group_invite`.
  - Asserts Indian-numbering format for `₹1,200` (120000 paise).
  - Asserts ZERO inline `/100` arithmetic (relies on the existing
    Functions-side boundary-contract grep).
- `functions/test/notifications/prefs-filter.test.ts` — per-flag
  short-circuit:
  - `notificationPrefs.newExpense == false` blocks the three
    expense types.
  - `notificationPrefs.settlement == false` blocks `settlement_received`.
  - `notificationPrefs.reminder == false` blocks `reminder`.
  - `group_invite` bypasses the filter (AC-19).
  - Missing `notificationPrefs` map defaults to true for all flags
    (mirrors the schema default).

### Functions trigger-extension tests

- `functions/test/triggers/on-expense-write/function.test.ts` — extend
  with `emitExpenseFcm` assertions:
  - Called once per non-author recipient (mocked module).
  - NOT called on stale-event / CONTEXT_NOT_FOUND /
    BALANCE_INVARIANT_VIOLATED branches.
  - Wrapped in try/catch — internal error does not fail the trigger.
- `functions/test/triggers/on-settlement-write/function.test.ts` —
  mirror for `emitSettlementFcm`:
  - Called with `recipient = toUserId` ONLY.
  - NOT called on the negative branches.
  - Error contained.

### Functions integration tests

- `functions/test/integration/on-expense-write.integration.test.ts` —
  extend with FCM-side assertion (mocked admin Messaging at the SDK
  boundary):
  - End-to-end create → trigger fires → FCM module called with the
    right shape.
- `functions/test/integration/on-settlement-write.integration.test.ts`
  — mirror.

### Client unit tests

- `test/features/notifications/data/fcm_token_service_test.dart` —
  `arrayUnion` / `arrayRemove` / `onTokenRefresh` against a fake repo.
- `test/features/notifications/data/notification_handler_test.dart` —
  payload parsing + foreground / background / cold-start dispatch
  tests.
- `test/features/notifications/application/notification_permission_controller_test.dart`
  — Notifier tests covering the pre-permission dialog flow + "Not now"
  suppression.
- `test/features/notifications/application/deep_link_handler_test.dart`
  — payload → route dispatch tests covering the deep-link map at
  `notifications.md` §4.

### Client widget tests

- `test/features/notifications/presentation/pre_permission_dialog_test.dart`
  — widget tests for the "Stay in the loop" dialog (button taps,
  focus trap, scrim dismiss).
- `test/features/notifications/presentation/in_app_notification_banner_test.dart`
  — widget tests for the 300 ms slide-in banner with auto-dismiss.

### Boundary-contract tests

- `test/features/notifications/notifications_boundary_contract_test.dart`
  — grep over `lib/features/notifications/**` for `.toDouble()`,
  `parseFloat`, `/100`, `.toFixed`, `double ` declarations on
  monetary fields.
- `test/core/routing/notification_deep_links_test.dart` — pure-function
  tests for the deep-link target resolver.

### Manual QA smoke matrix

- Sign in as user A on device 1; verify FCM token is written to
  `users/A.fcmTokens`.
- Sign in as user A on device 2 (debug build with a different FCM
  token); verify both tokens appear in the array.
- As user B, add an expense to the A↔B friendship; verify A receives
  the FCM banner on both devices.
- Tap the banner; verify deep-link routing to the Expense Detail
  screen.
- Set `notificationPrefs.newExpense = false` for A; verify subsequent
  expense adds do NOT trigger FCM.
- Soft-delete user A's app and reinstall; verify the stale FCM token
  is pruned on the next send attempt (410 response).
- Cold-start from a tapped notification (kill the app, send an FCM
  push, tap it); verify the splash → auth-check → target-screen flow.
- Sign out user A; verify the device's FCM token is removed from
  `users/A.fcmTokens` BEFORE `FirebaseAuth.signOut()` completes.

---

## Telemetry Contract

### Server-side (Cloud Functions, structured logs)

| Event | When emitted | Required parameters |
|---|---|---|
| `fcm_send_attempted` | Just before `getMessaging().sendEach(...)` | `userIdHash`, `notificationType`, `tokenCount` |
| `fcm_send_succeeded` | After a successful per-token send | `userIdHash`, `notificationType`, `tokenFingerprint` |
| `fcm_send_failed` | After a per-token failure that is NOT 410 | `userIdHash`, `notificationType`, `tokenFingerprint`, `errorCode` |
| `fcm_token_pruned` | After arrayRemove on 410 | `userIdHash`, `tokenFingerprint` |
| `fcm_send_suppressed_by_prefs` | Per-recipient short-circuit by prefs-filter | `userIdHash`, `notificationType` |
| `fcm_emission_internal_error` | trigger-extension catch block | `contextType`, `contextIdHash`, `errorMessage` |

### Client-side (Firebase Analytics)

| Event | When emitted | Required parameters |
|---|---|---|
| `fcm_token_registered` | After `getToken()` + arrayUnion success | (none — implicit user context) |
| `fcm_permission_prompt_shown` | When the pre-permission dialog appears | `trigger: 'first_session' \| 'manual'` |
| `fcm_notification_tapped` | Foreground banner tap / background tap / cold-start | `notification_type`, `source: 'foreground' \| 'background' \| 'cold_start'`, `target_tab: 'friends' \| 'activity' \| 'none'` (FR-AC-05 tab-switch, ADR-0018 — non-identifying) |

PII guard (ADR-0013): UID-derived parameters MUST be hashed; FCM
tokens themselves are NOT subject to ADR-0013 (opaque, non-deterministic,
rotating) but MAY be SHA-256-fingerprinted (truncated to 8 hex chars)
for diagnosability when included as a log parameter.

---

## Scope Exclusions

The following are explicitly OUT OF SCOPE for this PR:

- **FR-PR-03 / FR-AC-04 notification-preferences UI** — separate P1
  story; lives on the Profile screen with its own SCR-26+.
- **FR-SE-09 Send Reminder** — separate P1 story; introduces the
  per-friend 24-hour rate-limit subcollection per `notifications.md`
  §6.1; will be the FIRST consumer of this PR's FCM module.
- **Group-context FCM (`group_invite` producer)** — Sprint 3 groups
  epic. The renderer ships a stub template for forward compatibility
  but no producer wires it.
- **`OBTBottomNav` shell** — still deferred per the activity-feed
  read-side architect §2.1.
- **Read/unread markers, pagination, filter/search on the activity
  feed** — SCR-25 Open Questions; FUTURE.
- **Issue #47 rules-hardening** — separate small chore PR.
- **Issue #49 orphan-cleanup** — FUTURE.
- **Issue #50 trigger no-op-recompute optimisation** — EXPLICITLY
  CONSTRAINED by FR-EX-07 AC-2.
- **Concurrent-edit detection for FR-EX-06** — still deferred.
- **Rate-limit transaction race refactor** — still deferred.
- **Activity-writer rename cleanup** — deferred per the activity-feed
  read-side architect §2.3.
- **Real FCM emulator wiring** — FCM emulator is NOT part of the
  Firebase Emulator Suite. Tests mock at the SDK boundary; debug
  builds use real FCM tokens for manual smoke.
- **Periodic stale-token sweeps via maintenance Cloud Function** —
  per-send cleanup on 410 is the v1.0 contract.

---

## Definition of Done

- [ ] All 20 ACs above pass automated tests where applicable and
      manual QA where not.
- [ ] `flutter analyze --fatal-infos` exits 0.
- [ ] `dart format --set-exit-if-changed .` exits 0.
- [ ] `flutter test` passes (baseline 973 + ~50 new = ~1023 tests).
- [ ] `cd functions && npm run lint && npm run build && npm test`
      passes (baseline 195 + ~30 new = ~225 tests / ~17 suites).
- [ ] `cd functions && npm run test:rules` passes (188 unchanged —
      no rules diff this PR).
- [ ] Manual QA smoke matrix complete with evidence.
- [ ] Invariant 1: new client-side and existing Functions-side
      boundary-contract greps return zero violations.
- [ ] Invariant 2: zero new writes to `simplifiedBalances`.
- [ ] Invariant 4: `.firebaserc` unchanged.
- [ ] Architect Notes appended (Phase 2).
- [ ] Plan + burndown updated (Phase 7).

---

## Architect Notes

> Appended for the FR-AC-03 + FR-AC-05 FCM PR. These notes ratify
> the design decisions taken before implementation begins.
> References: `.github/shared/invariants.md`,
> `.github/shared/decision-log.md` (ADR-0002 paise integers; ADR-0006
> Riverpod state management; ADR-0007 feature-first folder layout;
> ADR-0013 PII / telemetry hashing; ADR-0014 rules-readable user
> collection), `docs/design/07-technical/notifications.md`,
> `docs/design/04-wireframes/notifications-and-deeplinks.md`.

### 2.1 — Functions-side INR formatter placement

**RATIFY: create `functions/src/utils/format-inr.ts` as a Functions-
side mirror of `lib/core/formatters/inr_formatter.dart`.**

The Functions-side helper has identical semantics to the client-side
`formatInrFromPaise()`: integer arithmetic only, Indian-numbering
convention (e.g. `1,20,000` paise → `"₹1,200"`), no `/100` arithmetic
in the call sites, currency symbol prefix.

Placement co-located with `utils/id-hash.ts` (the existing PII helper)
under `functions/src/utils/` keeps utility helpers in one place. The
existing Functions-side boundary-contract grep at
`functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
auto-covers the new file.

We do NOT share a single TypeScript file across client + functions
because the client is Dart and the functions are TypeScript — the
contract is established by paired unit tests rather than shared code.
A drift would be caught by the per-event-type renderer tests which
assert the exact rendered output for canonical paise inputs.

### 2.2 — FCM token cleanup placement

**RATIFY: the token-cleanup-on-410 logic lives INSIDE
`functions/src/notifications/fcm-send.ts`, NOT in a separate cleanup
function.**

The cleanup is per-send (synchronous `arrayRemove` on 410). No batch
reaper is needed for v1.0 — the per-send path naturally prunes tokens
the moment FCM tells us they are stale.

A future maintenance Cloud Function may run periodic stale-token
sweeps (e.g. tokens that haven't been touched in 90 days). That is
out of v1.0 scope and tracked as a FUTURE candidate in
`next-three-prs.md`.

### 2.3 — Deep-link routing shared helper

**RATIFY: extract `lib/core/routing/notification_deep_links.dart`
(NEW).**

The existing `ActivityFeedScreen._onRowTap` logic (the
`_otherUidForFriendship`, `_showUnavailableSnackbar`, expense /
settlement dispatch switch) refactors to call into this helper. The
same in-app navigation surface is then used by:

1. The activity-feed row tap (existing FR-AC-02 consumer).
2. The foreground FCM banner tap (this PR — FR-AC-03).
3. The background system-notification tap (this PR — FR-AC-03).
4. The cold-start `getInitialMessage` payload (this PR — FR-AC-05).

The helper accepts a `NotificationDeepLinkTarget` value object (a
discriminated union over expense-detail, friend-detail, group-detail,
invite) and a `BuildContext`. It performs the platform navigation
(`Navigator.of(context).push(MaterialPageRoute(...))`). It does NOT
perform telemetry — the call sites do that with their own event
names (e.g. `activity_item_tapped` vs `fcm_notification_tapped`).

### 2.4 — Pending deep-link intent provider

**RATIFY: `lib/features/notifications/application/pending_deep_link_provider.dart`
exposes a `StateProvider<NotificationPayload?>`.**

The cold-start flow sets this provider when the user is unauthenticated.
A Riverpod listener on `authStateNotifierProvider` (placed inside
`OneBytwoApp.build` or a child wrapper widget) watches for the
transition to `AuthenticatedWithProfile` and:

1. Reads the pending payload (if any).
2. Clears it (`ref.read(pendingDeepLinkProvider.notifier).state = null`).
3. Schedules a `WidgetsBinding.instance.addPostFrameCallback` to push
   the target screen onto the Navigator stack.

This cleanly separates the navigation intent from the auth state and
is testable in isolation (the provider is a pure StateProvider; the
listener is a single function that maps `(authState, pendingPayload)
→ navigation action`).

### 2.5 — FCM emulator wiring

**RATIFY: NO FCM emulator wiring in `lib/main.dart`.**

The FCM emulator is not part of the Firebase Emulator Suite (Firebase
documents this as a known limitation). For local development:

- Tests mock `FirebaseMessaging` at the SDK boundary via Riverpod
  overrides on a `firebaseMessagingProvider` (NEW).
- Manual smoke uses a real FCM token in a debug build connected to
  the production Firebase project. Per Invariant 4 there is no second
  project, so debug-build smoke is on production with throwaway test
  accounts (the same approach used for the Auth flow's SMS-OTP
  smoke).

### 2.6 — First-session pre-permission dialog trigger

**RATIFY: a Riverpod listener on `authStateNotifierProvider` inside
the `OneBytwoApp.build` method.**

When the state transitions to `AuthenticatedWithProfile` AND the
local "shown-this-session" flag is false AND the local
"permanently-denied" flag is false, schedule the dialog for the next
frame via `WidgetsBinding.instance.addPostFrameCallback`.

This mirrors the cleanest separation of concerns: the dialog
trigger is centralised in one place (the auth-state listener) and
does not require wiring into `HomePlaceholderScreen.initState` or
any other widget-tree placement. If `HomePlaceholderScreen` is
later replaced by the real dashboard or the `OBTBottomNav` shell,
the trigger continues to fire unchanged.

The "shown-this-session" flag lives in a `Provider<bool>` that
defaults to false on each ProviderScope construction (i.e. each
process launch). It is set to true the moment the dialog is
displayed. The "permanently-denied" flag is persisted in
`SharedPreferences` (or an existing local-storage abstraction) so
that the dialog is not re-shown automatically on subsequent
launches; the user can re-enable from the notification-preferences
screen (FR-PR-03 — separate PR).

### 2.7 — Trigger-extension API surface

**RATIFY:** `emitExpenseFcm(deps, params)` and `emitSettlementFcm(deps,
params)` mirror the existing `emitExpenseActivity` /
`emitSettlementActivity` patterns at the bottom of the respective
function.ts files.

Both helpers:

- NEVER rethrow. Per architect §2.9 item 2 of the FR-EX-07 story,
  trigger-extension failures must not propagate into the trigger's
  success branch.
- Look up the recipient(s)' `users/{uid}` doc to get `fcmTokens` +
  `notificationPrefs` via a single admin-SDK read per recipient
  (parallelised via `Promise.allSettled` for the expense fan-out).
- For expense-trigger: recipients are `memberIds` MINUS the
  `authorUid` (don't notify the author of their own action).
- For settlement-trigger: recipient is `toUserId` ONLY (the payer
  is the actor; the payee is the one notified per `notifications.md`
  §2.2 `settlement_received` template).
- Call the appropriate renderer, then `sendFcmToTokens` from
  `notifications/fcm-send.ts`.
- Are placed inside the success branch of the respective trigger
  AFTER the activity emission (FR-AC-01) call. The order is:
  recompute → log compute_completed → emit activity → emit FCM.

The shared module surface `functions/src/notifications/index.ts`
exports two trigger-facing entry points:

```typescript
export {sendExpenseNotification} from "./send-expense-notification";
export {sendSettlementNotification} from "./send-settlement-notification";
```

These are the only public symbols the triggers import. Internal
helpers (`fcm-send.ts`, `payload-renderer.ts`, `prefs-filter.ts`)
are not directly imported by the triggers — the public surface
encapsulates the per-event-type dispatch.

### 2.8 — Files to touch (exhaustive — anything outside this set is scope creep)

**NEW (server):**

- `functions/src/utils/format-inr.ts`
- `functions/src/notifications/fcm-send.ts`
- `functions/src/notifications/payload-renderer.ts`
- `functions/src/notifications/prefs-filter.ts`
- `functions/src/notifications/send-expense-notification.ts`
- `functions/src/notifications/send-settlement-notification.ts`
- `functions/src/notifications/index.ts`
- `functions/src/notifications/types.ts` — shared types
  (`NotificationType`, `NotificationPayload`, `RecipientPrefs`)
- `functions/test/notifications/fcm-send.test.ts`
- `functions/test/notifications/payload-renderer.test.ts`
- `functions/test/notifications/prefs-filter.test.ts`
- `functions/test/notifications/send-expense-notification.test.ts`
- `functions/test/notifications/send-settlement-notification.test.ts`
- `functions/test/utils/format-inr.test.ts`

**NEW (client):**

- `lib/core/routing/notification_deep_links.dart`
- `lib/features/notifications/data/fcm_token_service.dart`
- `lib/features/notifications/data/notification_handler.dart`
- `lib/features/notifications/domain/notification_payload.dart`
- `lib/features/notifications/application/firebase_messaging_provider.dart`
- `lib/features/notifications/application/notification_permission_controller.dart`
- `lib/features/notifications/application/deep_link_handler.dart`
- `lib/features/notifications/application/pending_deep_link_provider.dart`
- `lib/features/notifications/presentation/pre_permission_dialog.dart`
- `lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`
- `test/features/notifications/data/fcm_token_service_test.dart`
- `test/features/notifications/data/notification_handler_test.dart`
- `test/features/notifications/domain/notification_payload_test.dart`
- `test/features/notifications/application/notification_permission_controller_test.dart`
- `test/features/notifications/application/deep_link_handler_test.dart`
- `test/features/notifications/presentation/pre_permission_dialog_test.dart`
- `test/features/notifications/presentation/in_app_notification_banner_test.dart`
- `test/features/notifications/notifications_boundary_contract_test.dart`
- `test/core/routing/notification_deep_links_test.dart`

**MODIFIED:**

- `functions/src/triggers/on-expense-write/function.ts` — close the
  FR-AC-03 seam at line 167 with the `emitExpenseFcm` call;
  inject `notificationsApi` into Dependencies.
- `functions/src/triggers/on-settlement-write/function.ts` — close the
  FR-AC-03 seam at line 237 with the `emitSettlementFcm` call.
- `functions/test/triggers/on-expense-write/function.test.ts` — add
  FCM-side assertions.
- `functions/test/triggers/on-settlement-write/function.test.ts` —
  mirror.
- `lib/main.dart` — register the top-level `onBackgroundMessage`
  handler before `runApp`; initialise the FCM service.
- `lib/features/auth/application/auth_state_provider.dart` — extend
  with the sign-out FCM-token-cleanup hook (or expose a callback the
  sign-out action can call).
- `lib/features/activity/presentation/activity_feed_screen.dart` —
  refactor `_onRowTap` to dispatch via the shared
  `notification_deep_links.dart` helper.
- `docs/sprint-zero/sprint-2-plan.md`
- `docs/sprint-zero/next-three-prs.md`
- `docs/audits/sprint-1/07-bucket-b-burndown.md`

### 2.9 — Files explicitly NOT to touch (negative scope guardrails)

- `firestore.rules`, `firestore.indexes.json`, `storage.rules` —
  UNCHANGED. The existing `users/{userId}` rules already permit
  owner-only read/write of `fcmTokens` and `notificationPrefs`. The
  FCM module uses admin SDK and bypasses rules.
- `pubspec.yaml` — UNCHANGED. `firebase_messaging: ^16.2.0` is
  already present.
- `functions/package.json` — UNCHANGED. `firebase-admin` already
  provides `getMessaging()`.
- `lib/features/expenses/**`, `lib/features/friends/**`,
  `lib/features/settlements/**`, `lib/features/activity/**`
  (except for the deep-link refactor in `ActivityFeedScreen`) —
  UNCHANGED.
- `functions/src/triggers/on-expense-write/activity-writer.ts`,
  `payload-builder.ts`, `activity-validator.ts` — UNCHANGED.
- `.github/workflows/*.yml` — UNCHANGED.

### 2.10 — Anticipated reconciliations

1. **Snake_case vs camelCase notification types.** The FCM data
   payload uses snake_case (`expense_added`, `settlement_received`)
   per `notifications.md` §2.2. The client deep-link handler converts
   on read using a mapper (similar to
   `ActivityEventTypeX.parseSnakeCase` in the activity feature).

2. **Group invite path deferral.** The `group_invite` template is
   implemented in the renderer for forward compatibility, but no
   producer ships in this PR (groups epic is Sprint 3). The
   prefs-filter assertion that `group_invite` bypasses the filter
   ships as a forward-compatibility unit test only.

3. **Reminder rate-limit subcollection deferral.** FR-SE-09 ships
   separately and consumes this PR's FCM module. The rate-limit
   logic stays out of `notifications/**`.

4. **Notification-preferences UI deferral.** FR-PR-03 / FR-AC-04
   ships separately. This PR only READS `notificationPrefs`, never
   writes.

5. **FCM-emulator absence.** Mocked at the SDK boundary in tests;
   real tokens in debug builds for smoke. See §2.5.

6. **Token-cleanup is per-send, not batched.** See §2.2.

7. **Dependencies injection extension.** The shared `Dependencies`
   type in `functions/src/simplified-debts/function.ts` is the
   admin-SDK dependency-injection seam. The FCM module is exposed
   to the triggers via a `notificationsApi?: NotificationsApi`
   optional field on `Dependencies`. When absent (tests that don't
   mock FCM), the trigger's `emitExpenseFcm` / `emitSettlementFcm`
   no-ops cleanly. This avoids changing the Dependencies shape
   in a way that breaks every existing test.

8. **PII guard for FCM token logging.** FCM tokens are NOT
   deterministic UIDs and are NOT subject to ADR-0013 `hashId()`
   wrapping. However, including the raw token in structured logs
   risks credential leakage. The chosen middle ground is a SHA-256
   fingerprint of the token, truncated to 8 hex chars, included
   under a `tokenFingerprint` field. This is diagnosable (the
   operator can correlate a pruned token across log lines) without
   leaking the credential itself.

