---
name: Bug Report
description: Report a bug in OneByTwo.
labels: ["bug"]
body:
  - type: dropdown
    id: severity
    attributes:
      label: Severity
      description: >
        Classify per SRS section 10.5. S1 = crash/data loss/wrong balances;
        S2 = feature broken, no workaround; S3 = broken with workaround;
        S4 = polish/trivial.
      options:
        - S1 — Critical
        - S2 — Major
        - S3 — Minor
        - S4 — Trivial
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear, concise description of the bug.
    validations:
      required: true

  - type: textarea
    id: repro-steps
    attributes:
      label: Steps to Reproduce
      description: Numbered steps to reproduce the behaviour.
      placeholder: |
        1. Open the app.
        2. Navigate to ...
        3. Tap ...
        4. Observe ...
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behaviour
      description: What should happen.
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behaviour
      description: What actually happens.
    validations:
      required: true

  - type: dropdown
    id: device-tier
    attributes:
      label: Device Tier (SRS section 10.3)
      options:
        - "Tier 1: iPhone 12/14 (iOS 17), Pixel 6 (Android 14), Samsung Galaxy A (Android 13)"
        - "Tier 2: iPhone SE 2nd gen (iOS 14), Xiaomi Redmi (Android 11), low-end (Android 8)"
        - "Tier 3: iPad / Tablet (post-v1.0)"
        - "Other"
    validations:
      required: true

  - type: input
    id: device-model
    attributes:
      label: Device Model
      placeholder: e.g., Pixel 6, iPhone 14

  - type: input
    id: os-version
    attributes:
      label: OS Version
      placeholder: e.g., Android 14, iOS 17.2

  - type: input
    id: app-version
    attributes:
      label: App Version
      placeholder: e.g., v1.0.0

  - type: textarea
    id: screenshots
    attributes:
      label: Screenshots / Recordings
      description: Attach any relevant screenshots or screen recordings.

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other relevant information (network conditions, account state, etc.).
