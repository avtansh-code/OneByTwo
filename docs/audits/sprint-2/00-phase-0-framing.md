# Phase 0 — Scope and Output Framing

**Date:** 2026-06-24
**Session type:** Sprint 2 boundary cleanup and audit sweep
**Orchestrator commitment:** This framing is binding for the duration of this session.

---

## What This Session Is

This is an **audit**, not feature work. No new features ship in this session. The
purpose is to inspect the boundary between Sprint 2 (Friends and Core Expenses —
completed: PRs #15 through #77, **142 SP across 34 counted PRs**) and Sprint 3
(Groups and Settlements).

The audit examines documentation accuracy, test-suite health, agentic infrastructure
debt, dependency and security posture, and Sprint 3 pre-flight readiness. It mirrors
the Sprint-1 precedent (`docs/audits/sprint-1/`) and is run **before** the Sprint 3
Groups epic (FR-GR-01..07, FR-SE-05..08, FR-EX-06/07 in group context) opens.

---

## What This Session Is Not

- Not a feature session. Nothing from Sprint 3's scope (Groups, settle-up,
  group-context expenses) is implemented here. The Sprint 3 Groups epic is **not**
  started.
- Not the `go_router` migration. That candidate enabler is evaluated in Phase 5 for
  readiness only; it is not executed here.
- Not a refactoring session. Code changes are limited to fixes that would materially
  affect Sprint 3 quality.
- Not a style cleanup. Cosmetic changes are deferred or accepted.

**Refusal protocol applies:** any attempt to begin the Groups epic, the `go_router`
migration, or any feature work inside this session is refused, with the SRS/invariant
boundary quoted and a compliant alternative (file as a Sprint-3 issue) proposed.

---

## Sprint 2 Close-out Baseline (verified)

| Fact | Value |
|---|---|
| Sprint 2 status | Closed at 100% (milestone `Sprint 2`, 13 issues, all closed) |
| Velocity | **142 SP / 34 counted PRs** |
| Velocity-excluded PRs | #59, #61, #73, #75, **#77** (CI + governance) — Total unchanged |
| Highest PR | #77 (`b9b1e63`, squash) |
| Highest issue | #68 |
| **Next available slot** | **#78** (issues and PRs share one sequential namespace) |
| Committed remainder | #23 Flutter emulator integration-harness (PY3 Flutter-harness deferred to `Sprint 6`) |

PR #77 landed three governance changes that reshape **how this audit operates**:
1. **Path-based change detection** in `.github/workflows/pr.yml` (docs-only PRs run
   only the PR Title Lint).
2. The **milestone-tracking convention** (`.github/shared/milestone-tracking.md`) —
   Bucket B findings are filed as **GitHub issues on a milestone**, not the
   deprecated `sprint-2-chore` label.
3. A **deepened `review-pull-request` skill** (14 design-grounded review dimensions)
   — used as the audit lens in Phases 1–5.

---

## Possible Outcomes

This session has exactly two possible outcomes, determined by the audit findings:

1. **Cleanup PR (next available number, ≥ #78).** Title:
   `chore: Sprint 2 boundary cleanup and audit findings`. Opens if and only if
   Bucket A (fix now) findings are non-empty.

2. **Standalone audit report (docs-only PR).** The audit reports under
   `docs/audits/sprint-2/` are committed as a docs-only PR if Bucket A is empty.
   Under #77 change detection, a `docs/**`-only PR runs **only** the PR Title Lint;
   the Flutter/Functions/build/integration/coverage jobs skip (and pass the ruleset
   as "skipped").

The orchestrator does **not** pre-commit to either outcome. The audit runs first; the
findings dictate the response.

---

## Triage Buckets

Every finding from Phases 1 through 5 is explicitly triaged into one of three
buckets. No finding may fall into the gap between buckets.

### Bucket A — Fix Now (the cleanup PR)

**Bar:** Would this materially affect Sprint 3 quality if left unfixed?

Examples of Bucket A findings:
- Hook false positives (block legitimate work) or false negatives (let a violation
  through).
- HIGH or CRITICAL `npm audit` advisories.
- Sprint 3 first-PR (FR-GR-01 Create group) blockers.
- Documentation drift that would cause Sprint 3 agents to build against stale specs.
- Flaky tests (must be fixed, annotated, or deleted — silent flakiness is
  unacceptable).
- Coverage below SRS section 5.7 thresholds (≥70% non-UI per feature/module, ≥50%
  overall).
- Load-bearing architectural-decision back-ports (ADRs).

### Bucket B — Backlog as a milestone-assigned issue

**Bar:** Would Sprint 3 work create friction with this issue, or is it a follow-up
that can wait?

**Filing mechanism (changed since Sprint 1):** Each Bucket B finding is filed as a
**GitHub issue assigned to the milestone that owns the work** at creation time, per
`.github/shared/milestone-tracking.md` — default `Sprint 3`; a later sprint
(`Sprint 4`/`Sprint 5`/`Sprint 6`) or `Post-v1.0` where the source explicitly defers
it. The deprecated `sprint-2-chore` label is **not** used (it is historical, closed
issues only). The milestone choice and its one-line rationale are recorded as an
issue comment so the decision is auditable.

Examples of Bucket B findings:
- Stylistic inconsistencies in documentation.
- Test-runtime optimisations.
- Non-blocking convention-doc additions.
- Dependency upgrades that are not security-critical.

### Bucket C — Accept and Document

**Bar:** Is this a deliberate trade-off, or an acceptable level of imperfection that
costs less to live with than to fix?

Each accepted finding gets either an ADR entry in `.github/shared/decision-log.md`
(Sprint 2 added through ADR-0020) or a note in the relevant retrospective document so
it is not re-discovered later as a "bug".

---

## PR Numbering Note

Issues and PRs share one sequential namespace. The highest PR is #77 and the highest
issue is #68, so any cleanup PR lands as **#78** (or the next free number if an issue
is filed first). The slot label is reconciled at PR open per the rolling-roadmap
convention.

