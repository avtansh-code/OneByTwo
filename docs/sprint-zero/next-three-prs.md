# Next Three PRs

> Rolling roadmap. Updated after PR #11 (FR-AU-07/08 merged).
> Last updated: 2026-05-02.

---

## PR #12 — Simplified-Debts Cloud Function (FUNC-01)

**Status:** In flight.

**Scope:** Full implementation of the `recomputeSimplifiedBalances` Cloud
Function deployed as an HTTPS callable to `asia-south1`. Pure algorithm,
function boundary, Firestore rules for `simplifiedBalances` write-deny, and
the canonical six-case test matrix. Not yet wired as a Firestore trigger —
that arrives with the first expenses PR.

**User story:** `docs/sprint-zero/stories/FUNC-01-simplified-debts-stub.md`.

**Design artefacts:**
- Algorithm spec: `docs/design/07-technical/simplified-debts-algorithm.md`.
- Cloud Functions catalogue:
  `docs/design/07-technical/cloud-functions-catalogue.md` (section 1).
- Error codes: `docs/design/07-technical/cloud-functions-error-codes.md`.

**Agents involved:** functions-dev, architect, qa, devops.

---

## PR #13 — Profile View and Edit (FR-PR-01)

**Status:** Next up (closes Sprint 1).

**Scope:** Profile view/edit screen. Users can view their display name and
photo, change their display name, upload a new photo, and access the "Contact
Support" mailto link. Reads the `users/{userId}` document created in PR #10.

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FR-PR-01).

**Design artefacts:**
- Screen spec: `docs/design/06-screen-specs/23-28-settle-activity-profile.md`.
- Wireframe: `docs/design/04-wireframes/` (profile section).
- Mockup: `docs/design/05-mockups/08-profile-with-support.html`.

**Agents involved:** flutter-dev, qa.

---

## PR #14 — Sprint 2 Opener: Friend-Add via Contact Picker (FR-FR-01)

**Status:** Planned (Sprint 2).

**Scope:** Add-friend flow using the device contact picker. The user selects a
contact, the app resolves the +91 phone number, and either links to an existing
user or creates a pending friendship. Opens the social graph vertical.

**User story:** To be written (FR-FR-01 story refinement needed before PR opens).

**Agents involved:** flutter-dev, architect (friendship schema), qa.
