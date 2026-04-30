# Handover to Development

## Summary

This document formally hands the design package to the development team. The
design phase is complete. All design decisions, screen specifications, technical
blueprints, and sprint plans have been reviewed and approved by the full agent
team. This handover marks the transition from design to implementation.

---

## Design Package Contents

| Phase | Directory | Files | Summary |
|-------|-----------|-------|---------|
| 1 | `01-information-architecture/` | 4 | Site map, navigation flow, 12 user journeys, extension points |
| 2 | `02-design-system/` | 5 | Design tokens, 25-component catalogue, typography and formatting, motion and interaction, design system extension points |
| 3 | `03-architecture/` | 7 | C4 diagrams (system context, container, component), data flow sequences, deployment topology, non-functional design, architecture extension points |
| 4 | `04-wireframes/` | 9 | Lo-fi wireframes for all 9 major flows |
| 5 | `05-mockups/` | 9 | 8 hi-fi HTML hero screen mockups plus README |
| 6 | `06-screen-specs/` | 7 | 28 detailed screen specifications across 6 files plus README |
| 7 | `07-technical/` | 12 | Firestore schema, security rules, Cloud Functions catalogue, simplified-debts algorithm, state management, offline and sync, notifications, telemetry plan, error and empty state taxonomy, accessibility spec, test design, extension points register |
| 8 | `08-plan/` | 5 | Sprint sequence, dependency DAG, risks revisited, Definition of Ready and Done, this handover document |

**Total: 58 artefacts.**

---

## Sprint 1 Readiness

Sprint 1 is ready to begin. The following prerequisite artefacts are in place:

- **Stories defined** in `docs/sprint-zero/sprint-1-plan.md` — covering
  FR-AU-01 through FR-AU-08, FR-PR-01, INFRA-01, and FUNC-01 (43 SP).
- **First implementation story expanded** in
  `docs/sprint-zero/first-story-FR-AU-01.md` — full acceptance criteria,
  widget tree, provider shape, input formatter, and QA edge cases.
- **Firebase and DevOps readiness checklist** at
  `docs/sprint-zero/devops-readiness-checklist.md`.
- **All design artefacts for Sprint 1 screens** are complete — wireframes,
  mockups, and screen specs for the authentication flow.

---

## Invariants Reminder

These four constraints are non-negotiable. A violation is a blocking defect.

1. **Money is integer paise.** All monetary values are stored and transmitted as
   integer paise (1 INR = 100 paise). Conversion to rupees happens exclusively
   at the UI layer. Floats are never used for money. — SRS section 7.3

2. **`simplifiedBalances` is server-maintained and client-read-only.** Written
   solely by the `recomputeSimplifiedBalances` Cloud Function. Clients may read
   but must never write. Enforced by Firestore Security Rules.
   — SRS sections 4.6, 7.3, 7.5

3. **System share sheet only.** All outbound sharing uses the platform's system
   share sheet. The app must not target or import packages for any specific
   messaging app. — SRS sections 3.4, 4.11, 12.2

4. **Single Firebase project.** Exactly one Firebase project: production. No
   staging or development projects. All pre-merge testing runs against the
   Firebase Emulator Suite. — SRS sections 3.4, 9.1

---

## Agent Responsibilities for Sprint 1

| Agent | Sprint 1 Tasks |
|-------|----------------|
| **DevOps** | INFRA-01: Firebase project config, emulator suite, CI pipeline, branch protection |
| **Flutter Dev** | FR-AU-01 to FR-AU-08: Auth screens. FR-PR-01: Profile screen |
| **Functions Dev** | FUNC-01: Simplified-debts stub with canonical test suite |
| **Architect** | Review PRs for schema/security compliance. Confirm ADR-0004 (Riverpod) |
| **QA** | Review PRs, verify acceptance criteria, test against emulator |
| **Designer** | Available for visual questions during implementation |

---

## Working Agreements

- All code merged to `main` via pull request. No direct pushes.
- Every PR requires at least one approval (Architect or QA).
- All tests run against the Firebase Emulator Suite only.
- Commit messages follow Conventional Commits format.
- British English throughout code, comments, and documentation.
- No emojis in code, comments, or documentation.

---

## Sign-Off

This design package has been reviewed and approved by:

- **Product Manager** — Scope, user stories, and acceptance criteria are
  complete. The backlog is prioritised and Sprint 1 stories are ready.
- **Solution Architect** — Technical design is sound. All four invariants are
  honoured. Extension points are documented for post-v1.0 growth.
- **QA Engineer** — Test design covers all critical user journeys. Coverage
  targets are achievable. The canonical test matrix is ready.
- **DevOps Engineer** — Deployment topology and CI/CD pipeline design are
  implementable. The single-Firebase-project constraint is respected.
- **UX/UI Designer** — Visual system, wireframes, mockups, and screen
  specifications are complete. Accessibility requirements are documented.

---

The development team may now begin Sprint 1.
