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
2. Read `.github/shared/srs-pointer.md` and then read the SRS requirement(s) it
   maps to in `docs/OneByTwo_Requirements_Spec.md` (version 1.1).
3. Read `.github/ISSUE_TEMPLATE/user_story.md` and at least one current
   `docs/sprint-zero/stories/*.md` example to preserve the section 13.2
   structure used in the repo.
4. Read `.github/shared/invariants.md` for constraint implications.
5. Identify gaps:
   a. Fewer than 3 scenarios? Add more.
   b. No negative case? Add at least one.
   c. Ambiguous language? Replace with precise Given/When/Then.
   d. Missing invariant checks? Add criteria for paise, simplifiedBalances,
      share sheet, or single project as relevant.
   e. Missing edge cases? Add boundary conditions grounded in the SRS and repo,
      such as zero amount, invalid +91 phone number, permission denial, or
      offline state.
   f. Feature-status drift? Correct it. Current client feature areas are
      activity, auth, expenses, friends, notifications, profile, reminders,
      settlements, and shell. Groups is planned only: schema and rules exist,
      but no client Groups UI exists.
6. Rewrite acceptance criteria in Given/When/Then format. Keep each scenario
   independently testable and label the negative case if useful.
7. Verify the Definition of Done checklist matches the issue template: code
   merged to main via approved PR; unit and widget tests written and passing;
   QA reviewed and verified; telemetry / analytics events in place;
   documentation updated if applicable.
8. Do not add SRS changes while refining a story. If the refinement needs a
   requirement change, stop and use `update-srs` to draft a proposal.

## Output format

Updated issue sections ready to replace the existing content:

1. Preconditions, if they need correction.
2. Acceptance Criteria with at least 3 Given/When/Then scenarios and at least
   1 negative case.
3. Definition of Done, if the existing checklist does not match the
   `.github/ISSUE_TEMPLATE/user_story.md` template.
4. Invariant Compliance notes, if the story touches money, `simplifiedBalances`,
   sharing, or Firebase project configuration.

## Validation checks

- [ ] At least 3 acceptance criteria after refinement.
- [ ] At least 1 negative case.
- [ ] Each criterion is independently testable.
- [ ] No ambiguous terms (e.g., "should work" replaced with measurable outcomes).
- [ ] Invariant-relevant checks included where applicable.
- [ ] Terminology matches `.github/shared/glossary.md`.
- [ ] No SRS edits are made as part of refinement.
- [ ] No invented PR numbers, issue numbers, or implemented feature claims.

## Examples

### Positive example

**Input:** Story for "record a settlement" with one vague acceptance criterion:
"User can record a settlement."

**Refined output:**
- Given I am on the friend detail screen showing a non-zero simplified balance,
  when I tap "Settle Up", then the amount and recipient are pre-filled from the
  simplified-debts suggestion.
- Given I confirm a settlement of ₹500.00, when it is saved, then
  `amountPaise` is stored as integer `50000`, `currency` is `INR`, and
  simplified balances are recomputed by the Cloud Function rather than by the
  client.
- Given I attempt to record a settlement for ₹0.00, when I tap Save, then I see
  a validation error and the settlement is not recorded.
- Given I am offline, when I record a settlement, then it is queued locally and
  synced when connectivity returns.

### Negative example (should refuse)

**Input:** "Add acceptance criteria for recurring expense splits."

**Response:** Refused. Recurring expenses are listed in SRS section 12.3 as out of
scope for v1.0. The story should not include this feature.
