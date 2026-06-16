# FR-AU-09: Delete Account

> Implementation-ready user story for permanently deleting the signed-in user's
> account through a guarded multi-step flow (warning → re-authentication →
> typed confirmation → processing → success). A new region-pinned callable
> Cloud Function `deleteUserAccount` performs a synchronous Admin SDK cascade:
> it removes personal records, tombstones the user document into a PII-free
> "Deleted User" shell, and preserves all shared data and surviving members'
> balances. Replaces today's "Coming soon" snackbar dead-end and implements
> SCR-28 Part B.

---

## SRS Requirement ID(s)

FR-AU-09 (SRS section 4.1, line 168)

## Priority

**P1 — Should have**

## Story Points

8

## User Story

As a **signed-in user**,
I want to **permanently delete my account through a guarded, re-verified flow**
so that **my personal data and profile are removed while my friends keep the
shared expense history and balances we built together**.

## Preconditions

1. User is authenticated and has a `users/{userId}` document in Firestore
   (FR-AU-06, shipped).
2. The Profile screen exposes a "Delete Account" row, today a dead-end firing a
   `'Coming soon'` snackbar
   (`lib/features/profile/presentation/profile_screen.dart`, lines 387-401).
3. The re-authentication repository `PhoneAccountRepository`
   (`reauthenticate` / `requestOtp` / `currentPhoneNumber`) is available for
   reuse from FR-PR-02 (shipped).
4. A new callable Cloud Function `deleteUserAccount` is deployed to
   `asia-south1` (Architect + Functions Dev dependency) — the sole delete path.
5. The OTP request/verify flow and FR-AU-05 rate limiting are available
   (FR-AU-01..05, shipped).

---

## Acceptance Criteria

### AC-1 — Delete account (happy path, full multi-step flow)

> Given the signed-in user is on the Profile screen
> When they tap the "Delete Account" row and proceed through the
> `/profile/delete-account` flow — Step A warning "Continue", Step B re-verify
> their CURRENT +91 number (request an OTP via `PhoneAccountRepository.requestOtp`
> then enter the correct code so `reauthenticate` succeeds), Step C type `DELETE`
> exactly and tap "Delete My Account", Step D processing
> Then the client calls the `deleteUserAccount` callable (`asia-south1`) with no
> UID argument (the function reads `request.auth.uid`)
> And the function returns success within the 30-second window
> And the Step E success state shows for 3000 ms, after which the navigation
> stack is cleared and the user lands on the Phone Entry screen with no back
> navigation possible
> And server-side the account is gone: the Firebase Auth record is deleted,
> `users/{uid}` is tombstoned to `{ displayName: 'Deleted User', deletedAt }`,
> and `activity/{uid}/items/**`, `_rateLimits/{uid}/**`, and Storage
> `avatars/{uid}` are removed
> And the five happy-path telemetry events fire in order: `delete_account_started`
> → `delete_account_warning_continued` → `delete_account_reauth_completed` →
> `delete_account_confirmed` → `delete_account_completed`

Step B re-authentication is a mandatory step, not an edge case: because FR-AU-07
persists the session, the user must re-verify their current number before this
destructive action. The remaining two declared events
(`delete_account_warning_cancelled`, `delete_account_failed`) are off-path
branch events and do NOT fire on this path (see AC-3 and AC-5).

### AC-2 (Negative) — Wrong OTP at re-authentication

> Given the user has reached Step B and an OTP has been sent to their current
> +91 number
> When they enter an incorrect 6-digit code and `reauthenticate` returns an
> invalid-code error
> Then the `OBTOTPInput` shows its error state with the message "Incorrect code,
> try again."
> And the user remains on Step B and can retry by re-entering the code without
> restarting the flow
> And no `deleteUserAccount` call is made

### AC-3 (Negative) — OTP retry cap exceeded at re-authentication

> Given the user is on Step B and has exhausted the FR-AU-05 retry cap (3
> requests per 10-minute window)
> When they request another OTP
> Then an `OBTSnackbar(type: error)` is shown with the message "Too many
> attempts. Please try again later."
> And the back button remains active so the user can return to Step A and out of
> the flow
> And no `deleteUserAccount` call is made

### AC-4 (Negative) — Confirmation text must match `DELETE` exactly

> Given the user has reached Step C (Final Confirmation) after a successful
> re-authentication
> When the confirmation field contains anything other than the exact string
> `DELETE` (the match is case-sensitive and trimmed of leading/trailing
> whitespace — for example "delete", "Delete", and " DELETE x" all fail)
> Then the "Delete My Account" button stays disabled (`disabled` colour)
> And the `deleteUserAccount` Cloud Function is NOT called until the exact-match
> gate passes

