# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #48 merged (FR-EX-05 — receipt attachment, friendship context).

---

## GitHub issue / PR numbering note (post-PR #48)

The numbering jumped because issues and PRs share the same sequential
namespace on GitHub. The post-PR #38 sequence so far:

| Number | Type | What |
|---|---|---|
| #38 | PR | FR-EX-01 expense creation UI + chore #25 (merged 2026-06-06) |
| #39 | Issue | Cloud Functions Node 20 decommissioned 2026-10-31 (**CLOSED by PR #44**) |
| #40 | Issue | `firebase-functions` 6.x → 7.x (**CLOSED by PR #44**) |
| #41 | PR | docs(plan) — D5 deadline backlog cross-refs (merged 2026-06-06) |
| #42 | PR | FR-FR-04 friend detail full screen (merged 2026-06-06) |
| #43 | PR | FR-SE-05/06/07 settle up flow (merged 2026-06-06) |
| #44 | PR | CHORE-D5 runtime upgrade — Node 22 + firebase-functions 7.x (merged 2026-06-06; closes #39 #40) |
| #45 | PR | CHORE-PR45 — lookup rate-limit doc-path fix + post-PR-#38 cleanup (merged 2026-06-06) |
| #46 | PR | FR-EX-06 edit / delete expense, friendship context (merged 2026-06-07) |
| #47 | Issue | Firestore rules-hardening for non-creator update/delete (OPEN — Sprint 3 hardening) |
| #48 | PR | FR-EX-05 receipt attachment, friendship context (merged 2026-06-07) |
| **#49** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #49, PR #50, PR #51. Their issue-number
counterparts (when filed) will consume intermediate numbers; the orchestrator
should not assume PR #49 = number 49 on GitHub.

---

## PR #49 — TBD

**Status:** Next up. Architect picks at PR #49 kickoff per Sprint 2 velocity.

PR #48 shipped FR-EX-05 (receipt attachment for friendship-context
expenses, SCR-21) — the first client uploader to Firebase Storage
from the expense feature. The new Step 3 widget plus the extracted
`ImagePickerService` (now at `lib/core/services/`) plus the new
`ReceiptStorageService` give downstream features the building
blocks for any future image-attachment surface (e.g. group-context
receipts in the Sprint 3 groups epic). PR #48 also closed R7 + R8
from the Sprint-1 Bucket-B burndown (Storage rules tests for file
size + content type). The defensive group-receipts predicate is
already in `storage.rules` — the Sprint 3 groups epic only needs
to wire the UI.

Candidates (in rough priority order):

- **FR-EX-07 — Activity feed.** The highest unplaced P0. The
  `onExpenseWriteFriendship` trigger already emits activity entries
  for create / update / soft-delete events; PR #48's receipt-only
  update also fires the trigger (no-op recompute — log noise but
  correct). The remaining work is the read-side screen + listener +
  composite-index design.
- **FR-SE-09 — Send Reminder.** Closes the receiving-direction
  branch of the OBTSettleUpCard (per PR #43 §2.5 default-omit).
  Requires FCM dependency + 24-hour rate-limit subcollection.
  **Note:** this PR will exercise the
  `_rateLimits/{uid}/sends/counter` subcollection pattern
  established by PR #45 Architect Notes §2.9.
- **FR-SE-08 dedicated full-history screen** at
  `/settlements/history` (P0 — PR #42's in-timeline rows satisfy
  v1.0 but the dedicated screen is still a backlog item).
- **Issue #47 rules-hardening for non-creator update/delete gate**
  (operational hardening; small standalone PR ~2 SP). Closes the
  defence-in-depth gap that the FR-EX-06 architect §2.9 item 5
  documented — the `friendships/{fid}/expenses/{eid}` rules
  currently permit update + soft-delete by any friendship member;
  the client UI gates on `expense.createdBy == currentUser.uid`
  but a defence-in-depth rules tightening is a follow-up.
- **Concurrent-edit detection for FR-EX-06** (operational
  hardening; small standalone PR). Explicitly deferred from
  PR #46 per the story's Out of Scope (AC-11 / AC-12 — full
  transactional concurrent-edit detection).
