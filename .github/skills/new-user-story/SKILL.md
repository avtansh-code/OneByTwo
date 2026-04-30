---
name: new-user-story
description: >
  Use when a new user story needs to be created from an SRS functional requirement.
---

# New User Story

## When to use

When a functional requirement from the SRS (FR-XX-NN) needs to be converted into a
user story with acceptance criteria, ready for the Architect to design and developers
to implement.

## When NOT to use

- When the user story already exists and only needs acceptance criteria refinement
  (use `refine-acceptance-criteria` instead).
- When the task is a bug fix (use `triage-bug` instead).
- When the task is an SRS change (use `update-srs` instead).

## Inputs

1. **SRS requirement ID** (e.g., FR-EX-01) or a description of the feature area.
2. **Priority** (P0 / P1 / P2) as stated in the SRS.
3. **Context** — any prior design decisions or ADRs that affect this story.

## Procedure

1. Read the SRS requirement at the given ID in `docs/OneByTwo_Requirements_Spec.md`.
2. Read `.github/shared/invariants.md` to check for constraint implications.
3. Read `.github/shared/glossary.md` to ensure consistent terminology.
4. Write the user story in the format defined by SRS section 13.2:
   a. **Title:** concise feature title.
   b. **Story:** As a `<user role>`, I want `<capability>` so that `<benefit>`.
   c. **Preconditions:** state required before the scenario.
   d. **Acceptance Criteria:** at least 3 Given/When/Then scenarios, including at
      least 1 negative case. Each scenario must be independently testable.
   e. **Definition of Done:** code merged, tests written and passing, QA verified,
      telemetry in place, docs updated.
5. Tag the story with the SRS requirement ID(s) it covers.
6. Assign priority (P0 / P1 / P2) matching the SRS.
7. If the requirement touches money, include a criterion verifying integer paise.
8. If the requirement touches sharing, include a criterion verifying system share
   sheet usage.

## Output format

A GitHub Issue body using the `user_story` issue template, with all fields completed.

## Validation checks

- [ ] Story references at least one SRS requirement ID.
- [ ] At least 3 acceptance criteria are present.
- [ ] At least 1 negative case is included.
- [ ] Definition of Done checklist is complete.
- [ ] No invariant violations in the acceptance criteria.
- [ ] Terminology matches `.github/shared/glossary.md`.

## Examples

### Positive example

**Input:** FR-EX-01 (add an expense with amount, description, date, category,
payer, split method, and optional notes).

**Output:**
- Title: Add expense with split method selection
- Story: As a user, I want to add an expense with a description, amount, date,
  category, payer, and split method so that the cost is tracked and split among
  participants.
- Acceptance Criteria:
  - Given I am on the group detail screen, when I tap the FAB and fill in all
    required fields with an equal split, then the expense is saved and simplified
    balances update.
  - Given I enter an amount of 150.50 rupees, when the expense is saved, then the
    stored `amountPaise` is 15050 (integer).
  - Given I select "By Percentage" and the percentages do not sum to 100%, when I
    tap Save, then I see an inline error and the expense is not saved.

### Negative example (should refuse)

**Input:** "Create a story for UPI payment integration."

**Response:** Refused. UPI integration is listed in SRS section 12.3 as out of
scope for v1.0. This story cannot be created until a future SRS revision includes
it.