---

## Phases

| Phase | Title | Owner (Lead) | Consulting | Output |
|---|---|---|---|---|
| 0 | Scope and output framing | Orchestrator | — | `00-phase-0-framing.md` |
| 1 | Documentation drift audit | Architect | PM | `01-documentation-drift.md` |
| 2 | Test-suite health check | QA | Flutter Dev, Functions Dev | `02-test-suite-health.md` |
| 3 | Agentic infrastructure debt review | Architect | DevOps | `03-agentic-infrastructure-debt.md` |
| 4 | Dependency and security audit | DevOps | — | `04-dependency-and-security.md` |
| 5 | Sprint 3 pre-flight readiness | PM | Architect, Designer | `05-sprint-3-readiness.md` |
| 6 | Triage and decision | Orchestrator | — | `00-triage-summary.md` |
| 7 | Decide: cleanup PR (≥#78) or standalone report | Orchestrator | — | PR + `06-deferred-to-sprint-3.md` |
| 8 | Sprint 3 kickoff readiness confirmation | PM | QA | `docs/sprint-zero/sprint-3-kickoff-readiness.md` |

---

## Execution Protocol

- Phase by phase, stop after each, wait for explicit "proceed" before the next.
- Phases 1 through 5 produce audit reports under `docs/audits/sprint-2/`, each finding
  a row: location, drift/finding description, severity (high/medium/low), recommended
  action (fix now / backlog / accept), owner.
- Phase 6 triages all findings into Buckets A/B/C.
- Phase 7 acts on the triage (open the cleanup PR ≥#78, or commit audit reports as a
  docs-only PR). Bucket B items are filed as milestone-assigned GitHub issues and
  listed in `06-deferred-to-sprint-3.md`. Bucket C items get an ADR or retro note.
- Phase 8 confirms Sprint 3 readiness (`sprint-3-kickoff-readiness.md`), reconciles
  `sprint-2-plan.md` (mark fully closed) and `next-three-prs.md` (cleanup/audit-PR row
  + Sprint-3 Groups epic flipped to next-up), and QA posts a sign-off.

---

## References Read Before Framing

- `.github/copilot-instructions.md`
- `.github/shared/invariants.md` (four invariants confirmed)
- `.github/shared/milestone-tracking.md` (NEW in #77 — Bucket B files milestones, not labels)
- `.github/shared/decision-log.md` (ADRs through ADR-0020)
- `.github/shared/coding-standards.md`, `.github/shared/handoffs.md`
- `.github/skills/review-pull-request/SKILL.md` (NEW depth in #77 — 14 review dimensions)
- `docs/patterns/feature-pr-conventions.md`
- `docs/copilot_prompts/sprint_1/retro.md` and `docs/audits/sprint-1/` (the precedent this session mirrors)
- `docs/sprint-zero/sprint-2-plan.md`, `docs/sprint-zero/next-three-prs.md`
- `docs/design/08-plan/sprint-sequence.md`, `docs/design/08-plan/dependencies-and-critical-path.md`
- Live GitHub state: milestones (Sprint 3–6, Post-v1.0), 9 open issues, highest PR #77 / issue #68
