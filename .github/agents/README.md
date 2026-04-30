# Agents

This directory contains the AI agent definitions for the OneByTwo project. Each
`.md` file is a Claude Code subagent with YAML front-matter and a system prompt
body.

## How the Team Works

The **Orchestrator** is the entry point for all non-trivial tasks. It reads the
task description, determines which specialist agent(s) should handle it, and
sequences the work according to the handoff contracts defined in
`.github/shared/handoffs.md`.

No agent works in isolation. The standard flow is:

1. PM defines user stories from the SRS.
2. Architect designs the technical solution.
3. Developers implement (Flutter Dev for client, Functions Dev for backend).
4. QA validates and signs off.
5. DevOps releases.

The Designer contributes visual specs at any point where UI work is involved.

## Role Matrix

| Agent | File | Can edit | Can run | Primary skills |
|---|---|---|---|---|
| Orchestrator | `orchestrator.md` | Nothing | Nothing | Delegates via Task |
| Product Manager | `pm.md` | Nothing | Nothing | `new-user-story`, `refine-acceptance-criteria`, `update-srs`, `write-release-notes` |
| Solution Architect | `architect.md` | `shared/`, `docs/`, `firestore.rules`, `firestore.indexes.json` | Nothing | `design-firestore-schema`, `write-security-rule` |
| Flutter Developer | `flutter-dev.md` | `lib/**`, `test/**`, `ios/**`, `android/**` | `flutter`, `fvm` | `scaffold-flutter-feature`, `write-widget-test` |
| Cloud Functions Developer | `functions-dev.md` | `functions/**` | `npm`, `firebase emulators` | `scaffold-cloud-function`, `simplified-debts-test-case` |
| QA Engineer | `qa.md` | Nothing | Nothing | `write-integration-test`, `write-widget-test`, `triage-bug`, `simplified-debts-test-case`, `review-pull-request` |
| DevOps Engineer | `devops.md` | `.github/workflows/**`, `fastlane/**`, `lefthook.yml` | `gh`, `firebase`, `fastlane` | `setup-emulator-suite`, `add-github-actions-job` |
| UX/UI Designer | `designer.md` | Nothing | Nothing | (contributes specs consumed by Flutter Dev) |

## When to Invoke Whom

| You need to... | Invoke |
|---|---|
| Route a complex or multi-step task | Orchestrator |
| Write or refine a user story | PM |
| Design schema, security rules, or make an architectural decision | Architect |
| Build a Flutter feature or fix a client-side bug | Flutter Dev |
| Build or modify a Cloud Function | Functions Dev |
| Write tests, triage a bug, or review a PR | QA |
| Create or modify CI/CD pipelines, deploy, or set up emulators | DevOps |
| Get design specs, tokens, or accessibility guidance | Designer |

## Shared Context

Every agent reads these files before starting work:

- `.github/shared/invariants.md` — the four non-negotiable constraints.
- `.github/shared/srs-pointer.md` — path to the SRS.
- `.github/shared/handoffs.md` — handoff contracts between agents.
- `.github/shared/coding-standards.md` — code style and commit message rules.
- `.github/shared/glossary.md` — term definitions.

## Refusal Protocol

Every agent follows the same refusal protocol:

1. If a task falls outside the agent's scope, refuse and route to the correct agent.
2. If a task would violate an invariant, cite it and propose a compliant alternative.
3. If a task requests an out-of-scope feature (SRS section 12.3), cite the section
   and refuse.
