---
name: User Story
description: >
  Define a user story with acceptance criteria per SRS section 13.2.
labels: ["user-story"]
body:
  - type: input
    id: title
    attributes:
      label: Story Title
      description: A concise feature title.
    validations:
      required: true

  - type: input
    id: srs-refs
    attributes:
      label: SRS Requirement ID(s)
      description: >
        The functional requirement(s) this story covers (e.g., FR-EX-01,
        FR-SE-03).
    validations:
      required: true

  - type: dropdown
    id: priority
    attributes:
      label: Priority
      options:
        - P0 — Must have
        - P1 — Should have
        - P2 — Nice to have
    validations:
      required: true

  - type: textarea
    id: story
    attributes:
      label: User Story
      description: "As a <user role>, I want <capability> so that <benefit>."
      placeholder: |
        As a [user role],
        I want [capability]
        so that [benefit].
    validations:
      required: true

  - type: textarea
    id: preconditions
    attributes:
      label: Preconditions
      description: State required before the scenario.
    validations:
      required: true

  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: >
        At least 3 Given/When/Then scenarios, including at least 1 negative case.
        Each scenario must be independently testable.
      placeholder: |
        **Scenario 1 (happy path):**
        Given ...
        When ...
        Then ...

        **Scenario 2:**
        Given ...
        When ...
        Then ...

        **Scenario 3 (negative case):**
        Given ...
        When ...
        Then ...
    validations:
      required: true

  - type: checkboxes
    id: definition-of-done
    attributes:
      label: Definition of Done
      description: All items must be completed before the story is closed.
      options:
        - label: Code merged to main via approved PR.
          required: true
        - label: Unit and widget tests written and passing.
          required: true
        - label: QA reviewed and verified.
          required: true
        - label: Telemetry / analytics events in place.
          required: true
        - label: Documentation updated (if applicable).
          required: true

  - type: checkboxes
    id: invariant-check
    attributes:
      label: Invariant Compliance
      description: Verify this story respects all project invariants.
      options:
        - label: Money values are integer paise (invariant 1).
          required: true
        - label: No client writes to simplifiedBalances (invariant 2).
          required: true
        - label: Uses system share sheet only (invariant 3).
          required: true
        - label: Single Firebase project (invariant 4).
          required: true

  - type: textarea
    id: notes
    attributes:
      label: Implementation Notes
      description: >
        Optional notes for the Architect or Developer — design considerations,
        related ADRs, affected feature folders, etc.
