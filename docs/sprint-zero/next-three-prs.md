# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #52 merged (FR-AC-01 — activity feed read-side + settlement-trigger activity emission).

---

## GitHub issue / PR numbering note (post-PR #52)

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
| **#53** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #53, PR #54, PR #55. Their issue-number
counterparts (when filed) will consume intermediate numbers; the
orchestrator should not assume PR #53 = number 53 on GitHub.

---

## PR #53 — TBD

**Status:** Next up. Architect picks at PR #53 kickoff per Sprint 2 velocity.

PR #52 shipped FR-AC-01 / FR-AC-02 — the SCR-25 Activity tab is now
live as a temporary route reachable from `HomePlaceholderScreen`'s
AppBar action; the `OBTActivityRow` widget primitive is in the
component catalogue; the settlement-trigger TODO at
`functions/src/triggers/on-settlement-write/function.ts:231` is
closed (settlement events now emit `'settlement'` activity items to
both parties). The bottom-nav shell remains deferred (architect §2.1
in `docs/sprint-zero/stories/FR-AC-01-activity-feed-read-side.md`).
Cold-start deep-link (FR-AC-05) and FCM push notifications (FR-AC-03)
remain the natural next P0 stories — the FR-AC-01 in-app deep-link
routing surface this PR shipped is the prerequisite both stories
consume.

Candidates (in rough priority order):

- **FR-AC-03 — FCM push notifications + FR-AC-05 cold-start deep-link.**
  The highest unplaced P0 pair. Introduces the FCM dependency + the
  `notificationPrefs` schema + per-user `fcmTokens` plumbing.
  FR-AC-05 (cold-start deep-link from a tapped push notification when
  the app is not running) is naturally paired since the cold-start
  signal comes from the FCM tap event. 8-10 SP — may split into two
  sub-PRs (FCM infrastructure vs cold-start handler) at architect's
  call. The FR-AC-01 deep-link routing this PR shipped is the
  in-app target both stories use.
- **FR-SE-09 — Send Reminder.** Closes the receiving-direction
  branch of the OBTSettleUpCard (per PR #43 §2.5 default-omit).
  Requires FCM dependency + 24-hour rate-limit subcollection. Now
  the highest unplaced P1. Will exercise the
  `_rateLimits/{uid}/sends/counter` subcollection pattern
  established by PR #45 Architect Notes §2.9. Naturally bundles
  with FR-AC-03 if the FCM infrastructure ships in the same PR
  (one FCM dependency add, two consumers).
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
- **Concurrent-edit detection for FR-EX-06** (operational
  hardening; small standalone PR). Explicitly deferred from PR #46.
- **Integration-test infrastructure fix** (operational chore;
  ~1-2 SP). The Functions emulator currently fails to load
  `onExpenseWriteFriendship` with the warning
  `functions.config() has been removed in firebase-functions v7`
  during integration runs; this is a pre-existing issue not
  caused by PR #52 (verified by stashing PR #52 changes and
  reproducing on `main`). Track as a Sprint-3 cleanup item; CI
  may have a workaround that local runs do not — to investigate.
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

## PR #54 — TBD

**Status:** Slot reserved. Architect picks at PR #53 kickoff.

Candidates: whatever doesn't land in PR #53 from the list above, plus:

- A Bucket-B chore PR (remaining 27 / 37 items after PR #51 closed
  R5a — activity rules coverage).
- Pre-Sprint 3 design polish (FR-FR-01 chore #28 Friends HTML
  mockup; SCR-09/10 wireframe alignment).
- The deferred rate-limit transaction race refactor (PR #45 §2.2).
- The deferred concurrent-edit detection for FR-EX-06.
- Issue #47 rules-hardening for the non-creator update/delete gate.

---

## PR #55 — TBD

**Status:** Slot reserved. Architect picks at PR #54 kickoff.

Candidates: whatever doesn't land in PR #53 / PR #54 from the lists
above.

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

---

## Snapshot — Sprint 2 status at end of PR #51

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 15 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45, #46, #48, #51) |
| Story points delivered | 55 (PR #41 was 0 SP — pure docs cross-refs; PR #42, #43, #46, #48, #51 were 5 SP each; PR #44 + PR #45 were 3 SP each — both chores) |
| Bucket-B items closed | 10 (R1, R2, R3, R5a, R7, R8, CV3, SR8, D5a, D5b — PR #51 closed R5a with the new 12-test activity.test.ts suite). Remaining: 27 / 37. |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 14 (issues #47, #49, #50 remain open; PR #51 did not file any new issues) |
| Outstanding deadline-bound work | **None.** D5 shipped in PR #44; PR #45, PR #46, PR #48, PR #51 were non-deadline-bound. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** Expense lifecycle (create / edit / soft-delete) closed end-to-end on the friendship axis by PR #46. Receipt attachment surface closed by PR #48. **Activity-feed WRITE-SIDE closed by PR #51** — every friendship-expense write now emits an `activity/{userId}/items/{auto-id}` document per member with type discriminator (`expense_added` / `expense_edited` / `expense_deleted`) and a payload sufficient for SCR-25 to render the row without additional reads. Read-side closure is the FR-AC-01 follow-on PR. |