- **Orphan-cleanup Cloud Function for receipts** (FUTURE; filed
  during PR #48 per SRS schema doc line 312 — 90-day reaper of
  unreferenced files under `receipts/`). Out of v1.0 unless
  required for compliance.
- **Trigger no-op-recompute optimisation** (FUTURE; filed during
  PR #48 — skip `recomputeSimplifiedBalances` when the update
  touches only `receiptUrl` + `updatedAt`). Pure log-noise +
  trivial CPU optimisation.
- **Rate-limit transaction race refactor** (operational hardening;
  small standalone PR). Deferred from PR #45 per chore-story
  Architect Notes §2.2.

---

## PR #50 — TBD

**Status:** Slot reserved. Architect picks at PR #49 kickoff.

Candidates: whatever doesn't land in PR #49 from the list above, plus:

- A Bucket-B chore PR (remaining 28 / 37 items after PR #48
  closed R7 + R8).
- Pre-Sprint 3 design polish (FR-FR-01 chore #28 Friends HTML
  mockup; SCR-09/10 wireframe alignment).
- A test-hygiene chore to move `npm run test:rules` out of the
  `--only auth,firestore,functions,storage` emulator invocation in
  `.github/workflows/pr.yml` (noted as a side observation in
  `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect
  Notes §2.7 — the trigger-interference flake is environment-
  sensitive on macOS but not observed on Linux runners). **Note:**
  PR #46 already split the rules tests into a dedicated emulator
  session per architect chore-D5 §2.7, so this slot is partially
  closed; the remaining work is updating the Architect Notes to
  reflect the split.
- The deferred rate-limit transaction race refactor (PR #45 §2.2).
- The deferred concurrent-edit detection for FR-EX-06.
- Issue #47 rules-hardening for the non-creator update/delete gate.

---

## PR #51 — TBD

**Status:** Slot reserved. Architect picks at PR #50 kickoff.

Candidates: whatever doesn't land in PR #49 / PR #50 from the lists
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
group-receipts predicate (closes R7 + R8 in one shot). 23 new
storage-rules tests (153 → 176 across 8 suites) cover the size /
MIME / membership / cross-collection predicate paths;
flutter tests grow 883 → 885 (the new step-3 widget tests, the
extracted picker smoke test, and the helper-shared fakes);
3 skipped integration-test stubs at
`test/integration/expenses/receipt_upload_flow_test.dart` earn
partial PY3 credit.

PR #49 picks up the highest-value backlog item per Sprint 2
velocity at the PR #49 kickoff. FR-EX-07 (activity feed) is the
natural next-feature given the trigger already emits the activity
entries; FR-SE-09 / FR-SE-08 / issue #47 rules-hardening / the
deferred concurrent-edit detection / the orphan-cleanup function /
the trigger no-op-recompute optimisation / the rate-limit
transaction race refactor are all plausible alternates; the
architect's call at kickoff reflects the current priority signal.

---

## Snapshot — Sprint 2 status at end of PR #48

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 14 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45, #46, #48) |
| Story points delivered | 50 (PR #41 was 0 SP — pure docs cross-refs; PR #42, #43, #46, #48 were 5 SP each; PR #44 + PR #45 were 3 SP each — both chores) |
| Bucket-B items closed | 9 (R1, R2, R3, R7, R8, CV3, SR8, D5a, D5b — PR #48 closed R7 + R8 with the new Storage rules predicates and the 23-test receipts.test.ts suite). Remaining: 28 / 37. |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 14 (PR #48 filed two new FUTURE-work issues: orphan-cleanup Cloud Function for receipts, and trigger no-op-recompute optimisation; plus issue #47 for non-creator rules hardening was filed during PR #46 review and remains open) |
| Outstanding deadline-bound work | **None.** D5 shipped in PR #44; PR #45, PR #46, and PR #48 were non-deadline-bound. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** Expense lifecycle (create / edit / soft-delete) closed end-to-end on the friendship axis by PR #46. **Receipt attachment surface closed by PR #48**: optional JPEG/PNG upload to `gs://onebytwo-avtanshgupta.appspot.com/receipts/friendships/{fid}/{eid}` with the Expense Detail screen rendering the thumbnail on read. The `onExpenseWriteFriendship` trigger (PR #36) recomputes `simplifiedBalances` on every branch including receipt-only updates (no-op recompute; filed as FUTURE optimisation). |

