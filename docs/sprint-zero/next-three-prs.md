# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #35.

---

## PR #36 — `recomputeSimplifiedBalances` Cloud Function Trigger (likely)

**Status:** Next up. Unblocked.

**Scope:** Cloud Function trigger that materialises the
`simplifiedBalances` field on `friendships/{friendshipId}` (and later
`groups/{groupId}`) documents whenever an expense or settlement is
created, updated, or deleted. This is the production WRITER for the
field that PR #35 introduced as a READER. Until this trigger ships,
`simplifiedBalances` only appears on docs seeded manually (tests).

The pure simplification algorithm already exists at
`functions/src/simplified-debts/` (PR #12, FUNC-01). PR #36 wraps it in
a Firestore trigger, persists the output, and updates `lastActivityAt`.

**Story:** TBD (PM to draft a story for the trigger; the algorithm
itself is covered by FUNC-01 / SE-01).

**Agents involved:** Functions Dev, Architect (rules for the
service-account write path), QA.

---

## PR #37 — FR-FR-04 Friend Detail Screen OR FR-EX-01 Expense Creation

**Status:** Planned.

**Scope:**
- **Option A — FR-FR-04 (Friend Detail Screen):** replaces the
  `FriendDetailPlaceholderScreen` shipped in PR #35 with the real SCR-11
  detail screen (transaction history, settle-up CTA, delete option).
  Depends on at least the friend-scoped expense list being available
  (so depends on PR #36 having produced `lastActivityAt` updates that
  the detail view can show).
- **Option B — FR-EX-01 (Expense Creation):** unblocks Expenses epic,
  which the Cloud Function trigger in PR #36 will then have something
  meaningful to recompute.

Final determination at PR #37 kickoff after PM/architect review.

**Agents involved:** TBD per chosen scope.

---

## PR #38 — TBD per Sprint 2 Velocity

**Status:** Planned.

**Scope:** To be determined based on Sprint 2 velocity and the
PR #36/#37 outcomes.
