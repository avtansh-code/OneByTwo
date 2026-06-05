# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #36.

---

## PR #37 — `onSettlementWrite` Trigger OR FR-EX-01 Expense Creation

**Status:** Next up. Unblocked.

**Scope:**

- **Option A — `onSettlementWrite` Firestore trigger.** The natural
  successor to PR #36. Completes the trigger-pair pattern
  (expense + settlement) so `simplifiedBalances` is recomputed
  automatically on settlement creates as well. Different path:
  `settlements/{settlementId}` (top-level collection, NOT a subcollection
  of the context document). Different write semantics: settlements also
  carry `verificationStatus` which is server-only writable (parallel to
  the `simplifiedBalances` invariant for the parent friendship). FCM
  notifies the recipient — but the FCM side-effect is still deferred
  to FR-AC-03; the trigger ships compute-only with a hand-off seam.
- **Option B — FR-EX-01 Expense Creation UI (Flutter).** Unblocks the
  Expenses epic and produces the first real expense writes that PR #36's
  `onExpenseWriteFriendship` trigger consumes. Validates the trigger
  end-to-end in a production flow with real users. Larger Flutter scope
  (new screen, new form, new Riverpod controller, telemetry).

Final determination at PR #37 kickoff after PM/architect review.

**Likely choice:** Option A. Reason: settlements are server-side concerns
(same shape as expenses), keeping the trigger pair coherent before the
client-side expense creation work expands into Flutter UI scope.

**Story:** TBD per chosen option.

**Agents involved:** Functions Dev (trigger) or Flutter Dev (UI),
Architect, QA.

---

## PR #38 — TBD per PR #37 outcome

**Status:** Planned.

**Scope:**
- If PR #37 = Option A (`onSettlementWrite`), PR #38 likely = FR-EX-01
  (expense creation UI).
- If PR #37 = Option B (FR-EX-01), PR #38 likely = `onSettlementWrite`.

> ### ⚠ Mandatory bundle when PR #38 = FR-EX-01
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

**Agents involved:** TBD.

---

## PR #39 — TBD per Sprint 2 Velocity

**Status:** Planned.

**Scope:** To be determined based on Sprint 2 velocity and the
PR #37/#38 outcomes. Candidates:
- FR-FR-04 (Friend Detail Screen) replacing the placeholder from PR #35.
- `onExpenseWriteGroup` trigger binding (the deferred groups
  counterpart from PR #36 architect notes §2).
- Bucket-B chore PR (a batch of small audit items now ripe for closure).
- Pre-existing `lookup-user-by-phone-number` rate-limit doc-path bug
  fix (surfaced by PR #36's CI workflow change — see PR #36 PR body).
