# Phase 0 — Scope and Output Framing

**Date:** 2026-05-02
**Session type:** Sprint 1 boundary cleanup and audit sweep
**Orchestrator commitment:** This framing is binding for the duration of this session.

---

## What This Session Is

This is an **audit**, not feature work. No new features ship in this session. The
purpose is to inspect the boundary between Sprint 1 (completed: PRs #1 through #13,
43 SP across 11 stories) and Sprint 2 (Friends and Core Expenses, 50 SP planned).

The audit examines documentation accuracy, test-suite health, agentic infrastructure
debt, dependency and security posture, and Sprint 2 pre-flight readiness.

---

## What This Session Is Not

- Not a refactoring session. Code changes are limited to fixes that would materially
  affect Sprint 2 quality.
- Not a feature session. Nothing from Sprint 2's scope is implemented here.
- Not a style cleanup. Cosmetic changes are deferred or accepted.

---

## Possible Outcomes

This session has exactly two possible outcomes, determined by the audit findings:

1. **PR #14: Sprint 1 boundary cleanup.** Title:
   `chore: Sprint 1 boundary cleanup and audit findings`. Opens if and only if
   Bucket A (fix now) findings are non-empty.

2. **Standalone audit report.** The audit reports under `docs/audits/sprint-1/` are
   committed as a docs-only PR if Bucket A is empty. No application code changes.

The orchestrator does not pre-commit to either outcome. The audit runs first; the
findings dictate the response.

---

## Triage Buckets

Every finding from Phases 1 through 5 is explicitly triaged into one of three
buckets. No finding may fall into the gap between buckets.

### Bucket A — Fix Now (PR #14)

**Bar:** Would this materially affect Sprint 2 quality if left unfixed?

Examples of Bucket A findings:
- Hook false positives (slow real work) or false negatives (let bugs through).
- HIGH or CRITICAL npm audit advisories.
- Sprint 2 first-PR blockers.
- Documentation drift that would cause Sprint 2 agents to build against stale specs.
- Flaky tests (must be fixed, annotated, or deleted — silent flakiness is
  unacceptable).
- Coverage below SRS section 5.7 thresholds.

### Bucket B — Backlog for Sprint 2 Chore

**Bar:** Would Sprint 2 work create friction with this issue, or is it a follow-up
that can wait until a natural moment in Sprint 2 or beyond?

Examples of Bucket B findings:
- Stylistic inconsistencies in documentation.
- Test runtime optimisations.
- Non-blocking convention-doc additions.
- Dependency upgrades that are not security-critical.

### Bucket C — Accept and Document

**Bar:** Is this a deliberate trade-off, or an acceptable level of imperfection that
costs less to live with than to fix?

Examples of Bucket C findings:
- Architectural decisions that were made implicitly and are acceptable as-is, but
  should be documented so they are not re-discovered as "bugs".
- Known limitations that are tolerable for v1.0.

Each accepted finding gets either an ADR entry in `.github/shared/decision-log.md`
or a note in the relevant retrospective document.

---

## PR Numbering Note

The audit prompt referenced "PR #13" for the cleanup PR. In practice, FR-PR-01
shipped as PR #13 (the last Sprint 1 feature PR). The audit cleanup PR, if needed,
will be **PR #14**. All references in audit documents use the corrected numbering.

---

## Phases

| Phase | Title | Owner (Lead) | Consulting |
|---|---|---|---|
| 0 | Scope and output framing | Orchestrator | — |
| 1 | Documentation drift audit | Architect | PM |
| 2 | Test-suite health check | QA | Flutter Dev, Functions Dev |
| 3 | Agentic infrastructure debt review | Architect | DevOps |
| 4 | Dependency and security audit | DevOps | — |
| 5 | Sprint 2 pre-flight readiness | PM | Architect, Designer |
| 6 | Triage and decision | Orchestrator | — |
| 7 | Decide: PR #14 or standalone report | Orchestrator | — |
| 8 | Sprint 2 kickoff readiness confirmation | PM | QA |

---

## Execution Protocol

- Phase by phase, stop after each, wait for explicit "proceed" before the next.
- Phases 1 through 5 produce audit reports under `docs/audits/sprint-1/`.
- Phase 6 triages all findings.
- Phase 7 acts on the triage (open PR #14 or commit audit reports as docs-only PR).
- Phase 8 confirms Sprint 2 readiness.

---

## References Read Before Framing

- `.github/copilot-instructions.md`
- `.github/shared/invariants.md` (four invariants confirmed)
- `.github/shared/decision-log.md` (ADRs 0001 through 0008)
- `docs/patterns/feature-pr-conventions.md` (ratified after PR #4)
- `docs/retros/2026-05-02-sprint-1-retro.md` (velocity: 43 SP, 4 action items)
- `docs/sprint-zero/sprint-1-plan.md` (final state, 11 stories, all shipped)
- `docs/sprint-zero/next-three-prs.md` (PR #14 conditional, then FR-FR-01)
- `docs/design/08-plan/sprint-sequence.md` (Sprint 2: Friends and Core Expenses)
- `docs/design/08-plan/dependencies-and-critical-path.md` (DAG confirmed)
