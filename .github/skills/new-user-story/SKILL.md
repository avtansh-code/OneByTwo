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
4. **Target surface** — one of the current repo feature areas where applicable:
   activity, auth, expenses, friends, notifications, profile, reminders,
   settlements, or shell. Groups is planned only; the repo currently has schema
   and rules plus a shell placeholder, but no client Groups UI.

## Procedure

1. Read `.github/shared/srs-pointer.md` and then read the referenced SRS
   requirement in `docs/OneByTwo_Requirements_Spec.md` (version 1.1).
2. Read `.github/ISSUE_TEMPLATE/user_story.md` for the required issue fields.
3. Read at least one current example in `docs/sprint-zero/stories/*.md` to match
   the repo's story style without copying obsolete details.
4. Read `.github/shared/invariants.md` to check for constraint implications.
5. Read `.github/shared/glossary.md` to ensure consistent terminology.
6. Write the user story in the SRS section 13.2 / issue-template structure:
   a. **Story Title:** concise feature title.
   b. **SRS Requirement ID(s):** one or more existing SRS IDs.
   c. **Priority:** P0 — Must have, P1 — Should have, or P2 — Nice to have.
   d. **User Story:** As a `<user role>`, I want `<capability>` so that
      `<benefit>`.
   e. **Preconditions:** required state before the scenarios.
   f. **Acceptance Criteria:** at least 3 independently testable
      Given/When/Then scenarios, including at least 1 negative case.
   g. **Definition of Done:** code merged to main via approved PR; unit and
      widget tests written and passing; QA reviewed and verified; telemetry /
      analytics events in place; documentation updated if applicable.
   h. **Invariant Compliance:** all four invariant checks from the issue template.
   i. **Implementation Notes:** optional notes grounded in existing repo paths,
      ADRs, stories, or handoff contracts.
7. If the requirement touches money, include an acceptance criterion verifying
   integer paise storage and INR-only display conversion at the UI layer.
8. If the requirement touches `simplifiedBalances`, state that clients read it
   only and Cloud Functions recompute it.
9. If the requirement touches sharing, include a criterion verifying the platform
   system share sheet only.
10. If the requirement touches Firebase, keep it within the single production
    project (`onebytwo-avtanshgupta`) and emulator-based pre-merge testing.
11. Assign the new issue to exactly one sprint milestone — the sprint that owns the
    requirement per `docs/design/08-plan/sprint-sequence.md` (the current next active
    sprint is `Sprint 3`) — and comment the milestone choice with a one-line
    rationale, per `.github/shared/milestone-tracking.md`.

## Output format

A GitHub Issue body using `.github/ISSUE_TEMPLATE/user_story.md`, with these
fields completed in order:

1. Story Title
2. SRS Requirement ID(s)
3. Priority
4. User Story
5. Preconditions
6. Acceptance Criteria
7. Definition of Done
8. Invariant Compliance
9. Implementation Notes

## Validation checks

- [ ] Story references at least one SRS requirement ID.
- [ ] At least 3 acceptance criteria are present.
- [ ] At least 1 negative case is included.
- [ ] Definition of Done checklist is complete.
- [ ] No invariant violations in the acceptance criteria.
- [ ] Terminology matches `.github/shared/glossary.md`.
- [ ] The story does not invent PR numbers, issue numbers, feature status, or
      SRS requirements.
- [ ] Groups UI is not described as implemented.
- [ ] The issue is assigned to exactly one sprint milestone per
      `.github/shared/milestone-tracking.md`.

## Examples

### Positive example

**Input:** FR-EX-01 (add an expense with amount, description, date, category,
payer, split method, and optional notes).

**Output:**
- Story Title: Add expense with split method selection
- SRS Requirement ID(s): FR-EX-01
- Priority: P0 — Must have
- User Story: As an authenticated friendship member, I want to add an expense
  with a description, amount, date, category, payer, and split method so that
  the cost is tracked against the friendship.
- Preconditions: The user is authenticated and can open a friendship detail
  surface from the friends feature.
- Acceptance Criteria:
  - Given I am on a friendship detail surface, when I tap the FAB and complete
    the expense form with a valid equal split, then an expense document is
    written for that friendship.
  - Given I enter ₹150.50 in the UI, when the expense is saved, then the write
    stores `amountPaise` as integer `15050` and `currency` as `INR`.
  - Given the split amounts do not sum exactly to the total, when I try to save,
    then I see an inline validation error and the expense is not written.
- Definition of Done: Complete every required checkbox from the user-story issue
  template.
- Invariant Compliance: Money is integer paise; the client does not write
  `simplifiedBalances`; sharing, if any, uses the system share sheet; no second
  Firebase project is introduced.

### Negative example (should refuse)

**Input:** "Create a story for UPI payment integration."

**Response:** Refused. UPI integration is listed in SRS section 12.3 as out of
scope for v1.0. This story cannot be created until a future SRS revision includes
it.