### AC-5 (Negative) — Function failure or 30-second timeout routes to support

> Given the user has confirmed deletion and Step D (Processing) is running
> When the `deleteUserAccount` call returns an error, OR no response arrives
> within the 30-second timeout
> Then the flow navigates back to the Profile View screen (the client does NOT
> assume the account was deleted)
> And an `OBTSnackbar(type: error, actionLabel: "Contact Support")` is shown with
> the message "Account deletion failed. Please try again or contact support.",
> whose action is wired to the FR-PR-05 Contact Support flow
> And a `delete_account_failed` event fires with an `error_code` parameter (no
> PII)

### AC-6 (Negative / Idempotency) — Re-run after a timeout or force-quit resolves cleanly

> Given a prior invocation already completed the cascade server-side (SCR-28 edge
> cases 3 and 4: the client timed out or the app was force-quit during Step D
> while the function finished)
> When `deleteUserAccount` executes again for the same account
> Then the already-deleted Auth user and already-absent Firestore/Storage records
> are treated as success rather than raising an error
> And the function completes cleanly without re-deleting, recomputing, or
> corrupting any preserved shared data
> And the user is not shown a spurious error for an account that is already gone

### AC-7 (Load-bearing / Invariant 2) — Surviving member keeps balances and history

> Given users A and B share a friendship `friendships/{A_B}` with a non-zero
> `simplifiedBalances`, plus expenses, settlements, and receipts
> When user A's account is deleted via `deleteUserAccount`
> Then `friendships/{A_B}` is preserved untouched: `simplifiedBalances` is NEVER
> recomputed, zeroed, or stripped, and the expenses, settlements, and receipts
> remain intact
> And user B continues to see their balance and full shared history
> And user A renders as "Deleted User" wherever a name is shown, because the
> tombstoned `users/{A}` now carries `displayName: 'Deleted User'` and the three
> existing fallback sites already resolve `displayName ?? 'Unknown'`

### AC-8 (Negative / Security) — Client-side deletes stay rejected by Security Rules

> Given a signed-in client with a valid auth token
> When it attempts a Firestore SDK `delete` on its own `users/{uid}` document, or
> on a `friendships/{id}` document it is a member of
> Then the Firestore Security Rules reject both deletes (`allow delete: if
> false`), leaving the Admin SDK inside `deleteUserAccount` as the only delete
> path
> And the documents remain unchanged
> (Verified by Firestore Security Rules unit tests against the emulator in
> `functions/test/firestore-rules`.)

---

## Telemetry Events

All events are PII-free; the `uid` and the phone number must NEVER be a parameter
(SRS section 5.4, line 308). These seven events are already pre-declared in
`docs/design/07-technical/telemetry-plan.md` §1.7 (SCR-28) and the §4.6 Account
Lifecycle funnel — reference them, do not invent new ones.

| Event name | Parameters | Trigger |
|---|---|---|
| `delete_account_started` | — | User taps the "Delete Account" row on Profile View |
| `delete_account_warning_continued` | — | User taps "Continue" on Step A |
| `delete_account_warning_cancelled` | — | User taps "Cancel" on Step A |
| `delete_account_reauth_completed` | — | OTP verified in Step B |
| `delete_account_confirmed` | — | User taps "Delete My Account" in Step C |
| `delete_account_completed` | — | `deleteUserAccount` returns success |
| `delete_account_failed` | `error_code` | `deleteUserAccount` returns an error or times out |

The happy-path funnel (telemetry-plan §4.6) emits `delete_account_started →
delete_account_warning_continued → delete_account_reauth_completed →
delete_account_confirmed → delete_account_completed` in order.
`delete_account_warning_cancelled` (Step A cancel) and `delete_account_failed`
(function error/timeout) are off-path branch events. `error_code` is a
non-identifying classifier only — the `uid` and phone number are never logged
(SRS section 5.4, line 308).

---

## Invariant Applicability Assessment

| # | Invariant / constraint | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. This story has no monetary surface; it neither adds, converts, nor zeroes any balance. |
| 2 | `simplifiedBalances` server-maintained | CRITICAL. The deletion runs server-side so it MAY write Firestore, but it must NOT recompute, zero, or strip `simplifiedBalances` on any preserved `friendships`/`groups` document. Surviving members keep their balances exactly. |
| 3 | System share sheet only | N/A. No sharing in this story. |
| 4 | Single Firebase project | Applicable. The `deleteUserAccount` function, Auth, Firestore, Storage, and rules tests target the single production project `onebytwo-avtanshgupta`; pre-merge testing uses the Firebase Emulator Suite (project `demo-onebytwo`) per ADR-0003. |
| C1 | +91-only authentication (SRS section 3.4, line 133) | Applicable. Step B re-authentication reuses the +91-locked `PhoneAccountRepository`; it never calls `signInWithCredential`. |
| C2 | No PII in telemetry (SRS section 5.4, line 308) | Applicable. No `uid` or phone number may be logged as an event parameter; only a non-identifying `error_code`. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing (step controller, re-auth reuse,
      `DELETE` exact-match gate, timeout handling, error routing).
