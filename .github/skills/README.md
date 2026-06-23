# Skills

This directory contains reusable skill definitions for the One By Two agent team.
Each skill is a Claude Code skill with YAML front-matter and a structured markdown
body in a `SKILL.md` file inside its own folder.

## Catalogue

| Skill | Folder | Owning agent(s) | When to invoke |
|---|---|---|---|
| `new-user-story` | `new-user-story/` | PM | A new user story needs to be created from an SRS functional requirement. |
| `refine-acceptance-criteria` | `refine-acceptance-criteria/` | PM | An existing story's acceptance criteria need improvement or expansion. |
| `design-firestore-schema` | `design-firestore-schema/` | Architect | A new Firestore collection or document structure needs design. |
| `write-security-rule` | `write-security-rule/` | Architect | Firestore Security Rules need creation or update. |
| `scaffold-flutter-feature` | `scaffold-flutter-feature/` | Flutter Dev | A new Flutter feature needs its folder structure and stubs created. |
| `scaffold-cloud-function` | `scaffold-cloud-function/` | Functions Dev | A new Cloud Function needs its boilerplate created. |
| `write-widget-test` | `write-widget-test/` | Flutter Dev, QA | A widget or screen needs widget tests. |
| `write-integration-test` | `write-integration-test/` | QA | A critical user journey needs an integration test. |
| `review-pull-request` | `review-pull-request/` | QA | A pull request needs review for correctness and invariant compliance. |
| `triage-bug` | `triage-bug/` | QA | A bug report needs severity classification and assignment. |
| `write-release-notes` | `write-release-notes/` | PM | Release notes need to be drafted for a tagged version. |
| `setup-emulator-suite` | `setup-emulator-suite/` | DevOps | Firebase Emulator Suite needs configuration. |
| `add-github-actions-job` | `add-github-actions-job/` | DevOps | A GitHub Actions workflow job needs to be added or modified. |
| `update-srs` | `update-srs/` | PM | The SRS needs a proposed update. |
| `simplified-debts-test-case` | `simplified-debts-test-case/` | Functions Dev, QA | The simplified-debts canonical test matrix needs to be generated, verified, or extended. |

## Skill Format

Every `SKILL.md` follows this structure:

```yaml
---
name: <skill-name>
description: <one-liner: when to use this skill>
---
```

Followed by markdown sections:

1. **When to use** — conditions under which this skill should be invoked.
2. **When NOT to use** — common misuse cases and the correct alternative.
3. **Inputs** — what the skill expects to receive.
4. **Procedure** — step-by-step instructions for executing the skill.
5. **Output format** — what the skill produces.
6. **Validation checks** — checklist to verify the output is correct.
7. **Examples** — one positive example and one negative (refusal) example.

## Invariant Enforcement

All skills that produce code or configuration enforce the four project invariants
(`.github/shared/invariants.md`):

1. Money is integer paise.
2. `simplifiedBalances` is server-maintained and client-read-only.
3. System share sheet only.
4. Single Firebase project.

Skills that scaffold code hard-code these constraints directly in their procedure
steps.

## Milestone Tracking

Skills that create or review issues and pull requests keep GitHub Milestones in
step with the sprint roadmap, per `.github/shared/milestone-tracking.md`:

- `new-user-story` and `triage-bug` assign every new issue to exactly one sprint
  milestone at creation/triage.
- `review-pull-request` reconciles milestones with each passing PR (closed issues
  milestoned, re-scoped remainders re-homed, a completed sprint milestone closed).
- `write-release-notes` sources the closed stories from the release's sprint
  milestone and confirms its closure.

