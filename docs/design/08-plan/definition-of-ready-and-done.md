# Definition of Ready and Definition of Done

This document codifies the entry and exit criteria for every user story in the
One By Two product backlog. It draws from the acceptance criteria template
(SRS section 13.2), the shared invariants (`.github/shared/invariants.md`),
the test strategy (`.github/shared/test-strategy.md`), the coding standards
(`.github/shared/coding-standards.md`), and the handoff contracts
(`.github/shared/handoffs.md`).

All agents and all reviewers must treat these definitions as binding. A story
that does not satisfy every item in the relevant checklist must not advance.

---

## Definition of Ready (DoR)

A story is ready to enter a sprint when **all** of the following are true.

### 1. User story written in SRS section 13.2 format

- **Title:** a concise feature title.
- **Story:** "As a `<user role>`, I want `<capability>` so that `<benefit>`."
- **Preconditions:** the state required before the story can be exercised.
- **Acceptance Criteria:** at least three Given/When/Then scenarios, including
  at least one negative case.
- **Definition of Done reference:** a pointer to this document.

The story must reference the originating SRS functional requirement ID(s)
(e.g. FR-EX-01). This is required by the PM-to-Architect handoff contract
(`.github/shared/handoffs.md`, "PM to Architect" edge).

### 2. Design artefacts exist

- A screen specification in `docs/design/06-screen-specs/` covers every screen
  the story touches.
- A wireframe in `docs/design/04-wireframes/` exists for the flow.
- Component catalogue entries in `docs/design/02-design-system/components.md`
  exist for all required components.

### 3. Technical design available

- Firestore schema fields are documented in
  `docs/design/07-technical/firestore-schema.md`.
- If the story involves a Cloud Function, the function is catalogued in
  `docs/design/07-technical/cloud-functions-catalogue.md`.
- The Riverpod provider shape is identified in
  `docs/design/07-technical/state-management.md`.

### 4. Dependencies cleared

All upstream stories in the dependency DAG
(`docs/design/08-plan/dependencies-and-critical-path.md`) are marked done.

### 5. Telemetry events identified

Analytics events for the screen or flow are listed in
`docs/design/07-technical/telemetry-plan.md`.

### 6. Accessibility requirements identified

Semantic labels, focus order, and screen-reader expectations are documented in
`docs/design/07-technical/accessibility-spec.md`.

### 7. Edge cases documented

The screen specification includes at least three edge cases per screen.

### 8. Story points estimated

The team has estimated the story and recorded the estimate on the backlog issue.

### 9. Invariant applicability assessed

The story explicitly notes which of the four invariants
(`.github/shared/invariants.md`) are relevant and how compliance will be
verified:

1. Money is integer paise (SRS section 7.3).
2. `simplifiedBalances` is server-maintained and client-read-only
   (SRS sections 4.6, 7.3, 7.5).
3. System share sheet only (SRS sections 3.4, 4.11, 12.2).
4. Single Firebase project (SRS sections 3.4, 9.1).

---

## Definition of Done (DoD)

A story is done when **all** of the following are true.

### 1. Code merged to `main` via an approved pull request

- At least one approving review (QA for QA-impacting changes, Architect for
  schema/security/simplified-debts changes).
- PR follows Conventional Commits format
  (`.github/shared/coding-standards.md`).

### 2. Tests passing

- **Unit tests** written and passing for all non-UI logic.
- **Widget tests** written and passing for UI changes.
- **Integration tests** passing against the Firebase Emulator Suite.
- **Coverage thresholds not regressed:** >= 70% non-UI, >= 50% overall.
- **Simplified-debts module:** 100% branch coverage of the canonical test
  matrix (if touched).
- No new lint warnings.

### 3. QA verified

QA has reviewed the PR, executed acceptance criteria scenarios (including the
negative case), and posted an explicit sign-off comment.

### 4. Telemetry in place

All analytics events from `docs/design/07-technical/telemetry-plan.md` for
this story are firing correctly.

### 5. Accessibility verified

- Semantic labels present on all interactive widgets.
- Screen-reader testing performed on at least one Tier 1 device.

### 6. Dark mode checked

The screen renders correctly in both light and dark themes with WCAG AA
contrast ratios.

### 7. Invariant compliance confirmed

All four invariants verified as applicable:

1. No `double` or `float` for monetary storage or transmission.
2. No client code writes to `simplifiedBalances`.
3. No app-specific share packages imported.
4. No second Firebase project ID introduced.

### 8. Documentation updated

- Screen specification updated if scope shifted.
- Firestore schema documentation updated if fields changed.
- ADR logged if a new architectural decision was made.

### 9. No open S1 or S2 bugs

No bug with severity S1 (Critical) or S2 (Major) related to this story
remains open.

---

## Cross-References

| Source | Relevance |
|---|---|
| SRS section 13.2 | Acceptance criteria template |
| `.github/shared/invariants.md` | Four non-negotiable constraints |
| `.github/shared/test-strategy.md` | Coverage thresholds, canonical test matrix, device matrix, bug severities |
| `.github/shared/coding-standards.md` | Lint rules, commit format, money handling |
| `.github/shared/handoffs.md` | Review requirements, handoff contracts |
