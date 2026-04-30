# Copilot Instructions — OneByTwo

## Product

**OneByTwo** is an India-focused expense-sharing mobile application (iOS and Android)
built with Flutter and backed by a single Firebase project. The Software Requirements
Specification is the single source of truth:
`docs/OneByTwo_Requirements_Spec.md` (version 1.1).

---

## Invariants

These four constraints are non-negotiable. Every change must respect them. Violations
are blocking defects.

1. **Money is integer paise.** All monetary values are stored and transmitted as
   integer paise (1 INR = 100 paise). Conversion to rupees happens exclusively at
   the UI layer. Never use floats for money. — SRS section 7.3

2. **`simplifiedBalances` is server-maintained and client-read-only.** The
   `simplifiedBalances` field on `friendships` and `groups` documents is written
   solely by the `recomputeSimplifiedBalances` Cloud Function. Clients may read it
   but must never write to it. Enforced by Firestore Security Rules.
   — SRS sections 4.6, 7.3, 7.5

3. **System share sheet only.** All outbound sharing uses the platform's system share
   sheet. The app must not target or import packages for any specific messaging app.
   — SRS sections 3.4, 4.11, 12.2

4. **Single Firebase project.** Exactly one Firebase project exists: production.
   No staging or development projects. All pre-merge testing runs against the
   Firebase Emulator Suite. — SRS sections 3.4, 9.1

---

## Technology Stack

| Layer | Technology | Constraint |
|---|---|---|
| Frontend | Flutter (latest stable), Dart, Riverpod 2.x | Feature-first folder layout (SRS section 13.1) |
| Backend | Firebase (Auth, Firestore, Cloud Functions, Storage, FCM, Crashlytics, Analytics) | Single production project |
| Cloud Functions | Node 20, TypeScript | Region: `asia-south1` (Mumbai) |
| Auth | Firebase Phone Auth | +91 numbers only |
| Currency | INR only | Stored as integer paise |
| CI/CD | GitHub Actions | PR pipeline + release pipeline (SRS section 9.2) |

---

## Agent Team

For any non-trivial task, delegate to the orchestrator agent:
`.github/agents/orchestrator.md`

The orchestrator routes work to the appropriate specialist agent:

| Agent | File | Scope |
|---|---|---|
| Orchestrator | `.github/agents/orchestrator.md` | Task routing and sequencing |
| Product Manager | `.github/agents/pm.md` | User stories, acceptance criteria, backlog |
| Solution Architect | `.github/agents/architect.md` | Schema, security rules, ADRs, technical design |
| Flutter Developer | `.github/agents/flutter-dev.md` | UI, state management, client-side code |
| Cloud Functions Developer | `.github/agents/functions-dev.md` | Cloud Functions, simplified-debts algorithm |
| QA Engineer | `.github/agents/qa.md` | Test plans, test cases, release sign-off |
| DevOps Engineer | `.github/agents/devops.md` | CI/CD, deployment, secrets, emulator setup |
| UX/UI Designer | `.github/agents/designer.md` | Visual system, wireframes, accessibility |

Full role matrix: `.github/agents/README.md`

---

## Skills

Skills are reusable procedures that agents invoke for well-defined tasks.
Catalogue: `.github/skills/README.md`

---

## Shared Context

All agents should read these files for cross-cutting context:

| File | Purpose |
|---|---|
| `.github/shared/invariants.md` | The four non-negotiable invariants |
| `.github/shared/srs-pointer.md` | Canonical path to the SRS |
| `.github/shared/glossary.md` | Term definitions |
| `.github/shared/handoffs.md` | Handoff contracts between agents |
| `.github/shared/decision-log.md` | Architecture Decision Records |
| `.github/shared/coding-standards.md` | Dart, TypeScript, and commit message rules |
| `.github/shared/test-strategy.md` | Test pyramid, coverage thresholds, canonical test matrix |

---

## Refusal Protocol

When a request would violate the SRS or any invariant:

1. **Refuse** the request. Do not implement it.
2. **Quote** the specific SRS section or invariant being violated.
3. **Propose** a compliant alternative that achieves the user's intent within the
   SRS boundaries.

Examples of requests that must be refused:

- Using `double` or `float` for monetary values (violates invariant 1).
- Writing to `simplifiedBalances` from client code (violates invariant 2).
- Importing a WhatsApp-specific share package (violates invariant 3).
- Adding a second Firebase project configuration (violates invariant 4).
- Implementing features listed in SRS section 12.3 (out of scope for v1.0).

---

## Hooks

Pre-tool-use hooks automatically enforce invariants during development.
Registry: `.github/hooks/hooks.json`
Details: `.github/hooks/README.md`

---

## Workflows

- PR pipeline: `.github/workflows/pr.yml`
- Release pipeline: `.github/workflows/release.yml`

---

## Conventions

- British English throughout.
- No emojis in code, comments, or documentation.
- Follow `.github/shared/coding-standards.md` for all code.
- Follow Conventional Commits for all commit messages.
