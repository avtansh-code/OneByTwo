---
name: Feature Request
description: Propose a new feature or enhancement for One By Two.
labels: ["enhancement"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      description: >
        What problem does this feature solve? Reference the relevant SRS
        section if applicable.
    validations:
      required: true

  - type: textarea
    id: proposed-solution
    attributes:
      label: Proposed Solution
      description: Describe the feature you would like to see.
    validations:
      required: true

  - type: dropdown
    id: priority
    attributes:
      label: Suggested Priority
      options:
        - P0 — Must have
        - P1 — Should have
        - P2 — Nice to have
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: Any alternative solutions or features you have considered.

  - type: checkboxes
    id: invariant-check
    attributes:
      label: Invariant Compliance
      description: >
        Confirm this request does not violate any project invariant
        (.github/shared/invariants.md).
      options:
        - label: This feature does not require float-based money (all amounts remain integer paise).
          required: true
        - label: This feature does not write to simplifiedBalances from the client.
          required: true
        - label: This feature does not add platform-specific share targets.
          required: true
        - label: This feature does not require a second Firebase project.
          required: true

  - type: checkboxes
    id: scope-check
    attributes:
      label: Scope Check
      description: Confirm this is within v1.0 scope.
      options:
        - label: This feature is NOT listed in SRS section 12.3 (out of scope for v1.0).
          required: true

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other relevant information, mockups, or references.
