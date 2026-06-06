# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #44 merged (D5 runtime upgrade — Node 22 + firebase-functions 7.x).

---

## GitHub issue / PR numbering note (post-PR #44)

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
| **#45** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #45, PR #46, PR #47. Their issue-number
counterparts (when filed) will consume intermediate numbers; the orchestrator
should not assume PR #46 = number 46 on GitHub.

---

## PR #45 — TBD

**Status:** Next up. Architect picks at PR #45 kickoff per Sprint 2 velocity.

The deadline-bound D5 work has shipped in PR #44 — the deploy path is
de-risked through Node 22 deprecation in 2027-04-30. PR #45 picks
the highest-value backlog item per current priority signal.

Candidates (in rough priority order):

- **`lookup-user-by-phone-number` rate-limit doc-path bug fix.**
  Five skipped integration tests in
  `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
  blocked on the rate-limit doc-path mismatch. Surfaced by PR #36's
  CI workflow change; pre-existing finding not touched by PR #44.
- **FR-EX-05 — Receipt attachment** (Step 3 of the Add Expense bottom
  sheet). Pairs with Storage rules R7-R8 from the Bucket-B burndown
  ([#21](https://github.com/avtansh-code/OneByTwo/issues/21)).
- **FR-EX-06 — Edit / delete expense.** Natural follow-up to PR #38
  (the rows are currently read-only on Friend Detail per PR #42); the
  bottom sheet pattern is established.
- **FR-SE-09 — Send Reminder.** Closes the receiving-direction branch
  of the OBTSettleUpCard (per PR #43 §2.5 default-omit). Requires
  FCM dependency + 24-hour rate-limit rules. (Note: pairs cleanly
  with PR #44's runtime upgrade — the FCM-emitting Cloud Function
  ships on the new Node 22 + `firebase-functions@7.x` matrix.)
- **FR-SE-08 dedicated full-history screen** at `/settlements/history`
  (P0 — PR #42's in-timeline rows satisfy v1.0 but the dedicated
  screen is still a backlog item).
- **Post-PR #38 cleanup PR** (the 3 S4 items: stale event names in 3
  design docs; splitter test cap labels; missing `// TODO(SCR-08)`
  comment).

---

## PR #46 — TBD

**Status:** Slot reserved. Architect picks at PR #45 kickoff.

Candidates: whatever doesn't land in PR #45 from the list above, plus:

- A Bucket-B chore PR (e.g., Storage rules R7-R8 if FR-EX-05 ships).
- Pre-Sprint 3 design polish (FR-FR-01 chore #28 Friends HTML
  mockup; SCR-09/10 wireframe alignment).
- A test-hygiene chore to move `npm run test:rules` out of the
  `--only auth,firestore,functions,storage` emulator invocation in
  `.github/workflows/pr.yml` (noted as a side observation in
  `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect
  Notes §2.7 — the trigger-interference flake is environment-
  sensitive on macOS but not observed on Linux runners).

---

## PR #47 — TBD

**Status:** Slot reserved. Architect picks at PR #46 kickoff.

Candidates: whatever doesn't land in PR #45 / PR #46 from the lists
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

PR #44's outcome: **zero source-code reconciliations required** (the
v6 → v7 breaking changes do not apply to our v2-only callsites; see
`docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect
Notes §2.4 + §2.7). The five-layer test pyramid stayed green on the
new matrix (Layer 1+2+3: 100/100 pass; Layer 4: 149/149 pass; Layer
5: 28 pass / 5 skipped; coverage on `simplified-debts/function.ts`
at 89.13% branch vs the PR #36 baseline of 88.57%).

PR #45 picks up the highest-value backlog item per Sprint 2 velocity
at the PR #45 kickoff. The `lookup-user-by-phone-number` rate-limit
bug fix is a strong contender (unblocks 5 skipped integration
tests). FR-EX-05 / FR-EX-06 / FR-SE-09 are all plausible feature
candidates; the architect's call at kickoff reflects the current
priority signal.

---

## Snapshot — Sprint 2 status at end of PR #44

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 11 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44) |
| Story points delivered | 37 (PR #41 was 0 SP — pure docs cross-refs; PR #42 + PR #43 were 5 SP each; PR #44 was 3 SP — chore) |
| Bucket-B items closed | 7 (R1, R2, R3, CV3, SR8, D5a, D5b) |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 13 (was 15; PR #44 closed #39 + #40) |
| Outstanding deadline-bound work | **None.** D5 shipped in PR #44 — the deploy path is now de-risked through Node 22 deprecation 2027-04-30. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43** — both expenses (PR #38) and settlements (PR #43) flow end-to-end through the UI → trigger → snapshot stream → real-time re-render path. The read-side was closed in PR #42 (Friend Detail). Deploy path future-proofed in PR #44 (Node 22 + `firebase-functions@7.x`). |

