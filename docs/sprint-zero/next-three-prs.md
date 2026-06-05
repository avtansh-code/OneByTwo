# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #37.

---

## PR #38 — FR-EX-01 Expense Creation UI (Flutter)

**Status:** Next up. Unblocked.

**Scope:**

FR-EX-01: Flutter UI for creating an expense within a friendship context.
The first client producer of expense writes that PR #36's
`onExpenseWriteFriendship` trigger consumes. Now that PR #37 has
shipped the settlement trigger pair, the next pivot to Flutter UI work
is natural — the trigger pair is complete; we can ship UI that
exercises both ends without further server-side work.

Includes:
- New screen `lib/features/expenses/presentation/add_expense_screen.dart`
  with an amount input (paise integer enforcement), description,
  category selector, split picker, payer dropdown.
- New Riverpod controller `addExpenseController` driving validation and
  the Firestore write to `friendships/{fid}/expenses/{eid}`.
- Telemetry events per the chore #25 decision (see Critical Constraint
  C-1 below — MUST be bundled).
- Widget tests + integration test seeding A→B and reading the resulting
  `simplifiedBalances` after the trigger fires.

> ### ⚠ Mandatory bundle — chore #25 (expense event naming)
>
> Per **Critical Constraint C-1** in `docs/sprint-zero/sprint-2-plan.md`,
> chore [#25](https://github.com/avtansh-code/OneByTwo/issues/25)
> (expense event naming convention decision) MUST be resolved in the
> SAME PR as FR-EX-01. PR #38 cannot ship without:
> 1. The naming decision recorded in
>    `docs/design/07-technical/telemetry-plan.md`.
> 2. All expense events in `lib/features/expenses/**` using the chosen
>    names.
> 3. Issue #25 closed in the PR body (`Closes #25`).
>
> The orchestrator MUST refuse to start FR-EX-01 implementation work
> until the decision is recorded in the story file's Architect Notes.

**Story:** `docs/sprint-zero/stories/FR-EX-01-expense-creation.md`
(to be authored).

**Agents involved:** Flutter Dev, PM, Architect (for chore #25 decision),
QA.

---

## PR #39 — FR-FR-04 Friend Detail Screen OR `onExpenseWriteGroup`

**Status:** Planned.

**Scope:**

Two candidates after PR #38:

- **Option A — FR-FR-04 Friend Detail Screen.** Replaces the placeholder
  from PR #35 with a real per-friend transaction history. Depends on
  FR-EX-01 (PR #38) shipping first so there is actual expense data to
  display. UI-heavy work; expands the friends epic.
- **Option B — `onExpenseWriteGroup` trigger binding.** The deferred
  groups counterpart from PR #36 architect notes §2 and PR #37
  architect notes §1. Adds a parallel trigger registration plus the
  groups expense security rules block. Sprint 3 (groups epic)
  preparatory work; could ship earlier if groups arrive sooner than
  expected.

Final determination at PR #39 kickoff.

**Likely choice:** Option A. Reason: FR-FR-04 is the natural
client-side follow-up to FR-EX-01 — once expenses can be created,
viewing them in a per-friend list is the next user-visible value.

---

## PR #40 — TBD per Sprint 2 Velocity

**Status:** Planned.

**Scope:** To be determined based on Sprint 2 velocity and the
PR #38/#39 outcomes. Candidates:
- The deferred `onExpenseWriteGroup` trigger binding if not picked up
  by PR #39.
- Bucket-B chore PR (a batch of small audit items now ripe for closure;
  see Sprint 2 Chore Backlog in `sprint-2-plan.md`).
- Pre-existing `lookup-user-by-phone-number` rate-limit doc-path bug
  fix (surfaced by PR #36's CI workflow change — see PR #36 PR body;
  5 `describe.skip`'d integration tests are still in the codebase).
- FR-SE-08 Settle-Up UI (the Flutter client surface that produces
  settlement writes — the first client producer of the settlement
  trigger shipped in PR #37).