- [ ] Integration tests passing against the Firebase Emulator Suite (full
      cascade: personal records removed, `users/{uid}` tombstoned, shared data
      preserved, Auth deleted last).
- [ ] `deleteUserAccount` idempotency tested (re-run after timeout/force-quit
      resolves cleanly — AC-6).
- [ ] Firestore Security Rules tests verify AC-8 (client `delete` of
      `users/{uid}` and `friendships/{id}` rejected) in
      `functions/test/firestore-rules`.
- [ ] QA reviewed and verified acceptance criteria (including all negative cases).
- [ ] Telemetry events in place and firing correctly, with no PII parameters (no
      `uid`, no phone number).
- [ ] Accessibility verified (semantic labels per SCR-28, focus order, Step D
      live region, intercepted back during Steps D and E).
- [ ] Dark mode checked (WCAG AA contrast ratios; `danger` surfaces).
- [ ] Invariant compliance confirmed (all four), with Invariant 2 explicitly
      verified, plus the +91-only and PII constraints.
- [ ] Documentation updated if applicable (no new telemetry events — already in
      §1.7 and §4.6; the `deleteUserAccount` contract noted in the technical
      docs).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — compliant; the
      server-side function preserves `simplifiedBalances` and never recomputes,
      zeroes, or strips it.
- [ ] Uses system share sheet only (invariant 3) — N/A.
- [ ] Single Firebase project (invariant 4) — compliant, production only;
      emulator (`demo-onebytwo`) for tests.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Account Deletion screen spec (SCR-28 Part B) | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (Part B: Account Deletion, lines 732-882) |
| Deferred open questions | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-28 Open Questions, lines 877-881) |
| Profile entry point ("Delete Account" row) | `lib/features/profile/presentation/profile_screen.dart` (lines 387-401) |
| Re-authentication pattern (reused from FR-PR-02) | `lib/features/auth/data/phone_account_repository.dart`; story `docs/sprint-zero/stories/FR-PR-02-change-phone-number.md` |
| Contact Support flow (Step D error action) | `docs/sprint-zero/stories/FR-PR-05-contact-support.md` |
| Name-fallback sites (`displayName ?? 'Unknown'`) | `lib/features/activity/presentation/activity_feed_screen.dart`; `lib/features/friends/application/friend_detail_provider.dart`; `lib/features/friends/application/friends_list_provider.dart` |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`users/{userId}`, `friendships/{id}`) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (§1.7 SCR-28; §4.6 Account Lifecycle) |
| Privacy / right-to-delete | SRS section 5.5 (line 318); DPDP 2023 |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Architect | Design the `deleteUserAccount` callable contract and the synchronous cascade order (Firestore → Storage → Auth last); confirm the `users/{uid}` tombstone shape `{ displayName: 'Deleted User', deletedAt }`; confirm Security Rules keep client `delete` at `false`; ADR if needed |
| Functions Dev | Implement `deleteUserAccount` (region `asia-south1`, authenticates `request.auth.uid`, Admin SDK cascade, idempotent re-run, Invariant 2 preservation); Firestore Security Rules tests for AC-8; emulator integration tests |
| Flutter Dev | Multi-step `/profile/delete-account` route and step controller (Steps A–E); reuse `PhoneAccountRepository` for Step B; `DELETE` exact-match gate; 30s timeout and Contact Support routing; replace the "Coming soon" snackbar entry point; telemetry wiring; unit and widget tests |
| QA | Verify all ACs and invariants (especially Invariant 2 preservation and "Deleted User" rendering), idempotency, rules behaviour, accessibility, and telemetry PII-freeness |
| Designer | Confirm SCR-28 Part B copy, `danger` surfaces, and accessibility labels; sign-off |

---

## Implementation Notes

- **Replaces a dead-end.** The Profile "Delete Account" row currently fires a
  `'Coming soon'` snackbar
  (`lib/features/profile/presentation/profile_screen.dart`, lines 387-401). This
  story replaces it with navigation into the multi-step full-screen route
  `/profile/delete-account` (bottom nav hidden), per SCR-28 Part B.
