# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #45 merged (chore — lookup-user rate-limit doc-path fix + post-PR-#38 cleanup).

---

## GitHub issue / PR numbering note (post-PR #45)

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
| **#46** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #46, PR #47, PR #48. Their issue-number
counterparts (when filed) will consume intermediate numbers; the orchestrator
should not assume PR #47 = number 47 on GitHub.

---

## PR #46 — TBD

**Status:** Next up. Architect picks at PR #46 kickoff per Sprint 2 velocity.

The deadline-bound D5 work shipped in PR #44 (deploy path de-risked
through Node 22 deprecation 2027-04-30). PR #45 closed the
lookup-user rate-limit doc-path bug AND the three S4 cleanup items
from PR #38 in one atomic bundle. PR #46 picks the highest-value
backlog item per current priority signal.

Candidates (in rough priority order):

- **FR-EX-06 — Edit / delete expense.** Natural follow-on to PR #38
  (the rows are currently read-only on Friend Detail per PR #42); the
  bottom sheet pattern is established, and the on-expense-write
  trigger from PR #36 already handles update + soft-delete events.
- **FR-EX-05 — Receipt attachment** (Step 3 of the Add Expense bottom
  sheet). Pairs with Storage rules R7-R8 from the Bucket-B burndown
  ([#21](https://github.com/avtansh-code/OneByTwo/issues/21)).
- **FR-SE-09 — Send Reminder.** Closes the receiving-direction branch
  of the OBTSettleUpCard (per PR #43 §2.5 default-omit). Requires
  FCM dependency + 24-hour rate-limit rules. **Note:** this PR
  will exercise the new `_rateLimits/{uid}/sends/counter`
  subcollection pattern established by PR #45 Architect Notes §2.9.
- **FR-SE-08 dedicated full-history screen** at `/settlements/history`
  (P0 — PR #42's in-timeline rows satisfy v1.0 but the dedicated
  screen is still a backlog item).
- **Rate-limit transaction race refactor** (operational hardening;
  small standalone PR). Deferred from PR #45 per chore-story
  Architect Notes §2.2.

---

## PR #47 — TBD

**Status:** Slot reserved. Architect picks at PR #46 kickoff.

Candidates: whatever doesn't land in PR #46 from the list above, plus:

- A Bucket-B chore PR (e.g., Storage rules R7-R8 if FR-EX-05 ships).
- Pre-Sprint 3 design polish (FR-FR-01 chore #28 Friends HTML
  mockup; SCR-09/10 wireframe alignment).
- A test-hygiene chore to move `npm run test:rules` out of the
  `--only auth,firestore,functions,storage` emulator invocation in
  `.github/workflows/pr.yml` (noted as a side observation in
  `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect
  Notes §2.7 — the trigger-interference flake is environment-
  sensitive on macOS but not observed on Linux runners).
- The deferred rate-limit transaction race refactor (PR #45 §2.2).

---

## PR #48 — TBD

**Status:** Slot reserved. Architect picks at PR #47 kickoff.

Candidates: whatever doesn't land in PR #46 / PR #47 from the lists
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

PR #46 picks up the highest-value backlog item per Sprint 2
velocity at the PR #46 kickoff. FR-EX-06 (Edit / delete expense) is
the natural next-feature given PR #42 made the rows visible and the
PR #38 bottom-sheet pattern is reusable for edit. FR-EX-05 / FR-SE-09
/ FR-SE-08 / the rate-limit transaction race refactor are all
plausible alternates; the architect's call at kickoff reflects the
current priority signal.

---

## Snapshot — Sprint 2 status at end of PR #45

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 12 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45) |
| Story points delivered | 40 (PR #41 was 0 SP — pure docs cross-refs; PR #42 + PR #43 were 5 SP each; PR #44 + PR #45 were 3 SP each — both chores) |
| Bucket-B items closed | 7 (R1, R2, R3, CV3, SR8, D5a, D5b — unchanged from PR #44; PR #45 closed no Bucket-B items because its scope was the NEW finding from PR #36 plus the three S4 items from the PR #38 QA sign-off backlog, neither of which were formal Bucket-B audit findings) |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 13 (unchanged — PR #45 closed no open issues; both streams were tracked in markdown only) |
| Outstanding deadline-bound work | **None.** D5 shipped in PR #44; PR #45 was non-deadline-bound. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** The read-side was closed in PR #42 (Friend Detail). Deploy path future-proofed in PR #44 (Node 22 + `firebase-functions@7.x`). Lookup-user rate-limit gate effective for the first time in production via PR #45 (was silently throwing pre-fix; now enforces 100/hour per SRS §5.7). |

