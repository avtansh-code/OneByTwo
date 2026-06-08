# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #53 merged (FR-AC-03 + FR-AC-05 — FCM push notifications + cold-start deep-link).

---

## GitHub issue / PR numbering note (post-PR #53)

The numbering jumped because issues and PRs share the same sequential
namespace on GitHub. The post-PR #48 sequence so far:

| Number | Type | What |
|---|---|---|
| #46 | PR | FR-EX-06 edit / delete expense, friendship context (merged 2026-06-07) |
| #47 | Issue | Firestore rules-hardening for non-creator update/delete (OPEN — Sprint 3 hardening) |
| #48 | PR | FR-EX-05 receipt attachment, friendship context (merged 2026-06-07) |
| #49 | Issue | Orphan-cleanup Cloud Function for unreferenced receipts (90-day reaper) — OPEN (FUTURE-work chore, 2 SP) |
| #50 | Issue | Trigger no-op-recompute optimisation when update touches only `receiptUrl` + `updatedAt` — OPEN (FUTURE-work chore, 1 SP). **EXPLICITLY CANNOT BE CLOSED** by any FR-EX-07-consuming PR — the optimisation would skip activity emission on receipt-only updates, breaking the FR-EX-07 contract (AC-2). |
| #51 | PR | FR-EX-07 activity feed write-side, friendship expenses (merged 2026-06-07) |
| #52 | PR | FR-AC-01 activity feed read-side + settlement-trigger activity emission (merged 2026-06-08) |
| #53 | PR | FR-AC-03 FCM push notifications + FR-AC-05 cold-start deep-link (merged 2026-06-08) |
| **#54** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #54, PR #55, PR #56. Their issue-number
counterparts (when filed) will consume intermediate numbers; the
orchestrator should not assume PR #54 = number 54 on GitHub.

---

## PR #54 — TBD

**Status:** Next up. Architect picks at PR #54 kickoff per Sprint 2 velocity.

PR #53 shipped FR-AC-03 + FR-AC-05 — the FCM module is live (server
notifications module + per-event-type renderer + 410 token cleanup +
prefs filter + INR formatter parity), both triggers emit FCM (expense
to non-author members, settlement to toUserId), the client lifecycle
is wired (token register / refresh / sign-out cleanup), the
pre-permission dialog appears on first transition to
`AuthenticatedWithProfile`, the foreground in-app banner renders via
an OverlayEntry, the background `onBackgroundMessage` handler is
registered before runApp, and the cold-start `getInitialMessage`
payload routes after the auth check. The shared
`lib/core/routing/notification_deep_links.dart` helper is consumed by
both the activity feed (`ActivityFeedScreen._onRowTap` refactored)
and the FCM tap surfaces.

Candidates (in rough priority order):

