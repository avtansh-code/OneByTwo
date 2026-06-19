# FR-PR-03 + FR-AC-04 — Notification Preferences UI

> Implementation-ready user story for the **first client write path
> to `users/{userId}.notificationPrefs`** (SCR-27) bundled with the
> **first production wiring of `cloud_functions` for
> `reminderRepositoryProvider` + `matchingRepositoryProvider`**.
> Ships the new `/profile/notifications` route, the
> `NotificationPreferencesScreen` (SCR-27) with three per-category
> toggles (auto-save on change; debounced; optimistic-with-revert),
> the new `UserRepository.updateNotificationPrefs(uid, prefs)` writer
> using a dot-path partial-map merge, the `NotificationPreferencesController`
> Riverpod notifier with per-toggle debounce + serial write queue +
> single-fire telemetry, the OS-level permission banner with "Open
> Settings" deep-link, the `cloud_functions: ^X.Y.Z` pubspec
> dependency, the two `cloud_functions`-binding adapter files
> (`reminder_callable_adapter.dart` + `matching_callable_adapter.dart`)
> that translate `FirebaseFunctionsException` into the existing typed
> `ReminderCallableException` / `CloudFunctionException`, and the
> `lib/main.dart` `ProviderScope` overrides that close the long-
> deferred FR-AC-04 / FR-SE-09 round-trip from a real device.

---

## SRS Requirement ID(s)

