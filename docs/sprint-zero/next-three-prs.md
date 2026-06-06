# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #43 merged (FR-SE-05/06/07 settle up flow).

---

## GitHub issue / PR numbering note (post-PR #43)

The numbering jumped because issues and PRs share the same sequential
namespace on GitHub. The post-PR #38 sequence so far:

| Number | Type | What |
|---|---|---|
| #38 | PR | FR-EX-01 expense creation UI + chore #25 (merged 2026-06-06) |
| #39 | Issue | Cloud Functions Node 20 decommissioned 2026-10-31 (open) |
| #40 | Issue | `firebase-functions` 6.x → 7.x (open) |
| #41 | PR | docs(plan) — D5 deadline backlog cross-refs (merged 2026-06-06) |
| #42 | PR | FR-FR-04 friend detail full screen (merged 2026-06-06) |
| #43 | PR | FR-SE-05/06/07 settle up flow (merged 2026-06-06) |
| **#44** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #44, PR #45, PR #46. Their issue-number
counterparts (when filed) will consume intermediate numbers; the orchestrator
should not assume PR #45 = number 45 on GitHub.

---

## PR #44 — D5 deadline (Node 22 + firebase-functions 7.x)

**Status:** Next up. Unblocked. **DEADLINE: 2026-10-31.**

**Scope:**

The dedicated PR for **issues #39 + #40** — the deadline-bound D5
items surfaced by the post-PR #38 functions deploy:

- Cloud Functions runtime: Node 20 → Node 22 (issue #39).
- `firebase-functions` SDK: 6.x → 7.x (issue #40).

Both ship in the SAME PR so the runtime + SDK upgrade is atomic and
the rollback story is a single revert. Slot this PR before
mid-September 2026 to leave a comfortable buffer.

**Likely deliverables:**

- `functions/package.json` `engines.node` → `22`.
- `firebase.json` `functions[].runtime` → `nodejs22`.
- `firebase-functions` 6.x → 7.x with breaking-change reconciliation on
  all five deployed functions (v2 trigger + callable surfaces).
- `.github/workflows/pr.yml` and `.github/workflows/release.yml`
  `actions/setup-node` pinned to `22`.
- Re-run of every Functions test under the new runtime.
- Closes #39 and #40.

**Out of scope:**

- Any feature work — this is a pure infrastructure upgrade PR.
- Other dependency upgrades (Riverpod 3.x, share_plus, etc.) — those
  remain on issue #22.

**Agents involved:** Functions Dev, DevOps, QA.

---

## PR #45 — TBD

**Status:** Slot reserved. Architect picks at PR #44 kickoff per Sprint 2 velocity.

Candidates (in rough priority order):

- **`lookup-user-by-phone-number` rate-limit doc-path bug fix.**
  Five skipped integration tests in
  `functions/test/integration/lookup-user-by-phone-number.test.ts`
  blocked on the rate-limit doc-path mismatch.
- **FR-EX-05 — Receipt attachment** (Step 3 of the Add Expense bottom
  sheet). Pairs with Storage rules R7-R8 from the Bucket-B burndown
  ([#21](https://github.com/avtansh-code/OneByTwo/issues/21)).
- **FR-EX-06 — Edit / delete expense.** Natural follow-up to PR #38
  (the rows are currently read-only on Friend Detail per PR #42); the
  bottom sheet pattern is established.
- **FR-SE-09 — Send Reminder.** Closes the receiving-direction branch
  of the OBTSettleUpCard (per PR #43 §2.5 default-omit). Requires
  FCM dependency + 24-hour rate-limit rules.
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

---

## Sequencing rationale

After PR #43 both halves of the simplified-debts round-trip are
closed end-to-end from the user's point of view: a friendship member
sees the friends-list net balance chip, drills into Friend Detail,
sees the underlying expense ledger, adds expenses (PR #38) and
settlements (PR #43), and watches the balance pill + the new row
appear via the snapshot stream within NFR-PE-04's 2.5 s P95 budget.

PR #44 then de-risks the deploy path by retiring the Node 20
runtime + firebase-functions 6.x before the 2026-10-31 cutoff. With
5 Cloud Functions live in production (PR #36 trigger, PR #37 trigger
+ algorithm extension, plus the original 3 from Sprint 1), the
upgrade surface is non-trivial; bundling Node-22 + functions@7.x
into one PR keeps the rollback story atomic.

PR #45 picks up the highest-value backlog item per Sprint 2 velocity
at the PR #44 kickoff. FR-EX-05 / FR-EX-06 / FR-SE-09 are all
plausible; the architect's call at kickoff reflects the current
priority signal.

---

## Snapshot — Sprint 2 status at end of PR #43

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 10 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43) |
| Story points delivered | 34 (PR #41 was 0 SP — pure docs cross-refs; PR #42 + PR #43 were 5 SP each) |
| Bucket-B items closed | 5 (R1, R2, R3, CV3, SR8) |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 15 |
| Outstanding deadline-bound work | **D5 — Node 22 + firebase-functions 7.x (issues #39 + #40) by mid-September 2026** to ship before the 2026-10-31 cutoff. PR #44 is the dedicated default plan. |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43** — both expenses (PR #38) and settlements (PR #43) flow end-to-end through the UI → trigger → snapshot stream → real-time re-render path. The read-side was closed in PR #42 (Friend Detail). |