- **FR-SE-09 — Send Reminder.** Now the **highest unplaced P1** and
  the **first downstream consumer of the FCM module shipped in
  PR #53**. Introduces the per-friend 24-hour rate-limit
  subcollection (`_rateLimits/{uid}/sends/counter` pattern per PR #45
  Architect Notes §2.9), the Reminder Cloud Function entry point,
  the `reminder` notification template producer (renderer + filter
  already shipped in PR #53), and the OBTSettleUpCard "Send Reminder"
  button on the receiving-direction branch (deferred per PR #43 §2.5
  default-omit). 4-6 SP. NO new FCM infrastructure work — the
  `sendFcmToTokens` API is stable.
- **FR-AC-04 + FR-PR-03 — notification preferences UI.** The Profile
  screen gains a `/profile/notifications` route with three toggles
  (`newExpense`, `settlement`, `reminder`) backed by the existing
  `users/{uid}.notificationPrefs` map. The server-side prefs-filter
  already shipped in PR #53 — this is purely the client UI + write
  path. 3-4 SP. Naturally pairs with FR-SE-09 because both touch
  notification semantics.
- **`OBTBottomNav` shell.** UX foundation deferred from PR #52 per
  architect §2.1. Becomes the canonical entry point for the
  Friends / Groups / Activity / Profile tab cluster — needed before
  the Sprint 3 groups epic ships.
- **FR-SE-08 dedicated full-history screen** at
  `/settlements/history` (P0 — PR #42's in-timeline rows satisfy
  v1.0 but the dedicated screen is still a backlog item).
- **Issue #47 rules-hardening for non-creator update/delete gate**
  (operational hardening; small standalone PR ~2 SP). Closes the
  defence-in-depth gap that the FR-EX-06 architect §2.9 item 5
  documented.
- **`OBTRupeeText` primitive** (UX foundation; small PR ~1 SP).
  Deferred from PR #52 per architect §2.6. The component catalogue
  declares it; a future PR adds the 5-line wrapper around
  `Text(formatInrFromPaise(...))` once a second use site needs it.
- **Activity-writer rename cleanup** (cosmetic; small chore PR
  ~1-2 SP). Per FR-AC-01 architect §2.3 the rename of
  `writeExpenseActivity` → `writeContextActivity` (+ `friendshipId`
  → `contextId`, `expenseId` → `entityId`, `expenseIdHash` →
  `entityIdHash`) was DEFERRED to minimise blast radius. A future
  cleanup PR can do the full rename + Cloud Logging dashboard
  migration as one focused change.
- **`shared_preferences` adoption for FCM-permission persistence**
  (architect §2.6 / §2.8 addendum from PR #53). The
  `wasPermanentlyDenied` flag in
  `NotificationPermissionController` is in-memory only because the
  lockfile has no `shared_preferences` entry. Add the dependency +
  persist the flag across launches so the pre-permission dialog
  honours the "permanently denied" state across app restarts.
  1-2 SP. Naturally pairs with the FR-AC-04 / FR-PR-03 prefs UI PR
  since that also persists user-facing notification preferences.
- **FCM emulator-side integration test infrastructure** (per PR #53
  functions-dev §1 deviation). The Cloud Functions emulator-side
  integration tests under `functions/test/integration/on-*.integration.test.ts`
  do not exercise the FCM emission path because `jest.mock()` does
  not survive the emulator process boundary. Future work: add a
  flag-gated production-config swap that injects a `MockMessaging`
  in the emulator process so the full create → trigger → FCM round
  trip is asserted in CI. 2-3 SP.
- **Concurrent-edit detection for FR-EX-06** (operational
  hardening; small standalone PR). Explicitly deferred from PR #46.
- **Issue #49 — Orphan-cleanup Cloud Function for receipts**
  (FUTURE; filed during PR #48 per SRS schema doc line 312).
  Out of v1.0 unless required for compliance.
- **Issue #50 — Trigger no-op-recompute optimisation** (FUTURE;
  filed during PR #48). **EXPLICITLY CONSTRAINED** by FR-EX-07
  (PR #51 AC-2): the optimisation must NOT skip activity emission
  on receipt-only updates; a follow-up will update issue #50 with
  this constraint.
- **Rate-limit transaction race refactor** (operational hardening;
  small standalone PR). Deferred from PR #45 per chore-story
  Architect Notes §2.2.
- **`emitExpenseActivity` memberIds re-read cleanup** (operational
  cleanup; small standalone PR ~1 SP). Per the PR #51 review
  recommendation #1: the trigger handler currently re-reads the
  friendship doc to resolve `memberIds` for the activity fan-out
  (one extra Firestore read per invocation). A future refactor
  could thread `memberIds` through `RecomputeResult` to eliminate
  the second read; track as a Sprint-3 cleanup item.

---

## PR #55 — TBD

**Status:** Slot reserved. Architect picks at PR #54 kickoff.

Candidates: whatever doesn't land in PR #54 from the list above.

---

## PR #56 — TBD

**Status:** Slot reserved. Architect picks at PR #55 kickoff.

Candidates: whatever doesn't land in PR #54 / PR #55 from the lists above.

---


## Sequencing rationale

After PR #43 both halves of the simplified-debts round-trip closed
end-to-end from the user's point of view. PR #44 then de-risked the
deploy path by retiring the Node 20 runtime + `firebase-functions`
6.x ahead of the 2026-10-31 cutoff. With 5 Cloud Functions live in
production (PR #36 trigger, PR #37 trigger + algorithm extension,
plus the original 3 from Sprint 1), the upgrade surface was
non-trivial; bundling Node-22 + `firebase-functions@7.x` into one
PR kept the rollback story atomic and the test surface bounded.

PR #45 then bundled two small hygiene streams into a single atomic
chore PR: (a) the `lookup-user-by-phone-number` rate-limit doc-path
fix at `functions/src/lookup-user-by-phone-number/function.ts:108`,
and (b) the three S4 items from the PR #38 QA sign-off Post-Merge
Cleanup Backlog. The 5 previously-skipped integration tests at
`functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
are now active and exercise the rate-limit branch end-to-end in CI.

PR #46 then shipped FR-EX-06 (edit + soft-delete for friendship-
context expenses, mirroring SCR-22). The Expense Detail screen is
the natural viewing surface for the read-only row PR #42 rendered;
the bottom-sheet edit-mode reuses the PR #38 Add Expense layout
under an `isEditMode` controller path. The dedicated
`OBTConfirmationDialog` widget added in PR #46 is the reusable
confirmation primitive for every future destructive action.

PR #48 then closed the SCR-21 surface PR #38 had deferred —
receipt attachment for friendship-context expenses. Step 3 reuses
the Step 2 / bottom-sheet machinery; a new
`ReceiptStorageService` mirrors the existing repository pattern;
the `ImagePickerService` was extracted from `features/auth/data/`
to `lib/core/services/` so the expense feature can import it
without an auth → expenses dependency. The `storage.rules` predicate
for friendship-receipts ships with the matching defensive
group-receipts predicate (closes R7 + R8 in one shot).

PR #51 then closed the long-standing
`// TODO(FR-AC-01): write activity-feed item` hand-off seam at
`functions/src/triggers/on-expense-write/function.ts:160-169` —
the friendship-expense trigger now fans out an
`activity/{userId}/items/{auto-id}` document per friendship member
on every successful recompute (create / edit / soft-delete). The
new `firestore.rules` block at `match /activity/{userId}/items/{itemId}`
enforces member-read / server-only-write, the canonical posture
mirroring `simplifiedBalances`. The `activity-writer.ts` module
is reusable by the future settlement-trigger activity-emission
extension (paired with FR-AC-01 client read-side).

PR #52 picks up the highest-value backlog item per Sprint 2
velocity at the PR #52 kickoff. FR-AC-01 client (SCR-25) +
settlement-trigger activity emission is the natural next-feature
pairing — the read-side schema PR #51 wrote is the contract
FR-AC-01 reads, and the settlement-trigger half is needed for the
settlement leg of SCR-25 to render anything. The architect's call
at kickoff reflects the current priority signal.

PR #53 picks up FR-AC-03 + FR-AC-05 — the second natural P0 reader
of the FR-AC-01 in-app routing surface PR #52 shipped. FCM is the
cold-start signal (FR-AC-05) so the two stories pair naturally.
The Functions notifications module (FCM admin-SDK helper, per-event-
type renderer, prefs filter, 410 token cleanup, Functions-side INR
formatter) is the bulk; the two trigger-extension hooks
(`emitExpenseFcm` and `emitSettlementFcm`) close the FR-AC-03 TODO
seams; the client lifecycle wires token register / refresh /
sign-out cleanup; the pre-permission dialog appears on first
transition to `AuthenticatedWithProfile`; the in-app banner
overlays via `OverlayEntry`; the background handler is registered
before `runApp`; the cold-start `getInitialMessage` payload routes
after the auth check. The shared
`lib/core/routing/notification_deep_links.dart` helper is consumed
by both the activity-feed row-tap path (refactored) and the FCM
tap surfaces, satisfying architect §2.3.

---

## Snapshot — Sprint 2 status at end of PR #53

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 17 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45, #46, #48, #51, #52, #53) |
| Story points delivered | 73 (PR #41 was 0 SP — pure docs cross-refs; PR #42, #43, #46, #48, #51 were 5 SP each; PR #44 + PR #45 were 3 SP each — both chores; PR #52 was 8 SP; PR #53 was 10 SP) |
| Bucket-B items closed | 10 (R1, R2, R3, R5a, R7, R8, CV3, SR8, D5a, D5b — PR #51 closed R5a with the new 12-test activity.test.ts suite). Remaining: 27 / 37. **PR #53 made partial PY3 progress** with 11 trigger-level FCM tests + 63 module-level notifications unit tests; no Bucket-B items formally closed. |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 14 (issues #47, #49, #50 remain open; PR #53 did not file any new issues) |
| Outstanding deadline-bound work | **None.** D5 shipped in PR #44; PR #45, PR #46, PR #48, PR #51, PR #52, PR #53 were non-deadline-bound. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** Expense lifecycle (create / edit / soft-delete) closed end-to-end on the friendship axis by PR #46. Receipt attachment surface closed by PR #48. **Activity-feed WRITE-SIDE closed by PR #51**; READ-SIDE closed by PR #52. **FCM push-notification round-trip closed by PR #53** — every expense (create / edit / soft-delete) and settlement now produces an FCM push to all non-author recipients respecting `notificationPrefs`; foreground and background and cold-start are all hooked to the shared in-app routing surface; the FCM module is the stable consumer surface for FR-SE-09 reminders next. |

