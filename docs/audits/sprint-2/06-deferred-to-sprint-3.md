# Bucket B — Deferred to Milestone-Assigned Issues

**Date:** 2026-06-24
**Owner:** PM (maintains this list)
**Source:** `docs/audits/sprint-2/00-triage-summary.md` (Phase 6 triage)

Per `.github/shared/milestone-tracking.md`, every Bucket-B finding is filed as a GitHub
issue assigned to its owning milestone at creation. Closely-related nits are clustered
into themed issues (44 findings → 13 issues). The deprecated `sprint-2-chore` label is
not used.

| Issue | Milestone | Findings | Theme |
|---|---|---|---|
| #78 | Sprint 3 | R2, SR5 | Group rules completion + zero-balance-guard enforcement decision + negative tests |
| #79 | Sprint 3 | SR3 | Group component-catalogue entries (member row, invite-link card) |
| #80 | Sprint 3 | SR7 | `go_router` scope decision for Sprint-3 navigation |
| #81 | Sprint 3 | R1 | Split `firestore.rules` before groups inflate it (548 lines) |
| #82 | Sprint 3 | SC2, SC3 | Trigger negative-path branch coverage (settlement/expense) |
| #83 | Sprint 3 | T6, T7, T8, T10, T11, T12, SR8 | Reconcile `telemetry-plan.md` with shipped events |
| #84 | Sprint 3 | S5, S7, S9, S17, S19 | Screen-spec reconciliations + product decisions |
| #85 | Sprint 5 | S8, S11, S13, S14, S18, S20, S21, S22 | Screen-spec polish backlog |
| #86 | Sprint 3 | A3, A4, A5 | ADR hygiene + candidates |
| #87 | Sprint 4 | H2, H3 | PreToolUse hook hardening (with float-hook #27) |
| #88 | Sprint 3 | P2, P3, CN2, F1, M6, SK3 | Conventions + doc hygiene |
| #89 | Sprint 4 | D3, D6, D7 | Functions dependency upgrades + discontinued transitives |
| #90 | Sprint 6 | RT3, SEC4 | CI emulator-suite monitoring + `secrets/` dev-setup note |

## Findings folded into existing issues

| Finding | Existing issue | Note |
|---|---|---|
| D1 | #22 (Sprint 4) | Held-back Flutter majors (Riverpod 3.x, share_plus 13, etc.) — annotated on the existing dependency-upgrade epic; no new issue. |

## Coverage check

All 44 Bucket-B findings from the triage are represented above (13 new issues + D1 on
#22). No Bucket-B finding is left unfiled or unmilestoned.

Bucket-A findings are fixed in the cleanup PR; Bucket-C findings are accepted and
documented (ADR-0021/0022/0023 and retro/spec notes) — see `00-triage-summary.md`.