- **Single delete path — `deleteUserAccount` (RESOLVED).** A new callable Cloud
  Function `deleteUserAccount`, region-pinned to `asia-south1`, is the ONLY way
  an account is deleted. It authenticates `request.auth.uid` and performs a
  SYNCHRONOUS cascade via the Admin SDK; clients have no delete path (Security
  Rules keep `allow delete: if false` for `users` and `friendships`).
- **Cascade matrix (RESOLVED).** DELETE personal records —
  `activity/{uid}/items/**`, `_rateLimits/{uid}/**`, Storage `avatars/{uid}`, and
  the Firebase Auth record LAST. TOMBSTONE `users/{uid}` into a PII-free shell
  `{ displayName: 'Deleted User', deletedAt }`, stripping phone, photo, FCM
  tokens, preferences, and locale. PRESERVE shared data untouched: friendships
  where the user is a member, their expenses, settlements, and receipts. The
  surviving member keeps their balance and history.
- **Invariant 2 is load-bearing (RESOLVED).** Because the function runs
  server-side it MAY write Firestore, but it MUST NOT recompute, zero, or strip
  `simplifiedBalances` on any preserved `friendships`/`groups` document. The
  surviving member's balance is left exactly as it was.
- **"Deleted User" vs "Unknown" — no client change (RESOLVED).** The deleted user
  renders as "Deleted User" purely via the tombstone: the three existing
  name-fallback sites already use `displayName ?? 'Unknown'`, so a present
  `displayName: 'Deleted User'` renders "Deleted User", while a genuine
  missing-document read still renders "Unknown". No fallback-site edits are
  required.
- **Re-authentication reuse (RESOLVED).** Step B reuses the FR-PR-02
  `PhoneAccountRepository` (`reauthenticate` / `requestOtp` /
  `currentPhoneNumber`) against the user's CURRENT +91 number. It must NEVER call
  `signInWithCredential`. FR-AU-05 rate limiting (3 per 10-minute window)
  applies.
- **"30 days" = synchronous hard-delete now (RESOLVED).** The function performs
  the deletion synchronously on invocation; the scheduled-cleanup reaper implied
  by the SRS "within 30 days" wording is deferred. The SCR-28 success and warning
  copy retain the "within 30 days" language as the user-facing promise (SRS
  section 5.5, line 318).
- **Idempotency is mandatory (RESOLVED).** Step order is Firestore → Storage →
  Auth LAST so a re-run after a client timeout or force-quit (SCR-28 edge cases 3
  and 4) resolves cleanly: an already-deleted Auth user and already-absent
  documents are treated as success, never an error.
- **No new client dependency.** `firebase_auth` and the Cloud Functions SDK are
  already dependencies; no new plugin and no `ios/Podfile.lock` change are
  needed.

---

## Out of Scope

- **SCR-28 Open Question 1 — grace period / undo window.** Deferred to a future
  follow-up issue. v1.0 deletion is immediate and irreversible (SCR-28 Open
  Questions, line 879).
- **SCR-28 Open Question 2 — deletion confirmation SMS.** Deferred to a future
  follow-up issue; v1.0 sends no post-deletion SMS (SCR-28 Open Questions,
  line 880).
- **SCR-28 Open Question 3 — deletion audit log.** Deferred to a future follow-up
  issue; no separate admin-facing audit collection in v1.0 beyond
  Analytics/Crashlytics (SCR-28 Open Questions, line 881).
- **Scheduled-cleanup reaper.** The "within 30 days" background sweep is deferred;
  v1.0 hard-deletes synchronously inside `deleteUserAccount`.
- **Groups UI work.** Groups has no Dart client code yet
  (`lib/features/groups/README.md`). Group-shared documents are covered by the
  same preserve-and-tombstone rule the function applies to friendships (the
  member shows as "Deleted User"), but no Groups screens or flows are built in
  this story.

---

## Dependencies

| Dependency | Status |
|---|---|
| FR-AU-06 — user document exists | Shipped |
| Profile screen "Delete Account" row | Shipped (currently a "Coming soon" snackbar dead-end) |
| `PhoneAccountRepository` re-auth (`reauthenticate` / `requestOtp` / `currentPhoneNumber`, FR-PR-02) | Shipped (reused) |
| OTP request/verify + FR-AU-05 rate limiting (FR-AU-01..05) | Shipped |
| `deleteUserAccount` callable Cloud Function (`asia-south1`, Admin SDK cascade, idempotent) | Required (Architect + Functions Dev) |
| Firestore Security Rules keep client `delete` at `false` for `users` and `friendships` | In place (`firestore.rules`) — confirm coverage in tests |
| FR-PR-05 Contact Support flow (Step D error action) | Shipped |
| `firebase_auth` + Cloud Functions SDK | Already dependencies (no new plugin, no `ios/Podfile.lock` change) |
