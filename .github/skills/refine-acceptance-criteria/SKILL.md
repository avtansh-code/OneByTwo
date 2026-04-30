---
name: refine-acceptance-criteria
description: >
  Use when an existing user story's acceptance criteria need improvement, expansion,
  or correction to meet the SRS section 13.2 standard.
---

# Refine Acceptance Criteria

## When to use

When a user story already exists but its acceptance criteria are incomplete, ambiguous,
missing negative cases, or not aligned with the current SRS or invariants.

## When NOT to use

- When no user story exists yet (use `new-user-story` instead).
- When the fundamental requirement needs changing (use `update-srs` instead).

## Inputs

1. **Existing user story** — the GitHub Issue or story text to refine.
2. **Feedback** — specific gaps identified by the Architect, QA, or reviewer.
3. **SRS requirement ID(s)** the story maps to.

## Procedure

1. Read the existing story and its current acceptance criteria.
2. Read the SRS requirement(s) it maps to in `docs/OneByTwo_Requirements_Spec.md`.
3. Read `.github/shared/invariants.md` for constraint implications.
4. Identify gaps:
   a. Fewer than 3 scenarios? Add more.
   b. No negative case? Add at least one.
   c. Ambiguous language? Replace with precise Given/When/Then.
   d. Missing invariant checks? Add criteria for paise, simplifiedBalances,
      share sheet, or single project as relevant.
   e. Missing edge cases? Add boundary conditions (e.g., zero amount, max group
      size, offline state).
5. Rewrite all acceptance criteria in Given/When/Then format.
6. Verify the Definition of Done checklist is complete.

## Output format

Updated acceptance criteria block, ready to replace the existing criteria in the
GitHub Issue.

## Validation checks

- [ ] At least 3 acceptance criteria after refinement.
- [ ] At least 1 negative case.
- [ ] Each criterion is independently testable.
- [ ] No ambiguous terms (e.g., "should work" replaced with measurable outcomes).
- [ ] Invariant-relevant checks included where applicable.
- [ ] Terminology matches `.github/shared/glossary.md`.

## Examples

### Positive example

**Input:** Story for "record a settlement" with one acceptance criterion:
"User can record a settlement."

**Refined output:**
- Given I am on the friend detail screen showing a non-zero simplified balance,
  when I tap "Settle Up", then the amount and recipient are pre-filled from the
  simplified-debts suggestion.
- Given I confirm a settlement of 500 rupees, when it is saved, then
  `amountPaise` is stored as 50000 and simplified balances are recomputed by the
  Cloud Function.
- Given I attempt to record a settlement for 0 rupees, when I tap Save, then I
  see a validation error and the settlement is not recorded.
- Given I am offline, when I record a settlement, then it is queued locally and
  synced when connectivity returns.

### Negative example (should refuse)

**Input:** "Add acceptance criteria for recurring expense splits."

**Response:** Refused. Recurring expenses are listed in SRS section 12.3 as out of
scope for v1.0. The story should not include this feature.
