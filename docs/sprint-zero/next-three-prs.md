# Next Three PRs

> Rolling roadmap. Updated after PR #9 (FR-AU-06).
> Last updated: 2026-05-01.

---

## PR #10 — Session Persistence (FR-AU-07) and Sign-Out (FR-AU-08)

**Scope:** Persist the authenticated session so returning users skip the auth
flow. Implement sign-out from the profile screen. Splash screen routes correctly
based on session state and user document existence.

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FR-AU-07, FR-AU-08).

**Design artefacts:**
- Screen spec: `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md`
  (SCR-01 Splash routing).
- State management: `docs/design/07-technical/state-management.md`
  (`authStateProvider`, `currentUserProvider`).

**Agents involved:** flutter-dev, qa.

**Key deliverables:**
- Splash screen with auth state check and user doc check.
- Sign-out button and flow.
- Session persistence via `FirebaseAuth.authStateChanges()`.

---

## PR #11 — Simplified Debts Stub and Canonical Test Suite (FUNC-01)

**Scope:** Implement the `recomputeSimplifiedBalances` Cloud Function stub with
the canonical test matrix. This de-risks the critical path for Sprint 2
(expenses and settlements).

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FUNC-01).

**Design artefacts:**
- Cloud Functions catalogue:
  `docs/design/07-technical/cloud-functions-catalogue.md`.
- Test strategy: `.github/shared/test-strategy.md` (canonical test matrix).

**Agents involved:** functions-dev, architect, qa.

---

## PR #12 — Profile View and Edit (FR-PR-01)

**Scope:** Profile view/edit screen. Users can view their display name and
photo, change their display name, upload a new photo, and access the "Contact
Support" mailto link. Reads the `users/{userId}` document created in PR #9.

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FR-PR-01).

**Design artefacts:**
- Screen spec: `docs/design/06-screen-specs/23-28-settle-activity-profile.md`.
- Wireframe: `docs/design/04-wireframes/` (profile section).
- Mockup: `docs/design/05-mockups/08-profile-with-support.html`.

**Agents involved:** flutter-dev, qa.
