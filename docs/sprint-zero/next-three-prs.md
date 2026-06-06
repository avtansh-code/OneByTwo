# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #42 merged (FR-FR-04 friend detail full screen).

---

## GitHub issue / PR numbering note (post-PR #42)

The numbering jumped because issues and PRs share the same sequential
namespace on GitHub. The post-PR #38 sequence so far:

| Number | Type | What |
|---|---|---|
| #38 | PR | FR-EX-01 expense creation UI + chore #25 (merged 2026-06-06) |
| #39 | Issue | Cloud Functions Node 20 decommissioned 2026-10-31 (open) |
| #40 | Issue | `firebase-functions` 6.x → 7.x (open) |
| #41 | PR | docs(plan) — D5 deadline backlog cross-refs (merged 2026-06-06) |
| #42 | PR | FR-FR-04 friend detail full screen (merged 2026-06-06) |
| **#43** | **PR** | **Next feature PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #43, PR #44, PR #45. Their issue-number
counterparts (when filed) will consume intermediate numbers; the orchestrator
should not assume PR #44 = number 44 on GitHub.

---

## PR #43 — FR-SE-08 Settle-Up UI

**Status:** Next up. Unblocked.

**Scope:**

The default plan is **FR-SE-08 Settle-Up UI** — the first Flutter client
surface that produces settlement writes. Symmetric to PR #38 for
settlements: PR #37 shipped the `onSettlementWrite` trigger that
consumes settlement documents, but the only producer today is the admin
SDK. FR-SE-08 closes the settlement round-trip from the user's point of
view. Particularly natural to ship right after PR #42 (FR-FR-04) since
the Friend Detail screen is the entry point for "I want to record a
settlement with this friend." PR #42 wired the settlement READ path
defensively; FR-SE-08 pairs it with the WRITE path and inserts the
`OBTSettleUpCard` between the header and the timeline.

**Likely deliverables:**

- Settle Up bottom-sheet UI keyed by friendship (mirrors the
  AddExpenseBottomSheet pattern from PR #38).
- `SettlementRepository.createSettlement(...)` write path on the
  abstract `SettlementStore` extended in PR #42.
- An `OBTSettleUpCard` affordance on `FriendDetailScreen` rendered
  between the header and the timeline when the net balance is
  non-zero (FR-SE-07 — "on every screen with non-zero balance"). The
  position is reserved in PR #42's screen but no card is currently
  rendered; FR-SE-08 inserts it via a clean diff.
- `settle_up_tapped` telemetry event (deferred from PR #42).
- Round-trip integration test: tap Settle Up → confirm → trigger
  recomputes → friendship's `simplifiedBalances` clears →
  `OBTBalancePill` flips to "Settled up".

**Out of scope:**

- Edit / delete settlement (separate later PR).
- Send reminder (FR-SE-09 — separate later PR).
- Group settlements (FR-GR-04 — Sprint 3 groups epic).

**Stories required before kickoff:**

- `docs/sprint-zero/stories/FR-SE-08-settle-up.md` (PM authors
  before architect handoff).

**Agents involved:** PM, Architect, Flutter Dev, QA.

Alternates (architect's call at PR #43 kickoff):

- **FR-EX-05 Receipt attachment (Step 3 of the bottom sheet).** Pairs
  with Storage rules R7-R8 from the Bucket-B burndown.
- **FR-EX-06 Edit / delete expense.** Natural follow-up to "I just
  added a wrong expense" and the read-only expense rows in PR #42.

---

## PR #44 — D5 deadline (Node 22 + firebase-functions 7.x)

**Status:** Planned. Deadline: 2026-10-31.

**Scope:**

The dedicated PR for **issues #39 + #40** — the deadline-bound D5
items surfaced by the post-PR #38 functions deploy:

- Cloud Functions runtime: Node 20 → Node 22 (issue #39).
- `firebase-functions` SDK: 6.x → 7.x (issue #40).

Both ship in the SAME PR so the runtime + SDK upgrade is atomic and
the rollback story is a single revert. Slot this PR before
mid-September 2026 to leave a comfortable buffer.

**Agents involved:** Functions Dev, DevOps, QA.

---

## PR #45 — TBD

**Status:** Slot reserved. Architect picks at PR #44 kickoff per Sprint 2 velocity.

Candidates:

- `lookup-user-by-phone-number` rate-limit doc-path bug fix (5 skipped
  integration tests).
- Post-PR #38 cleanup PR (the 3 S4 items: stale event names in 3 design
  docs; splitter test cap labels; missing `// TODO(SCR-08)` comment).
- A Bucket-B chore PR (e.g., the Storage rules R7-R8 chore that pairs
  with FR-EX-05).
- FR-EX-05 (Receipt attachment) if FR-SE-08 ships in PR #43 and the
  Sprint 2 budget allows.

---

## Sequencing rationale

After PR #42 the read-side of the simplified-debts round-trip is
closed end-to-end: a friendship member sees the friends-list net
balance chip, drills into Friend Detail, sees the underlying expense
ledger, taps the FAB to add a new expense, and watches the balance
pill + the new row appear via the snapshot stream. The natural next
step is to symmetrically close the SETTLEMENT round-trip — hence
FR-SE-08 as the PR #43 default.

PR #44 then de-risks the deploy path by retiring the Node 20
runtime + firebase-functions 6.x before the 2026-10-31 cutoff.

PR #45 picks up the highest-value backlog item per Sprint 2 velocity
at the PR #44 kickoff.

---

## Snapshot — Sprint 2 status at end of PR #42

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 9 (#31, #32, #34, #35, #36, #37, #38, #41, #42) |
| Story points delivered | 29 (PR #41 was 0 SP — pure docs cross-refs; PR #42 was 5 SP) |
| Bucket-B items closed | 5 (R1, R2, R3, CV3, SR8) |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 15 |
| Outstanding deadline-bound work | **D5 — Node 22 + firebase-functions 7.x (issues #39 + #40) by mid-September 2026** to ship before the 2026-10-31 cutoff |