- **FR-PR-03** (SRS section 4.2 — "Users shall be able to set
  notification preferences per category (new expense, settlement,
  reminders)"; P1). This story is the producer.
- **FR-AC-04** (SRS section 4.7 — "Notifications shall respect the
  user's per-category preferences (FR-PR-03)"; P1). The server-side
  prefs-filter shipped in PR #53 and the `RECIPIENT_PREFS_DISABLED`
  branch of `sendReminderNotification` shipped in PR #54 ALREADY
  consume `notificationPrefs.*`. This story closes the round-trip by
  giving the user the gate they need to actually flip the field, AND
  by wiring the production `cloud_functions` callable so the gate
  has bite from a real device.

The two SRS rows are inseparable: FR-AC-04 is literally "Notifications
shall respect the user's per-category preferences (FR-PR-03)" — there
is no FR-AC-04 surface without FR-PR-03, so they ship as one PR.

## Relevant SRS Sections

- **Section 4.2** — Profile and preferences (FR-PR-03 row: per-category
  notification preferences). This story is the producer.
- **Section 4.7** — Activity Feed and Notifications (FR-AC-04 row:
  server-side preference enforcement; the existing PR #53
  `prefs-filter.ts` and PR #54 `RECIPIENT_PREFS_DISABLED` callable
  branch are the consumers exercised by AC-9 / AC-11 in the end-to-end
  smoke matrix).
- **Section 5.10** — Observability (three new client analytics events,
  all pre-declared in `docs/design/07-technical/telemetry-plan.md`
  lines 204-206; PII guard per ADR-0013 — no UID-derived parameters
  on any of the three events).
- **Section 6.3** — Core Screen 11 sub-screens (SCR-27 lives under the
  Profile cluster; pushed via `MaterialPageRoute` from SCR-26).
- **Section 7.2** — `users/{userId}.notificationPrefs:
  { newExpense, settlement, reminder }: bool` schema (defaults
  all-true per FR-AU-06; the writer mutates one or more keys via
  Firestore dot-path partial updates).
- **Section 7.5** — Security rules. `firestore.rules:93-99`
  `isValidNotificationPrefs(prefs)` already enforces the shape; the
  partial-map merge path is automatically covered because Firestore
  evaluates rules against the post-merge `resource.data`. UNCHANGED
  in this PR; new defence-in-depth rules tests assert the contract.

## Priority

**P1.** Both SRS rows (FR-PR-03 and FR-AC-04) are P1. The natural
next-PR per the post-PR-#54 priority queue: PR #53 shipped the
server-side filter, PR #54 shipped the FR-SE-09 callable that
consults it via `RECIPIENT_PREFS_DISABLED`, and the Profile screen
already exposes a "Notification Preferences" row that is currently a
`Coming soon` snackbar stub at `lib/features/profile/presentation/profile_screen.dart:317-333`.

## Story Points

**5.** Decomposes as:

- **2 SP** — SCR-27 screen (`NotificationPreferencesScreen` with
  three toggle rows + descriptive header + load/error/offline states
  per §States table), the `NotificationPreferencesController`
  Riverpod notifier (per-toggle 500 ms debounce, optimistic update,
  serial write queue, telemetry single-fire on mount, per-toggle
  telemetry on persist), the offline-banner single-fire-per-session
  edge case.
- **1 SP** — `UserRepository.updateNotificationPrefs({required uid,
  required Map<String, bool> prefs})` writer using dot-path partial-
  map merge (`{'notificationPrefs.<key>': value, 'updatedAt':
  serverTimestamp()}`); rules-test extension at
  `functions/test/firestore-rules/users-update.test.ts` covering
  AC-17 / AC-18 / AC-19.
- **1 SP** — OS-level notification-permission banner subscribed to
  the existing `notification_permission_controller.dart` provider;
  "Open Settings" button calling
  `FirebaseMessaging.instance.openAppNotificationSettings()`
  (architect §2.4 ratifies; fallback per architect ratification).
- **1 SP** — `cloud_functions` pubspec dependency + production
  `reminderRepositoryProvider` + `matchingRepositoryProvider`
  overrides in `lib/main.dart`; two `cloud_functions`-binding adapter
  files (`reminder_callable_adapter.dart` +
  `matching_callable_adapter.dart`) translating
  `FirebaseFunctionsException` into the existing typed exception
  classes; emulator-functions wiring under `_useEmulator`.

Escalate to 7 SP only if the architect bundles the `shared_preferences`
adoption for the FR-AC-03 §2.6 `wasPermanentlyDenied` flag + FR-SE-09
§2.6 cooldown persistence — **NOT recommended**; the
`shared_preferences` adoption is its own concern and should land as a
focused chore PR once a third consumer of persistent local state
needs it.

Patterns reused without re-derivation:

- `lib/features/profile/application/edit_profile_controller.dart`
  (FR-PR-01) — sealed-state hierarchy + repository injection +
  telemetry single-fire blueprint.
- `lib/features/reminders/application/send_reminder_controller.dart`
  (FR-SE-09) — in-file state hierarchy + per-screen `autoDispose`
  scope blueprint.
- `lib/features/auth/data/user_repository.dart` `updateProfile`
  writer — partial-map merge + `updatedAt` server-timestamp pattern.
- `lib/features/reminders/data/reminder_repository.dart` — typed
  callable wrapper blueprint; the new
  `reminder_callable_adapter.dart` is the production binding.
- `lib/features/friends/data/matching_repository.dart` — symmetric
  callable wrapper blueprint for the matching path.
- `lib/features/expenses/application/expense_telemetry.dart` —
  `error_code` taxonomy (`firestore-error`, `network`, `unknown`)
  reused verbatim for `notification_pref_error`.
- `test/features/reminders/reminders_boundary_contract_test.dart`
  — Inv-1 + Inv-2 negative-guard grep template; cloned for the new
  `lib/features/profile/**` surface.

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `user/avtanshgupta/0611/fr-pr-03-notification-prefs-ui` |
| **Base** | `main` at `36b0fd3` (PR #54 merged: FR-SE-09 send reminder + rate limit) |
| **Target PR** | #55 |
| **PR title (54 chars)** | `feat(profile): FR-PR-03+FR-AC-04 notification prefs UI` |
| **Commit-title scope** | `profile` (the load-bearing surface — single-token per CI title-lint `[a-z0-9_-]+`) |
| **Story SP** | 5 |
| **Velocity after merge** | 84 SP across 19 PRs |

## Dependencies

This story builds on:

- **PR #53 (FR-AC-03)** — server-side `prefs-filter.ts` that consumes
  `notificationPrefs.{newExpense, settlement, reminder}`. UNCHANGED;
  this PR provides the client write path that flips the bits the
  filter reads.
- **PR #54 (FR-SE-09)** — the `sendReminderNotification` callable's
  `RECIPIENT_PREFS_DISABLED` branch. UNCHANGED; the cross-device
  smoke matrix in Phase 5 exercises this branch end-to-end with the
  REAL `cloud_functions` SDK for the first time (PR #54 stubbed the
  callable via the `throw UnimplementedError` provider).
- **PR #10 (FR-AU-06)** — `UserModel.toCreateMap()` defaults
  `notificationPrefs = {newExpense: true, settlement: true, reminder:
  true}`. Every user created after PR #10 has the fully-shaped map,
  so the dot-path partial-merge write path is always safe (the
  pre-existing map satisfies `isValidNotificationPrefs` before the
  merge).
- **PR #34 (matching repository)** — `matchingRepositoryProvider` is
  currently `throw UnimplementedError(...)`; the production override
  bundled here is the long-deferred completion of ADR-0014.

## GitHub Issue This Story Closes

**None.** FR-PR-03 and FR-AC-04 are P1 SRS rows (sections 4.2 and
4.7 respectively); no pre-existing GitHub issue exists. The story is
the source of truth.

## User Story

As a **signed-in user who wants control over which kinds of push
notifications I receive**,
I want **per-category toggles on the Profile screen for New Expenses,
Settlements, and Reminders that auto-save the moment I flip them**,
so that **I am not spammed with categories I do not care about, and
my preferences immediately take effect on the server-side notification
pipeline (no resend, no delay) — including the FR-SE-09 reminder
gate that depends on this preference being writable from the client**.

## Preconditions

1. User is authenticated and has a `users/{userId}` document with a
   fully-shaped `notificationPrefs` map (FR-AU-06 / PR #10 guarantees
   this for every user created after PR #10 via
   `UserModel.toCreateMap()` defaults `{newExpense: true, settlement:
   true, reminder: true}`).
2. The Profile screen (SCR-26) is functional and renders the
   "Notification Preferences" row at
   `lib/features/profile/presentation/profile_screen.dart:317-333`
   (currently a `Coming soon` snackbar stub; this PR wires the
   `onTap`).
3. The OS-permission tracker
   `lib/features/notifications/application/notification_permission_controller.dart`
   (PR #53 surface) is functional and exposes the current permission
   state via Riverpod.
4. The `reminderRepositoryProvider` (PR #54) and
   `matchingRepositoryProvider` (PR #34) are defined as
   throw-until-overridden — this PR adds the first production
   overrides.

---

## Acceptance Criteria

> 23 ACs. Mirrors the FR-SE-09 cadence (positive contract +
> per-error-code negative branches + cross-cutting invariant guards),
> reframed for the client-side preferences surface + the bundled
> `cloud_functions` production-wiring chore.

### Screen and controller contract — positive ACs

**AC-1 — `/profile/notifications` route opens SCR-27.** Given an
authenticated user is on the Profile View (SCR-26), when they tap
the "Notification Preferences" row, then the app pushes the
`NotificationPreferencesScreen`, the screen renders three toggle
rows (New Expenses / Settlements / Reminders) with descriptions per
SCR-27 §Toggle Mapping, AND a `notification_prefs_viewed` telemetry
event fires exactly once on mount.

**AC-2 — Toggles reflect the persisted state on first render.** Given
the user's `users/{uid}.notificationPrefs` map has `{newExpense:
false, settlement: true, reminder: true}`, when the screen loads,
then the New Expenses toggle is OFF, Settlements is ON, Reminders is
ON. Default values (all-true) render correctly when the map is
freshly initialised.

**AC-3 — Toggle change auto-saves after debounce.** Given the user
toggles New Expenses from ON to OFF, when 500 ms elapse, then
`UserRepository.updateNotificationPrefs(uid, {'newExpense': false})`
is called exactly once with a dot-path partial-map update, AND a
`notification_pref_changed` telemetry event fires with parameters
`{category: 'newExpense', enabled: false}`.

**AC-4 — Optimistic update.** Given the user toggles Reminders, when
the tap is registered, then the toggle's visual state flips
IMMEDIATELY (before the Firestore write resolves) — the UI does NOT
wait for the persist to complete.

**AC-5 — Per-toggle debounce isolation.** Given the user flips New
Expenses ON, then 100 ms later flips Settlements OFF, when the New
Expenses debounce timer (500 ms from its tap) elapses, then the New
Expenses write fires WITHOUT waiting for the Settlements debounce.
The Settlements write fires 500 ms after its own tap.

**AC-6 — Rapid same-toggle debouncing.** Given the user flips
Reminders OFF → ON → OFF → ON within 200 ms, when 500 ms elapse
since the last flip, then ONLY ONE Firestore write fires with the
final state (ON), AND only ONE `notification_pref_changed` event
fires with `enabled: true`.

### Screen and controller contract — negative ACs

**AC-7 — Persist failure reverts the toggle + shows snackbar.** Given
the user toggles New Expenses OFF and `updateNotificationPrefs`
rejects with a Firestore error, when the error surfaces, then the
toggle visual REVERTS to ON (the previous persisted state), an
`OBTSnackbar(message: "Could not update preference. Try again.",
type: error)` is shown, AND a `notification_pref_error` telemetry
event fires with parameters `{category: 'newExpense', error_code:
<firestore-error-code>}`.

**AC-8 — Load failure renders OBTErrorState.** Given the initial
`users/{uid}.get()` rejects, when the screen renders, then the
`OBTErrorState` is shown with title "Something went wrong", subtitle
"Could not load your preferences.", and a Retry button. Tapping
Retry re-issues the read.

**AC-9 — Concurrent flips are processed in order.** Given the user
flips three toggles in quick succession, when all three debounce
timers elapse and the writes are issued, then the controller does
NOT issue them in parallel; writes are SERIALISED via a per-
controller `Future` queue so a slow first write doesn't allow a
later write to commit first.

### Offline + OS-permission edge cases

**AC-10 — Offline banner on first offline toggle.** Given the device
is offline (Firestore connectivity gone), when the user flips the
first toggle, then the optimistic update reflects immediately, the
Firestore write QUEUES locally (Firestore persistence will retry),
AND an `OBTSnackbar(message: "You are offline. Changes will sync
when you reconnect.", type: info)` is shown. Subsequent offline
toggles within the same session do NOT re-show the snackbar
(single-fire per session).

**AC-11 — OS-level notification permission denied banner.** Given the
user has denied OS-level notification permission (OR permanently
denied), when the screen renders, then an info banner appears at the
top: "Notifications are turned off for this app. Enable them in your
device settings to receive alerts." with an "Open Settings" button.
Tapping "Open Settings" calls
`FirebaseMessaging.instance.openAppNotificationSettings()` (OR the
architect-ratified alternative per §2.x).

**AC-12 — Banner hidden when permission is granted.** Given the user
has granted OS-level notification permission, when the screen
renders, then the banner is NOT shown.

### `cloud_functions` production wiring (chore)

**AC-13 — `reminderRepositoryProvider` production override.** Given
the app starts in non-emulator mode, when any consumer reads
`reminderRepositoryProvider`, then a `ReminderRepositoryImpl` is
returned that wraps a `cloud_functions`-backed `ReminderCallable`
pointing at `asia-south1` region, NOT the `throw UnimplementedError(...)`
default.

**AC-14 — `matchingRepositoryProvider` production override.** Given
the app starts in non-emulator mode, when any consumer reads
`matchingRepositoryProvider`, then a `MatchingRepository` is
returned that wraps a `cloud_functions`-backed `LookupCallable`
pointing at `asia-south1` region.

**AC-15 — `FirebaseFunctionsException → ReminderCallableException`
translation.** Given the callable throws
`FirebaseFunctionsException(code: 'resource-exhausted', details:
{errorCode: 'RATE_LIMITED', nextAllowedAtIso:
'2026-06-12T00:00:00.000Z'})`, when the adapter handles it, then it
throws `ReminderCallableException(code: 'resource-exhausted',
errorCode: 'RATE_LIMITED', nextAllowedAtIso:
'2026-06-12T00:00:00.000Z')`. Other `FirebaseFunctionsException`
codes translate per the FR-SE-09 contract; an opaque
non-`FirebaseFunctionsException` failure surfaces as the existing
`ReminderSendFailed('UNKNOWN')` via the repository.

**AC-16 — Emulator-functions wiring.** Given the app starts with
`_useEmulator == true`, when the `cloud_functions` SDK is first
accessed, then `FirebaseFunctions.instanceFor(region:
'asia-south1').useFunctionsEmulator(host, 5001)` has been called
(verified by a flag or a stub in the integration test path).

### Rules contract (defence-in-depth)

**AC-17 — Partial-map `notificationPrefs.reminder` update succeeds.**
Given a user with a fully-shaped `notificationPrefs` map, when they
issue `update({'notificationPrefs.reminder': false, 'updatedAt':
serverTimestamp()})`, then the Firestore rules ALLOW the write (the
merged document still satisfies `isValidNotificationPrefs` because
the merge preserves the other two keys).

**AC-18 — Rules reject partial-map with a non-bool value.** Given
the same user, when they issue `update({'notificationPrefs.reminder':
'yes', 'updatedAt': serverTimestamp()})`, then the Firestore rules
REJECT the write (the merged document's `notificationPrefs.reminder`
is no longer `is bool`).

**AC-19 — Rules reject attempted-removal of a required pref key.**
Given the same user, when they issue
`update({'notificationPrefs': {newExpense: true, settlement: true},
'updatedAt': serverTimestamp()})` (a FULL-replace that drops
`reminder`), then the Firestore rules REJECT the write because
`isValidNotificationPrefs` requires `hasAll(['newExpense',
'settlement', 'reminder'])`.

### Cross-cutting and negative guards

**AC-20 — Telemetry PII guard.** Given any of the three new client
events fires (`notification_prefs_viewed`, `notification_pref_changed`,
`notification_pref_error`), when scanned, then NONE of the payloads
include a `userId` / `uid` / `friendship_id` / `friendship_id_hash`
parameter. The PII-leak grep test asserts this.

**AC-21 — Invariant 1 boundary contract (client).** Given the PR
diff, when scanned for `.toDouble()`, `parseFloat`, `/100`,
`.toFixed`, or `double` declarations on monetary fields, then ZERO
violations exist anywhere in the new `lib/features/profile/**` files
(notification preferences only). The new client-side grep at
`test/features/profile/notification_preferences_boundary_contract_test.dart`
is the affirmative gate.

**AC-22 — Invariant 2 negative guard.** Given the PR diff, when
scanned, then ZERO references to `simplifiedBalances` exist anywhere
in the new files.

**AC-23 — `notificationPrefs` is the only field written.** Given any
of the controller's writes, when inspected, then ONLY
`notificationPrefs.<key>` and `updatedAt` are in the update payload
— no other fields (`displayName`, `photoUrl`, `fcmTokens`, `locale`)
are touched by the new writer.

---

## Telemetry Contract (FR-PR-03 + FR-AC-04 v1.0)

Three NEW client events. All three are **pre-declared** in
`docs/design/07-technical/telemetry-plan.md` lines 204-206 — no
telemetry-plan edit is required in this PR.

| Event | Trigger | Parameters | Types |
|---|---|---|---|
| `notification_prefs_viewed` | Screen mounted (single-fire per session — mirror of `friend_detail_viewed` per PR #42) | — | — |
| `notification_pref_changed` | Successful Firestore persist after debounce (NOT on tap — mirror of `settlement_recorded` per PR #43) | `category`, `enabled` | `string` (∈ `{newExpense, settlement, reminder}`), `bool` |
| `notification_pref_error` | Failed Firestore persist | `category`, `error_code` | `string`, `string` (∈ `{firestore-error, network, unknown}` per `lib/features/expenses/application/expense_telemetry.dart` taxonomy) |

**PII guard (ADR-0013):** NONE of the three events carry UID-derived
parameters. The user is implicit (they own the document being
mutated); the friendship-id surface is irrelevant on the preferences
screen. **No hashing is required** because no hashable identifiers
are emitted. AC-20 asserts this defence-in-depth via the PII-leak
grep.

The constants live in `lib/features/profile/application/notification_preferences_telemetry.dart`
(mirror of `lib/features/reminders/application/reminder_telemetry.dart`).
The controller emits via the existing `analyticsServiceProvider`.

---

## Invariant Compliance

| Invariant | Applicability | How enforced |
|---|---|---|
| **1 — paise integers** | **N/A** | No monetary values flow through any new code path. The notification-preferences surface mutates a `Map<String, bool>` only. Defence-in-depth grep at `test/features/profile/notification_preferences_boundary_contract_test.dart` asserts ZERO `.toDouble()` / `parseFloat` / `/100` / `.toFixed` / `double`-declaration matches in the new `lib/features/profile/**` files (AC-21). |
| **2 — `simplifiedBalances` server-only** | **N/A** | No `simplifiedBalances` access on any new code path. Defence-in-depth grep asserts ZERO references in the new files (AC-22). |
| **3 — system share sheet only** | **N/A** | No outbound sharing on this surface. |
| **4 — single Firebase project** | **Defence-in-depth — fresh applicability via `cloud_functions` wiring** | `FirebaseFunctions.instanceFor(region: 'asia-south1')` MUST resolve to the same default Firebase app initialised at `lib/main.dart:25-27`. `.firebaserc` UNCHANGED (still contains exactly one project ID). CI gate green. The emulator-side `useFunctionsEmulator(host, 5001)` call mirrors the existing Firestore/Storage/Auth emulator wiring at `lib/main.dart:36-50` and uses the same `host` constant. |

---

## Out of Scope

These are explicitly EXCLUDED to keep PR #55 surgical. Each item
has an architect-ratified deferral rationale:

- **FR-PR-02 phone-number-change flow** — separate P1 story; depends
  on OTP re-verification. Will be filed as a follow-up issue.
- **FR-PR-05 Contact Support `mailto:` flow** — separate P0 story;
  depends on Remote Config wiring. Will be filed as a follow-up
  issue.
- **FR-AU-09 account-deletion flow** — separate P1 story; depends on
  a new Cloud Function.
- **`shared_preferences` adoption** — defer until a third consumer
  needs it (pairs with PR #53 §2.6 `wasPermanentlyDenied` flag and
  PR #54 §2.6 cooldown persistence). Will be filed as a follow-up
  tracker.
- **`OBTBottomNav` shell** — still deferred per PR #52 §2.1. UX
  foundation; top candidate for PR #56.
- **Activity-writer rename cleanup** — still deferred per PR #52
  §2.3. Cosmetic.
- **`OBTRupeeText` primitive** — still deferred per PR #52 §2.6. No
  second-use-site precedent yet.
- **`cloud-functions-catalogue.md §7` docs roll-up** — separate
  cosmetic chore PR per PR #54 §2.10.
- **FR-SE-09 message-compose dialog follow-up** — separate UX PR per
  FR-SE-09 §2.5.
- **Per-group notification override** — SCR-27 §Open Question 1;
  v1.1.
- **Reminder-frequency configurator** — SCR-27 §Open Question 2;
  v1.1.
- **Per-toggle Android notification-channel mapping** — SCR-27 §Open
  Question 3; v1.1.
- **Issue #47 rules-hardening** — separate small chore PR.
- **Issue #49 orphan-cleanup** — FUTURE.
- **Issue #50 trigger no-op-recompute optimisation** — **EXPLICITLY
  CONSTRAINED** by FR-EX-07 AC-2; closing it would break activity
  emission on receipt-only updates.
- **FR-SE-08 dedicated settlement-history screen** — separate P0
  story. Will be filed as a follow-up issue.
- **OAuth / SSO** — not in v1.0 per SRS §12.3.
- **`ReminderCallableException` ↔ `CloudFunctionException`
  harmonisation** — cosmetic; defer per architect §2.10 reconciliation
  2.
- **Fourth `notificationPrefs.groupInvite` key** — defer to the
  Sprint 3 groups epic; requires a migration for existing user docs.

If an agent suggests bundling any of the above into PR #55, refuse
and cite this section.

---

## Architect-Call Sub-Questions (for Phase 2)

Enumerated for the architect agent to ratify in §2.1–§2.10 of the
forthcoming Architect Notes appendix:

- **§2.1 Debounce strategy.** Per-toggle 500 ms debounce vs single
  global debounce. **PM recommendation:** per-toggle. Each toggle
  key (`newExpense`, `settlement`, `reminder`) gets its own `Timer`
  field on the controller; flipping the SAME toggle resets THAT
  toggle's timer; flipping a DIFFERENT toggle starts ITS OWN timer
  without affecting the others. Drives AC-5 + AC-6.
- **§2.2 Dot-path partial-update writer shape.** Dot-path
  `{'notificationPrefs.<key>': value}` vs full-map
  `update({'notificationPrefs': {...}})`. **PM recommendation:**
  dot-path partial-map with dirty keys only. Avoids the race where
  two in-flight writes overwrite each other's untouched keys.
  Drives AC-3 + AC-17 + AC-23.
- **§2.3 State sealed hierarchy placement.** In-file with the
  controller (mirror of `SendReminderController`) vs separate
  `notification_preferences_state.dart` file (mirror of
  `SettleUpState`). **PM recommendation:** in-file. 3 states
  (`NotificationPreferencesLoading` / `NotificationPreferencesError`
  / `NotificationPreferencesReady({required Map<String, bool> prefs,
  required Set<String> savingKeys})`). Per-key in-flight indicator
  via `savingKeys` set inside `Ready` rather than a separate
  hierarchy state.
- **§2.4 OS-permission "Open Settings" implementation.**
  `FirebaseMessaging.instance.openAppNotificationSettings()`
  cross-platform vs platform-specific (`app_settings` package or
  method-channel into `UIApplication.openSettingsURLString`).
  **PM recommendation:** prefer `firebase_messaging.openAppNotificationSettings()`
  if it works on both platforms in `firebase_messaging: ^16.2.0`.
  **Fallback:** if one platform lacks support, ship the banner
  without the button on the unsupported platform (graceful
  degradation; file a follow-up tracker). The banner itself ships
  regardless. Drives AC-11.
- **§2.5 Adapter file placement.** **PM recommendation:**
  - `lib/features/reminders/data/reminder_callable_adapter.dart` —
    `cloud_functions` → `ReminderCallable` shim translating
    `FirebaseFunctionsException` to `ReminderCallableException`.
  - `lib/features/friends/data/matching_callable_adapter.dart` —
    `cloud_functions` → `LookupCallable` shim translating
    `FirebaseFunctionsException` to the existing
    `CloudFunctionException` (per PR #34 backwards compat).
  Both are Firebase-SDK-binding shims; the repositories stay
  Firebase-SDK-free.
- **§2.6 `cloud_functions` version pin.** Verify the latest stable
  major version on pub.dev at kickoff (likely 5.x or 6.x as of June
  2026). **PM recommendation:** latest STABLE only; major version
  MUST match `firebase_core: ^4.7.0` for SDK compatibility. If a
  major-version mismatch is unavoidable, escalate to a coordinated
  Firebase-SDK bump in a separate chore PR.
- **§2.7 `ProviderScope` override placement.** **PM recommendation:**
  in `lib/main.dart`, wrap the existing
  `ProviderScope(child: OneBytwoApp())` with two overrides exactly —
  `reminderRepositoryProvider.overrideWithValue(...)` and
  `matchingRepositoryProvider.overrideWithValue(...)`. Production-
  only; emulator builds get the same overrides plus the
  `useFunctionsEmulator` call BEFORE `runApp`.
- **§2.8 Exhaustive files-to-touch list.** Per §5 of the
  orchestrator brief (lines 53-79) — the architect MUST enumerate
  the full list verbatim in the Architect Notes appendix so QA can
  diff-check at review time. Anything outside the enumerated set is
  scope creep.
- **§2.9 Negative scope guardrails.** Files explicitly NOT to touch
  per spec §204-212 — `firestore.rules`, `firestore.indexes.json`,
  `storage.rules`, `functions/package.json`, all of
  `functions/src/**`, all FR-AC-03 / FR-SE-09 / FR-PR-01 surfaces
  (except the new adapter files in `reminders/data/` and
  `friends/data/`), `.github/workflows/*.yml`, `docs/design/**`.
- **§2.10 Anticipated reconciliations.** The 5 items per spec
  §214-220:
  1. `profile_placeholder_screen.dart` dead-code check (file a
     cleanup follow-up if dead; do NOT delete in this PR).
  2. `ReminderCallableException` ↔ `CloudFunctionException` parallel
     classes — keep both as-is; defer the harmonisation.
  3. `firebase_messaging.openAppNotificationSettings()` cross-
     platform availability check at kickoff; fallback per §2.4.
  4. Fourth `notificationPrefs.groupInvite` key deferral — document
     the constraint that future additions require a migration.
  5. `_useEmulator` constant emulator-functions wiring MUST mirror
     the existing Firestore/Storage/Auth pattern at
     `lib/main.dart:36-50`.

---

## Definition of Done

- All 23 ACs (AC-1 ... AC-23) satisfied with passing tests.
- Story (this file) + Architect Notes (Phase 2) appended.
- `dart format --set-exit-if-changed .` exits 0.
- `flutter analyze --fatal-infos` exits 0 ("No issues found").
- `flutter test` exits 0; expected ~1117 → ~1147 tests after the
  new screen + controller + adapter + repository-extension + boundary-
  contract test additions.
- `cd functions && npm run lint && npm run build && npm test` exits 0
  (319 / 22 suites — **UNCHANGED**; zero Functions source changes
  in this PR).
- `cd functions && npm run test:rules` exits 0 (188 + 3 = 191 tests
  across 9 suites; the 3 new tests cover AC-17 / AC-18 / AC-19 on
  the partial-map `notificationPrefs.<key>` update path).
- `flutter pub get` succeeds after the `cloud_functions` dependency
  is added; `pubspec.lock` regenerated and committed.
- AC-20 PII-leak grep clean (no `userId` / `uid` / `friendship_id` /
  `friendship_id_hash` in the three new telemetry events).
- AC-21 Inv-1 negative-guard grep clean (zero `.toDouble()` /
  `parseFloat` / `/100` / `.toFixed` / `double`-declaration matches
  in `lib/features/profile/**` new files).
- AC-22 Inv-2 negative-guard grep clean (zero `simplifiedBalances`
  references in the new files).
- Manual smoke matrix per Phase 5 §10 of the orchestrator brief
  (lines 301-310) executed by QA:
  - Cross-device prefs round-trip (A toggles Reminders OFF → B's
    send-reminder rejected with `RECIPIENT_PREFS_DISABLED` → A
    flips back ON → B's send succeeds).
  - Offline-toggle queue persistence and snackbar single-fire-per-
    session behaviour.
  - OS-permission banner + "Open Settings" deep-link verified on
    both iOS and Android (architect §2.4 fallback if applicable).
  - Rapid same-toggle debounce collapse (4 flips within 200 ms → 1
    write).
  - Per-toggle isolation (toggle A flipped, then toggle B 100 ms
    later → toggle A's write fires before toggle B's debounce
    completes).
  - QA re-verifies the FR-SE-09 round-trip end-to-end with the REAL
    `cloud_functions` SDK (the first time the production callable
    is exercised from a real device — PR #54 used the
    `throw UnimplementedError` provider for tests).
- `docs/sprint-zero/sprint-2-plan.md` rolled forward with the PR
  #55 row (5 SP; cumulative 84 SP across 19 PRs).
- `docs/sprint-zero/next-three-prs.md` rolled forward (PR #55
  marked merged; PR #56 / #57 / #58 candidates per Phase 7).
- `docs/audits/sprint-1/07-bucket-b-burndown.md` PR #55 entry
  appended (closes no Bucket-B items directly; partial PY3 progress
  via new tests).
- PR title scope is single-token (`profile`) and subject ≤ 72
  characters total. Suggested: `feat(profile): FR-PR-03+FR-AC-04
  notification prefs UI` (54 chars).
- PR body cites SCR-27 + `telemetry-plan.md` §1.x + the relevant
  SRS rows (FR-PR-03 + FR-AC-04), confirms Invariants 1 / 2 / 3 / 4
  (only Invariant 4 has fresh applicability via the `cloud_functions`
  wiring), enumerates the deferred items, and ends with
  `Next PR: PR #56 — TBD per architect's call at kickoff (top
  candidate: OBTBottomNav shell).`
- DoD checklist §7 invariant compliance verified in PR body.

---

## Follow-up Issues to File After Merge

The Phase 7 PM agent files (or notes in `next-three-prs.md`) the
following candidate issues once PR #55 is squash-merged:

1. **FR-PR-02 phone-number-change flow** — P1 story; depends on OTP
   re-verification flow.
2. **FR-PR-05 Contact Support `mailto:` flow** — P0 story; depends
   on Remote Config wiring for the support email address.
3. **`shared_preferences` adoption tracker** — cross-feature chore;
   consolidates the deferred PR #53 §2.6 `wasPermanentlyDenied` flag
   and PR #54 §2.6 cooldown persistence into a focused PR once a
   third consumer surfaces.
4. **`OBTBottomNav` shell** — UX foundation deferred from PR #52
   §2.1; canonical entry point for Friends / Groups / Activity /
   Profile cluster; needed before the Sprint 3 groups epic.
5. **FR-SE-08 dedicated full-history settlement screen** — P0 story
   at `/settlements/history`; in-timeline rows satisfy v1.0 but the
   dedicated screen is still backlog.

These are tracked as candidates; the orchestrator decides which (if
any) are filed as GitHub issues at PR-#55 merge time.

---

## Architect Notes

This section formally ratifies the ten architect calls (§2.1–§2.10)
enumerated in the "Architect-Call Sub-Questions" section above. The
implementing Flutter-dev MAY treat every paragraph below as a binding
contract for PR #55 — each ratification either CONFIRMS the PM's
recommendation with concrete technical detail, or substitutes a
verified pattern from the actual source files at the PR #55 kickoff
SHA. Where this section conflicts with an unverified sketch in the
Phase-2 hand-off (notably the `MatchingRepository` constructor
parameter name in §2.7 and the boundary-contract test scope in
"Additional emphases"), THIS section is authoritative.

### §2.1 Debounce strategy

**RATIFIED: per-toggle 500 ms debounce.** Each toggle key
(`newExpense`, `settlement`, `reminder`) owns its OWN `Timer` field
on the controller. Flipping the SAME toggle CANCELS that key's
pending timer and starts a fresh one. Flipping a DIFFERENT toggle
starts ITS OWN timer without touching the others. Rapid same-toggle
flips (AC-6) collapse to a single Firestore write with the final
state. Independent flips across toggles (AC-5) fire at independent
times.

**REJECTED: a single global debounce.** It would lag a flip of
toggle A behind an unrelated flip of toggle B, violating AC-5.

**Storage shape on the controller:**

```dart
final Map<String, Timer?> _debounceTimers = {};

void _scheduleWrite(String category, bool value) {
  _debounceTimers[category]?.cancel();
  _debounceTimers[category] = Timer(
    const Duration(milliseconds: 500),
    () => _flush(category, value),
  );
}
```

**Dispose hygiene:** the controller MUST cancel every entry in
`_debounceTimers` in its `dispose()` override before clearing the
map — mirror of the `SendReminderController` cleanup pattern.

### §2.2 Dot-path partial-update writer shape

**RATIFIED: a single `update()` with dot-path entries plus a
server-timestamped `updatedAt`.** The new method
`UserRepository.updateNotificationPrefs({required String uid,
required Map<String, bool> prefs})` mirrors the existing
`updateProfile` shape at
`lib/features/auth/data/user_repository.dart:80-96` — same
`<String, dynamic>` map type, same `_firestore.collection('users')
.doc(uid).update(updates)` call site.

**Reference implementation:**

```dart
Future<void> updateNotificationPrefs({
  required String uid,
  required Map<String, bool> prefs,
}) async {
  assert(prefs.isNotEmpty, 'prefs map must contain at least one key');
  final updates = <String, dynamic>{
    for (final entry in prefs.entries)
      'notificationPrefs.${entry.key}': entry.value,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  await _firestore.collection('users').doc(uid).update(updates);
}
```

Only DIRTY keys appear in the `prefs` parameter — the writer NEVER
sends untouched keys. Concurrent in-flight writes NEVER overwrite
each other's untouched keys because Firestore dot-path semantics
merge each entry into the existing `notificationPrefs` map field
without touching siblings.

**REJECTED: the legacy full-map shape**
`update({'notificationPrefs': {...}})`. Two in-flight writes would
race: the later one wins, silently clobbering the earlier one's
mutation on any key it did not touch.

**Rules-layer safety (cross-reference `firestore.rules:72-99`):**
`isValidUserUpdate` re-validates the post-merge
`request.resource.data.notificationPrefs` against
`isValidNotificationPrefs` on EVERY update. Because Firestore
evaluates rules against the merged document (the existing map plus
the dot-path mutation), and because FR-AU-06 / PR #10 guarantees
every user doc has the fully-shaped map at creation, the
partial-map path satisfies `hasAll(['newExpense', 'settlement',
'reminder'])` automatically. AC-17 / AC-18 / AC-19 are
defence-in-depth proofs of this contract.

### §2.3 State sealed hierarchy placement

**RATIFIED: in-file with the controller.** The single file
`lib/features/profile/application/notification_preferences_controller.dart`
holds both the `NotificationPreferencesController` (a Riverpod 2.x
`AutoDisposeNotifier`) and the sealed state hierarchy below it.
Mirror of
`lib/features/reminders/application/send_reminder_controller.dart`
which colocates `SendReminderState` with `SendReminderController`.

**Three states (sealed hierarchy):**

- `NotificationPreferencesLoading` — initial state during the
  `users/{uid}.get()` read. Renders the screen's
  `CircularProgressIndicator`.
- `NotificationPreferencesError({required String message})` —
  on read failure. Renders `OBTErrorState` per AC-8 with a Retry
  button that re-issues the read.
- `NotificationPreferencesReady({required Map<String, bool>
  prefs, required Set<String> savingKeys})` — populated state.
  `prefs` is mutated in-place for optimistic updates (per AC-4);
  `savingKeys` tracks per-key in-flight writes — the controller
  adds a key on debounce-flush and removes it on persist
  resolution (success or failure). The UI MAY render a subtle
  per-row indicator (e.g. trailing spinner) when a key is in
  `savingKeys`, though v1.0 is allowed to omit this indicator.

**REJECTED: a separate `notification_preferences_state.dart`
file.** The state hierarchy is small (three cases, no draft
model) and there is no second consumer of the state classes. The
per-key "saving" indicator lives INSIDE the `Ready` state as a
`Set<String>`, NOT as a separate hierarchy variant — a separate
`Saving` variant would require state copying on every per-key
transition and would not compose with `Ready`'s `prefs` map.

### §2.4 OS-permission "Open Settings" implementation

> **Superseded by ADR-0019 (AC-11 "Open Settings" CTA chore, PR ≥ #70).**
> The interim decision below shipped the banner WITHOUT the button because
> `FirebaseMessaging.instance.openAppNotificationSettings()` does not exist
> on the installed `firebase_messaging` Dart API and §2.4 REJECTED pulling a
> new plugin in the 5-SP PR #55 scope. The follow-up chore reverses that: it
> adds `app_settings` behind a shared `lib/core/services/AppSettingsService`
> seam and wires the "Open Settings" button on both the SCR-27 banner and the
> SCR-10 contact-permission view. The banner copy and its
> `denied || permanentlyDenied` trigger (below) are unchanged.

**RATIFIED: use `FirebaseMessaging.instance.openAppNotificationSettings()`
from the EXISTING `firebase_messaging: ^16.2.0`** (pubspec.yaml
line 19 — no version bump). The Flutter-dev MUST verify at
implementation kickoff:

1. The method signature exists in the installed version — confirm
   via the `firebase_messaging` package source or the pub.dev API
   docs (grep of `lib/` confirms the API is NOT yet used anywhere
   in this codebase, so this is a first-use).
2. Both iOS and Android implementations route correctly — Android
   should open `Settings.ACTION_APP_NOTIFICATION_SETTINGS`; iOS
   should open `UIApplication.openSettingsURLString`.

**Fallback ladder (graceful degradation):**

- BOTH platforms support the API → ship the "Open Settings"
  button on both.
- ONLY ONE platform supports the API → ship the button on the
  supported platform; ship the banner copy alone on the
  unsupported platform; file a follow-up issue tracking the
  deep-link gap.
- NEITHER platform supports the API → file a follow-up issue;
  ship the banner without the button on both platforms.

The banner ITSELF (copy verbatim: "Notifications are turned off
for this app. Enable them in your device settings to receive
alerts.") SHIPS regardless of the API-check outcome — AC-11
demands the banner; the button is a graceful-degradation
extension. The banner triggers when
`NotificationPermissionController` reports `denied` OR
`permanentlyDenied` (per the enum at
`lib/features/notifications/application/notification_permission_controller.dart:30-36`).

**REJECTED: pulling `app_settings` or `permission_handler` as
new pubspec dependencies.** Those are separate scope chores;
the goal of PR #55 is to land FR-PR-03 + FR-AC-04 +
`cloud_functions` wiring in 5 SP, not to grow the dependency
graph for an OS-deep-link convenience. The fallback ladder
preserves AC-11 without the new dependency.

### §2.5 Adapter file placement

**RATIFIED: two new files, both pure Firebase-SDK-binding shims**
with zero business logic. The repository classes
(`ReminderRepositoryImpl` at
`lib/features/reminders/data/reminder_repository.dart:81-132` and
`MatchingRepository` at
`lib/features/friends/data/matching_repository.dart:78-106`) stay
Firebase-SDK-free — they remain importable in pure-Dart unit tests
with no Firebase initialisation.

**File 1 — `lib/features/reminders/data/reminder_callable_adapter.dart`:**

- Constructor takes the `cloud_functions` `HttpsCallable` instance
  pointing at `sendReminderNotification` in region `asia-south1`.
- Exposes a `Future<Map<String, dynamic>> call(Map<String, dynamic>
  params)` method matching the `ReminderCallable` typedef at
  `reminder_repository.dart:17-18` (note: `Map<String, dynamic>`,
  NOT `Map<String, Object?>`).
- Translates `FirebaseFunctionsException(code, message, details)`
  to `ReminderCallableException(code: e.code, errorCode:
  (e.details as Map?)?['errorCode'] as String? ?? 'UNKNOWN',
  nextAllowedAtIso: (e.details as Map?)?['nextAllowedAtIso'] as
  String?)` per the field shape at `reminder_repository.dart:25-46`.
- Any NON-`FirebaseFunctionsException` (`PlatformException`,
  `TimeoutException`, etc.) is re-thrown UNCHANGED. The
  repository's `on Exception` branch at
  `reminder_repository.dart:128-130` catches it and yields
  `ReminderSendFailed('UNKNOWN')`.

**File 2 — `lib/features/friends/data/matching_callable_adapter.dart`:**

- Constructor takes the `cloud_functions` `HttpsCallable` instance
  pointing at `lookupUserByPhoneNumber` in region `asia-south1`.
- Exposes a `Future<Map<String, dynamic>> call(Map<String, dynamic>
  params)` method matching the `LookupCallable` typedef at
  `matching_repository.dart:4-5`.
- Translates `FirebaseFunctionsException(code, message, details)`
  to the EXISTING `CloudFunctionException(code: e.code, details:
  (e.details as Map?)?['errorCode'] as String? ?? e.code)`. **Note
  the shape: `CloudFunctionException.details` is a single `String`
  (not a Map)** — see `matching_repository.dart:8-20`. The adapter
  populates it from `e.details['errorCode']` (the server-side
  `HttpsError` details key) and falls back to `e.code` if the
  details map is absent. This matches how
  `MatchingRepository.lookupUser` consumes the field at
  `matching_repository.dart:99-101`
  (`if (e.details == 'RATE_LIMITED')`).
- DO NOT rename `CloudFunctionException` to a shared base in this
  PR — §2.10 reconciliation 2 keeps both exception classes as-is.

### §2.6 `cloud_functions` version pin

**RATIFIED: pin to the latest STABLE major version on pub.dev as
of PR #55 kickoff.** NEVER a beta, RC, or pre-release.

**Flutter-dev procedure:**

1. Run `flutter pub add cloud_functions` — picks the latest
   stable automatically.
2. Inspect the resolved version in `pubspec.lock`.
3. Confirm the major aligns with the existing FlutterFire
   coordinated release line at `pubspec.yaml:12-21`:
   `cloud_firestore: ^6.3.0`, `firebase_auth: ^6.4.0`,
   `firebase_core: ^4.7.0`, `firebase_messaging: ^16.2.0`,
   `firebase_remote_config: ^6.4.0`, `firebase_storage:
   ^13.3.0`. The `cloud_functions` plugin's major version moves
   in lockstep with the rest of the FlutterFire suite — for the
   current line (`firebase_core: ^4.x`) the resolved version is
   most likely `cloud_functions: ^6.x`.
4. If the resolved major MATCHES the suite line → pin with
   caret (`^X.Y.Z`) in `pubspec.yaml`, commit `pubspec.lock`,
   proceed.
5. If the resolved major DOES NOT match → **STOP.** A coordinated
   Firebase-SDK bump is a separate chore PR (it would touch every
   Firebase plugin's pubspec entry and force a full smoke
   regression). Surface the friction back to the orchestrator;
   do NOT silently bump the whole suite inside PR #55 — that
   would blow the 5-SP envelope.

**REJECTED:** pinning to a beta or RC; pinning to an exact patch
(`X.Y.Z` without caret) on a non-breaking line.

### §2.7 `ProviderScope` override placement

**RATIFIED: in `lib/main.dart`, REPLACE line 52
(`runApp(const ProviderScope(child: OneBytwoApp()));`) with a
`ProviderScope` carrying exactly two overrides.** ALSO add a single
`useFunctionsEmulator` call inside the existing `_useEmulator`
block at lines 34-51, placed AFTER the Storage emulator wiring at
lines 45-47 and BEFORE the "FCM emulator is NOT part of..." comment
at lines 48-50.

**Verified constructor signatures (Flutter-dev MUST use exactly
these param names):**

- `ReminderRepositoryImpl({required ReminderCallable callable})`
  — param name is **`callable`**. See
  `lib/features/reminders/data/reminder_repository.dart:83`.
- `MatchingRepository({required LookupCallable lookupCallable})`
  — param name is **`lookupCallable`** (NOT `callable`; the
  Phase-2 hand-off sketch had this wrong). See
  `lib/features/friends/data/matching_repository.dart:80`.

**Verified callable export names:**

- `sendReminderNotification` — exported at
  `functions/src/index.ts:43` (FR-SE-09 callable, region
  `asia-south1`).
- `lookupUserByPhoneNumber` — exported at
  `functions/src/index.ts:35` (PR #34 matching callable, region
  `asia-south1`).

**Replacement for `lib/main.dart:52`:**

```dart
runApp(
  ProviderScope(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(
        ReminderRepositoryImpl(
          callable: ReminderCallableAdapter(
            FirebaseFunctions.instanceFor(region: 'asia-south1')
                .httpsCallable('sendReminderNotification'),
          ),
        ),
      ),
      matchingRepositoryProvider.overrideWithValue(
        MatchingRepository(
          lookupCallable: MatchingCallableAdapter(
            FirebaseFunctions.instanceFor(region: 'asia-south1')
                .httpsCallable('lookupUserByPhoneNumber'),
          ),
        ),
      ),
    ],
    child: const OneBytwoApp(),
  ),
);
```

**Addition inside the `_useEmulator` block (insert AFTER line 47,
BEFORE the FCM comment at lines 48-50):**

```dart
debugPrint('[OneByTwo] Connecting to Functions emulator $host:5001...');
FirebaseFunctions.instanceFor(region: 'asia-south1')
    .useFunctionsEmulator(host, 5001);
debugPrint('[OneByTwo] Functions emulator connected.');
```

Mirror the EXACT `debugPrint` style at
`lib/main.dart:39/42/45/47`. Note that `useFunctionsEmulator` is
a SYNCHRONOUS void method (no `await`) — same pattern as
`useFirestoreEmulator` at line 43.

**Import additions to `lib/main.dart` (alphabetised per the
existing convention at lines 1-16):**

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:onebytwo/features/friends/data/matching_callable_adapter.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/reminders/data/reminder_callable_adapter.dart';
import 'package:onebytwo/features/reminders/data/reminder_repository.dart';
```

### §2.8 Exhaustive files-to-touch list (PR diff scope)

The PR #55 diff MUST contain exactly the files below. Anything
outside this list is scope creep and must be challenged at QA
diff review.

**Documentation:**

- `docs/sprint-zero/stories/FR-PR-03-FR-AC-04-notification-preferences.md`
  (NEW — created by PM commit `61be1b1`; this `## Architect Notes`
  appendix lands in a follow-up commit on the same branch).
- `docs/sprint-zero/sprint-2-plan.md` (EXTEND — append the PR #55
  row).
- `docs/sprint-zero/next-three-prs.md` (EXTEND — roll PR #55 to
  merged; surface PR #56 / #57 / #58 candidates).
- `docs/audits/sprint-1/07-bucket-b-burndown.md` (EXTEND —
  header timestamp + PR #55 entry).
- `docs/copilot_prompts/sprint_2/18.md` (NEW — already committed
  in prep commit `9ba9503`).

**Flutter source (NEW):**

- `lib/features/profile/application/notification_preferences_telemetry.dart`
- `lib/features/profile/application/notification_preferences_controller.dart`
  (includes the in-file sealed state hierarchy per §2.3)
- `lib/features/profile/presentation/notification_preferences_screen.dart`
- `lib/features/reminders/data/reminder_callable_adapter.dart`
- `lib/features/friends/data/matching_callable_adapter.dart`

**Flutter source (EXTEND):**

- `lib/features/auth/data/user_repository.dart` — ADD the
  `updateNotificationPrefs({required String uid, required
  Map<String, bool> prefs})` method per §2.2.
- `lib/features/profile/presentation/profile_screen.dart` lines
  317-333 — swap the `onTap` snackbar at lines 327-331 for a
  `Navigator.of(context).push(MaterialPageRoute<void>(builder:
  (_) => const NotificationPreferencesScreen()))`. The
  `Semantics` wrapper, label, icon, trailing chevron, and the
  enclosing `_ProfileRow` are UNCHANGED.
- `lib/main.dart` — wrap `ProviderScope` with two overrides per
  §2.7; add `useFunctionsEmulator` under `_useEmulator`; add
  the five new imports per §2.7.

**Pubspec:**

- `pubspec.yaml` — ADD `cloud_functions: ^X.Y.Z` per §2.6
  (alphabetical position between `cloud_firestore` and `crypto`).
- `pubspec.lock` — REGENERATED via `flutter pub get`.

**Flutter tests (NEW):**

- `test/features/profile/notification_preferences_controller_test.dart`
- `test/features/profile/notification_preferences_screen_test.dart`
- `test/features/profile/notification_preferences_boundary_contract_test.dart`
  (Inv-1 + Inv-2 + PII-leak greps; scope per the narrowing
  rationale in "Additional emphases" below)
- `test/features/reminders/data/reminder_callable_adapter_test.dart`
- `test/features/friends/data/matching_callable_adapter_test.dart`

**Flutter tests (EXTEND):**

- `test/features/auth/user_repository_test.dart` — ADD
  `updateNotificationPrefs` writer tests (dot-path partial-map
  merge assertion + `updatedAt` server timestamp assertion).

**Functions tests (EXTEND):**

- `functions/test/firestore-rules/users-update.test.ts` — ADD a
  new `describe("users/{userId} — notificationPrefs updates",
  ...)` block with three tests covering AC-17 / AC-18 / AC-19.

### §2.9 Negative scope guardrails (files NOT to touch)

The following paths MUST remain UNCHANGED in the PR #55 diff. CI
diff review at PR open should reject any deviation.

- **`firestore.rules`** — the existing `isValidUserUpdate` (lines
  72-91) + `isValidNotificationPrefs` (lines 93-99) cover the new
  partial-map path automatically. The three new rules tests in
  `users-update.test.ts` are the defence-in-depth proof that the
  existing rules behave correctly on the new write shape.
- **`firestore.indexes.json`** — UNCHANGED.
- **`storage.rules`** — UNCHANGED.
- **`functions/package.json`** — UNCHANGED.
- **All of `functions/src/**`** — UNCHANGED. PR #55 ships ZERO
  new server-side code. The FR-AC-04 server-side filter (PR #53)
  and the FR-SE-09 callable's `RECIPIENT_PREFS_DISABLED` branch
  (PR #54) already consume `notificationPrefs.*` correctly.
- **All `functions/test/**` EXCEPT the `users-update.test.ts`
  extension** — UNCHANGED.
- **`lib/features/expenses/**`, `lib/features/settlements/**`,
  `lib/features/activity/**`, `lib/features/notifications/**`
  (FR-AC-03 surface stable), `lib/features/reminders/**` (FR-SE-09
  surface stable EXCEPT the new adapter file),
  `lib/features/friends/**` (PR #34 surface stable EXCEPT the
  new adapter file)** — UNCHANGED.
- **`lib/features/auth/domain/user_model.dart`** — UNCHANGED.
  The schema is fine; only the writer extends.
- **`lib/features/auth/presentation/{home_placeholder_screen,
  profile_setup_screen, otp_entry_screen, phone_entry_screen,
  splash_screen, authenticated_screen}.dart`** — UNCHANGED.
- **`lib/features/profile/presentation/{edit_profile_screen,
  profile_placeholder_screen}.dart`,
  `lib/features/profile/application/edit_profile_controller.dart`,
  `lib/features/profile/presentation/widgets/photo_picker_sheet.dart`**
  — UNCHANGED.
- **`.github/workflows/*.yml`** — UNCHANGED.
- **`docs/design/**`** — read-only references; NO spec updates in
  this PR. The three new telemetry events
  (`notification_prefs_viewed`, `notification_pref_changed`,
  `notification_pref_error`) are ALREADY pre-declared at
  `docs/design/07-technical/telemetry-plan.md:204-206`.

### §2.10 Anticipated reconciliations

1. **`profile_placeholder_screen.dart` dead-code check.** The file
   lives alongside the real `profile_screen.dart`. The Flutter-dev
   MUST grep `lib/**` for any reference to the placeholder
   class/file. If dead, FILE a follow-up cleanup chore issue;
   do NOT delete the file in PR #55 (deletion is its own
   focused-chore PR).
2. **`ReminderCallableException` vs `CloudFunctionException`
   parallel classes.** Two separate exception classes for two
   callable surfaces. PR #55 keeps both AS-IS (no rename, no
   harmonisation). A future cosmetic chore PR MAY unify them
   under a shared `CloudFunctionFailure` base — that work is
   explicitly deferred per the §2.5 ratification.
3. **`firebase_messaging.openAppNotificationSettings()` cross-
   platform availability.** Verify at kickoff per §2.4. If only
   one platform supports the API, ship the banner without the
   button on the unsupported platform (graceful degradation) and
   file a follow-up issue tracking the deep-link gap.
4. **Future fourth `notificationPrefs.groupInvite` key (Sprint 3
   groups epic).** The `notificationPrefs` map currently has
   exactly three keys. If a future story adds a fourth key (e.g.
   `groupInvite` for the Sprint 3 groups feature),
   `firestore.rules:93-99` `isValidNotificationPrefs` will reject
   EVERY existing user doc on the next update — because
   `hasAll(['newExpense', 'settlement', 'reminder', 'groupInvite'])`
   would fail until a one-shot migration backfills the new key on
   every existing user doc. NOT in scope for PR #55; documented
   here so the Sprint 3 planner factors a migration step into
   that epic's story-point estimate.
5. **`_useEmulator` Functions-emulator wiring shape.** The
   Functions emulator connection added under `_useEmulator` (per
   §2.7) MUST mirror the existing Firestore / Storage / Auth
   pattern at `lib/main.dart:36-50` exactly: same `host` constant
   (`String.fromEnvironment('EMULATOR_HOST', defaultValue:
   'localhost')`), same `debugPrint` style (`[OneByTwo]
   Connecting to ...` and `[OneByTwo] ... emulator connected.`),
   same call ordering (`Firebase.initializeApp()` first, then
   emulator wiring inside the `_useEmulator` block, then
   `runApp`).

### Additional emphases

- **Boundary contract test scope (narrowed from precedent).** The
  new file
  `test/features/profile/notification_preferences_boundary_contract_test.dart`
  MUST mirror the STRUCTURE of
  `test/features/reminders/reminders_boundary_contract_test.dart`
  (group blocks + per-file scan + `_isCommentLine` helper for
  comment-stripping). However, the SCAN TARGET differs from the
  reminders precedent: instead of recursively walking the entire
  `lib/features/profile/` directory, the test MUST scan ONLY the
  three new files explicitly:
  - `lib/features/profile/application/notification_preferences_telemetry.dart`
  - `lib/features/profile/application/notification_preferences_controller.dart`
  - `lib/features/profile/presentation/notification_preferences_screen.dart`

  **Rationale for the scope narrowing:**
  `lib/features/profile/presentation/profile_screen.dart` already
  contains legitimate layout-related `double` declarations at
  lines 497 (`final double size;`), 518 (`final double width;`),
  and 519 (`final double height;`) for widget sizing fields.
  These are NOT monetary doubles (Invariant 1 governs paise
  integers, not Flutter layout primitives), but a naive recursive
  grep would flag them as Inv-1 violations and fail the test
  spuriously. The three new files are the only place where new
  monetary doubles COULD have been introduced in PR #55, so
  narrowing the scan to that fixed list preserves the
  defence-in-depth intent without false positives. The Inv-1
  grep asserts ZERO matches of `.toDouble()`, `parseFloat`,
  `/ 100` (regex `/\s*100\b` excluding `~/`), `.toFixed`, or
  ` double `/`(double ` declarations. The Inv-2 grep asserts
  ZERO `simplifiedBalances` references. The PII-leak grep
  asserts ZERO literal string matches of `'userId'`, `'uid'`,
  `'friendship_id'`, or `'friendship_id_hash'` (defence-in-depth
  for the three new telemetry events per AC-20). All three greps
  use the same narrowed file list.

- **`hashFriendshipId` is NOT needed.** NONE of the three new
  events (`notification_prefs_viewed`, `notification_pref_changed`,
  `notification_pref_error`) emit a `friendshipId` or any
  UID-composite identifier. The user is implicit — they own the
  document being mutated. No hashing helper from
  `lib/core/telemetry/event_id_hash.dart` is invoked from any new
  file. The PII-leak grep described above is the affirmative gate
  per ADR-0013; no positive-test for a hash output is required
  for PR #55.

- **`describe` block name for the new rules tests.** The three
  new tests in
  `functions/test/firestore-rules/users-update.test.ts` MUST be
  wrapped in a single new
  `describe("users/{userId} — notificationPrefs updates", ...)`
  block (verbatim; the em-dash `—` and the trailing word
  "updates" are part of the canonical name). The three tests
  inside that block:
  - **AC-17** — dot-path partial-map flip
    (`{'notificationPrefs.reminder': false, 'updatedAt':
    serverTimestamp()}`) is ALLOWED.
  - **AC-18** — dot-path partial-map with a non-bool value
    (`{'notificationPrefs.reminder': 'yes', ...}`) is REJECTED.
  - **AC-19** — full-replace dropping a required key
    (`{'notificationPrefs': {newExpense: true, settlement:
    true}, ...}`) is REJECTED.

### Sign-off

The Architect agent RATIFIES all ten calls §2.1 through §2.10
(plus the three additional emphases above) as binding contracts
for PR #55. The implementing Flutter-dev MAY proceed with Phase 4
(test-first cadence per `docs/copilot_prompts/sprint_2/18.md`
lines 263-282) using the ratifications above as the design source
of truth. Any deviation discovered during implementation MUST
come back to the Architect for a follow-up amendment BEFORE the
deviation lands in code, NOT during code review.

— Architect, FR-PR-03 + FR-AC-04 (PR #55), 2026-06-11.
