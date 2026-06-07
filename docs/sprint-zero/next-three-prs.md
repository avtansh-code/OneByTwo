# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #46 merged (FR-EX-06 — edit / delete expense, friendship context).

---

## GitHub issue / PR numbering note (post-PR #46)

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
| **#47** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #47, PR #48, PR #49. Their issue-number
counterparts (when filed) will consume intermediate numbers; the orchestrator
should not assume PR #48 = number 48 on GitHub.

---

## PR #47 — TBD

**Status:** Next up. Architect picks at PR #47 kickoff per Sprint 2 velocity.

PR #46 shipped FR-EX-06 (edit + soft-delete for friendship-context
expenses, mirroring SCR-22), built atop a dedicated Expense Detail
screen and a reusable `OBTConfirmationDialog` widget downstream
destructive flows will inherit. The `onExpenseWriteFriendship`
trigger from PR #36 already handles update + soft-delete events, so
the simplified-debts round-trip is now closed end-to-end for the
create / edit / delete lifecycle on the friendship axis. PR #47
picks the highest-value backlog item per current priority signal.

Candidates (in rough priority order):

- **FR-EX-05 — Receipt attachment.** Pairs with Storage rules R7-R8
  from the Bucket-B burndown
  ([#21](https://github.com/avtansh-code/OneByTwo/issues/21)). The
  Expense Detail screen shipped by PR #46 is the natural viewing
  surface for receipts; the bottom-sheet edit-mode established by
  PR #46 generalises to a Step-3 attachment slot.
- **FR-EX-07 — Activity feed.** Natural P0 follow-on; the
  `onExpenseWriteFriendship` trigger already emits activity entries
  for create / update / soft-delete events, so the remaining work
  is the read-side screen + listener + composite-index design.
- **FR-SE-09 — Send Reminder.** Closes the receiving-direction
  branch of the OBTSettleUpCard (per PR #43 §2.5 default-omit).
  Requires FCM dependency + 24-hour rate-limit subcollection.
  **Note:** this PR will exercise the
  `_rateLimits/{uid}/sends/counter` subcollection pattern
  established by PR #45 Architect Notes §2.9.
- **FR-SE-08 dedicated full-history screen** at
  `/settlements/history` (P0 — PR #42's in-timeline rows satisfy
  v1.0 but the dedicated screen is still a backlog item).
- **Concurrent-edit detection for FR-EX-06** (operational
  hardening; small standalone PR). Explicitly deferred from
  PR #46 per the story's Out of Scope (AC-11 / AC-12 — full
  transactional concurrent-edit detection).
- **Rules-hardening for non-creator update/delete gate**
  (operational hardening; small standalone PR). Closes the gap
  architect §2.9 item 5 of the FR-EX-06 story documented — the
  `friendships/{fid}/expenses/{eid}` rules currently permit
  update + soft-delete by any friendship member; the client UI
  gates on `expense.createdBy == currentUser.uid` but a
  defence-in-depth rules tightening is a follow-up. File as a
  sprint-3-hardening issue at minimum.
- **Rate-limit transaction race refactor** (operational hardening;
  small standalone PR). Deferred from PR #45 per chore-story
  Architect Notes §2.2.

---

## PR #48 — TBD

**Status:** Slot reserved. Architect picks at PR #47 kickoff.

Candidates: whatever doesn't land in PR #47 from the list above, plus:

- A Bucket-B chore PR (e.g., Storage rules R7-R8 if FR-EX-05 ships
  in PR #47).
- Pre-Sprint 3 design polish (FR-FR-01 chore #28 Friends HTML
  mockup; SCR-09/10 wireframe alignment).
- A test-hygiene chore to move `npm run test:rules` out of the
  `--only auth,firestore,functions,storage` emulator invocation in
  `.github/workflows/pr.yml` (noted as a side observation in
  `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect
  Notes §2.7 — the trigger-interference flake is environment-
  sensitive on macOS but not observed on Linux runners).
- The deferred rate-limit transaction race refactor (PR #45 §2.2).
- The deferred concurrent-edit detection for FR-EX-06 (AC-11 /
  AC-12 of the FR-EX-06 story).
- The deferred rules-hardening for the non-creator update/delete
  gate (architect §2.9 item 5 of the FR-EX-06 story).

---

## PR #49 — TBD

**Status:** Slot reserved. Architect picks at PR #48 kickoff.

Candidates: whatever doesn't land in PR #47 / PR #48 from the lists
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
fix at `functions/src/lookup-user-by-phone-number/function.ts:108`
(the bug was masked since FR-FR-01 shipped because the rate-limit
gate would throw before the algorithm ran, but the contact-picker
happy path stayed well below the 100/hour throttle), and (b) the
three S4 items from the PR #38 QA sign-off Post-Merge Cleanup
Backlog (stale telemetry references in 3 design docs; splitter test
cap-label propagation; missing `// TODO(SCR-08)` comment on
`friends_list_screen.dart`). The 5 previously-skipped integration
tests at
`functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
are now active and exercise the rate-limit branch end-to-end in
CI.

PR #46 then shipped FR-EX-06 (edit + soft-delete for friendship-
context expenses, mirroring SCR-22). The Expense Detail screen is
the natural viewing surface for the read-only row PR #42 rendered;
the bottom-sheet edit-mode reuses the PR #38 Add Expense layout
under an `isEditMode` controller path. The dedicated
`OBTConfirmationDialog` widget added in PR #46 (design-system
catalogue item 24) is the reusable confirmation primitive for
every future destructive action. Four new Firestore rules tests
(149 → 153) cover the FR-EX-06 update + soft-delete validation
paths; 82 new Flutter tests (794 → 876 pass) cover the controller,
the repository, the dialog widget, and the Expense Detail screen
end-to-end; 3 skipped integration-test stubs at
`test/integration/expenses/edit_delete_expense_flow_test.dart`
earn partial PY3 credit pending the Flutter emulator harness.

PR #47 picks up the highest-value backlog item per Sprint 2
velocity at the PR #47 kickoff. FR-EX-05 (receipt attachment) is
the natural next-feature given the Expense Detail screen built in
PR #46 is the viewing surface and Storage rules R7-R8 are an open
Bucket-B item. FR-EX-07 / FR-SE-09 / FR-SE-08 / the deferred
concurrent-edit detection / the rules-hardening follow-up / the
rate-limit transaction race refactor are all plausible alternates;
the architect's call at kickoff reflects the current priority
signal.

---

## Snapshot — Sprint 2 status at end of PR #46

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 13 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45, #46) |
| Story points delivered | 45 (PR #41 was 0 SP — pure docs cross-refs; PR #42 + PR #43 + PR #46 were 5 SP each; PR #44 + PR #45 were 3 SP each — both chores) |
| Bucket-B items closed | 7 (R1, R2, R3, CV3, SR8, D5a, D5b — unchanged from PR #44; neither PR #45 nor PR #46 closed Bucket-B items by ID. PR #46 added four new Firestore rules tests covering FR-EX-06 update + soft-delete paths, extending the R4 coverage closed by PR #36, but does not close any remaining R5-R8 sub-item.) |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 13 (unchanged — PR #46 closed no open issues; the FR-EX-06 story tracks its deferred items in the story's Out of Scope and via the next-three-prs.md candidate list rather than as new GitHub issues) |
| Outstanding deadline-bound work | **None.** D5 shipped in PR #44; PR #45 and PR #46 were non-deadline-bound. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** The read-side was closed in PR #42 (Friend Detail). Deploy path future-proofed in PR #44 (Node 22 + `firebase-functions@7.x`). Lookup-user rate-limit gate effective for the first time in production via PR #45 (was silently throwing pre-fix; now enforces 100/hour per SRS §5.7). **Expense lifecycle (create / edit / delete) closed end-to-end on the friendship axis by PR #46**: create via PR #38 bottom sheet, edit via PR #46 bottom-sheet edit-mode, soft-delete via PR #46 Expense Detail destructive action. The `onExpenseWriteFriendship` trigger (PR #36) recomputes `simplifiedBalances` on all three branches. |

