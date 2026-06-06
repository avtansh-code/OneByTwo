# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #38.

---

## PR #39 — TBD at kickoff: FR-FR-04 vs FR-EX-05 vs FR-EX-06 vs `onExpenseWriteGroup`

**Status:** Next up. Unblocked.

**Scope:**

With PR #38 shipping FR-EX-01 (expense creation UI for the friendship
context), four candidates open up for PR #39. The architect makes the
final call at PR #39 kickoff; the recommendation order below reflects
PM priority.

- **Option A — FR-FR-04 Friend Detail full screen.** Replaces the
  `FriendDetailPlaceholderScreen` from PR #35 with a real per-friend
  transaction history. Now genuinely unblocked: PR #38 produces the
  expense documents that this screen reads. UI-heavy work; expands
  the friends epic; closes the simplified-debts round-trip from the
  user's point of view by surfacing the expense list alongside the
  net balance. **PM recommendation.**
- **Option B — FR-EX-05 Receipt attachment (Step 3).** The deferred
  third step of the Add Expense bottom sheet. PR #38 wires
  `ExpenseDoc.receiptUrl` as always-`null`; this PR adds the
  image-picker + Storage upload + `receiptUrl` write. Pairs
  naturally with the Storage rules R7-R8 chore from the Bucket-B
  burndown.
- **Option C — FR-EX-06 Edit / delete expense.** The natural
  follow-up to "I just added a wrong expense". Reuses the PR #38
  bottom-sheet scaffold and `split_calculator`. Soft-delete is
  already accepted by PR #36's trigger and PR #37's rules.
- **Option D — `onExpenseWriteGroup` trigger binding.** The
  deferred groups counterpart from PR #36 Architect Notes §2 and
  PR #37 Architect Notes §1. Sprint 3 preparatory work; could ship
  earlier if groups slip in from Sprint 3.

**Likely choice:** Option A (FR-FR-04). Reason: the simplified-debts
round-trip closes server-side via PR #36 / PR #37 and client-write-side
via PR #38, but the read-side surface beyond the friends-list
net-balance chip is still a placeholder. FR-FR-04 unblocks every
later expense and settlement UX flow that needs a per-friend ledger.

**Stories required before kickoff:**

- `docs/sprint-zero/stories/FR-FR-04-friend-detail.md` (Option A) —
  to be authored by PM before architect handoff.
- Stories for Options B / C / D to be authored against SRS §4.5
  (FR-EX-05, FR-EX-06) or lifted from PR #36 Architect Notes §2
  (Option D).

**Agents involved:** PM, Architect, Flutter Dev (Options A / B / C)
or Functions Dev (Option D), QA.

---

## PR #40 — FR-SE-08 Settle-Up UI OR PR #39 deferred item

**Status:** Planned.

**Scope:**

The default plan is **FR-SE-08 Settle-Up UI** — the first Flutter
client surface that produces settlement writes. Symmetric to PR #38
for settlements: PR #37 shipped the `onSettlementWrite` trigger that
consumes settlement documents, but the only producer today is the
admin SDK. FR-SE-08 closes the settlement round-trip from the user's
point of view.

Alternate: if PR #39 picks Option A (FR-FR-04 full screen), the
highest-value deferred candidate from PR #39's option set fills
PR #40 — most likely **FR-EX-05** (receipt attachment) since it pairs
with Storage rules R7-R8 from the Bucket-B burndown, or **FR-EX-06**
(edit / delete) if the "wrong expense" recovery flow is judged
higher value than receipts.

**Stories required before kickoff:**

- `docs/sprint-zero/stories/FR-SE-08-settle-up-ui.md` (default plan)
  — to be authored by PM during PR #39 review.

**Agents involved:** PM, Architect, Flutter Dev, QA.

---

## PR #41 — `lookup-user-by-phone-number` rate-limit doc-path bug fix OR Bucket-B chore PR

**Status:** Planned.

**Scope:**

Two candidates after PR #40:

- **Option A — `lookup-user-by-phone-number` rate-limit doc-path
  bug fix.** A pre-existing bug surfaced by PR #36's CI workflow
  change: `db.doc('_rateLimits/{uid}/lookups')` is an odd-component
  path that Firestore rejects. The five affected integration tests
  are still marked `describe.skip` with TODOs in the codebase (see
  PR #36 PR body and the Bucket-B burndown PR #36 NEW-finding note).
  Now ripe: by PR #41 we have shipped enough downstream features
  (PR #38 expense UI, PR #39 friend detail or extension, PR #40
  settle-up) that an isolated bug-fix PR has clear test surface
  and no merge contention. Unblocks 5 skipped integration tests.
- **Option B — Bucket-B chore PR.** A batch of small audit items
  now ripe for closure — the Sprint 2 polish set (M1 / S1 / S3 /
  S4 / CV2) or the telemetry sweep (#16 / #18-S5) recommended in
  `sprint-2-plan.md` §Sprint 2 Chore Backlog. Roughly 2-3 SP per
  bundle; clears down to ~30 Bucket-B remaining and unblocks the
  Sprint 3 ramp.

**Likely choice:** Option A first (pure bug-fix, isolated, unblocks
live integration tests). SP estimate to be sized by Architect at
kickoff. Option B becomes PR #42.

**Agents involved:** Functions Dev (Option A), or PM + Architect +
multiple devs (Option B), QA.

---

## Snapshot — Sprint 2 status at end of PR #38

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 7 (#31, #32, #34, #35, #36, #37, #38) |
| Story points delivered | 24 |
| Bucket-B items closed | 5 (R1, R2, R3, CV3, SR8) |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 13 (originally 14 — #25 closed) |
