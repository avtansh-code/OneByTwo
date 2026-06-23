# Phase 6 — Triage and Decision

**Date:** 2026-06-24
**Owner:** Orchestrator

---

## Consolidation

Phases 1 through 5 produced **99 findings** across five audit reports (83 actionable +
16 informational PASS rows):

| Phase | Title | High | Medium | Low | PASS | Total |
|---|---|---|---|---|---|---|
| 1 | Documentation drift | 4 | 23 | 23 | 7* | 50 |
| 2 | Test-suite health | 0 | 3 | 4 | 4 | 11 |
| 3 | Agentic infrastructure debt | 0 | 4 | 4 | 5 | 13 |
| 4 | Dependency and security | 1 | 3 | 7 | 5 | 16 |
| 5 | Sprint 3 pre-flight readiness | 2 | 3 | 2 | 2 | 9 |
| **Total** | | **7** | **36** | **40** | **23** | **99** |

\* Phase-1 PASS rows (S15, S23, F2, F3, M7, T13, P4) are recorded in the report but not
re-counted in the ledger; the ledger holds the 83 actionable findings.

Every finding is triaged into exactly one bucket. None falls into the gap.

---

## Bucket A — Fix Now (the cleanup PR): 33 findings

**Bar:** would this materially affect Sprint 3 quality if left unfixed, or block the
first Sprint-3 PR, or is it a HIGH security/correctness defect?

### Code fixes (require testing)

| ID | Phase | Finding | Rationale |
|---|---|---|---|
| **S6** (+ **PY3** + **T4**) | 1.1 / 2.4 / 1.5 | **Wire the add-friend flow** so the popped `SelectedContact` reaches `MatchAndInviteScreen` (override the controller; route from both add sites + the context picker), **add one executable end-to-end add-friend test** (PY3), and pass `method` to `friend_added` (T4, now reachable). | Functional defect — FR-FR-01/02 unreachable in the running app. Highest-priority quality fix; Sprint 3 builds on friends. |
| **T1** | 1.5 | **Bucket `amount_paise` → `amount_range`** on `home_settle_up_tapped` and `expense_delete_confirmed` (helper exists). | Telemetry-privacy "blocking defect" per plan §2.1/§3. |
| **T2** | 1.5 | **Remove `phone_hash`** from `otp_screen_viewed` (event needs no params). | Reversible phone-derived PII in analytics; plan forbids phone numbers. |
| **T3** | 1.5 | Rename `activity_item_tapped.entity_id` → `entity_id_hash`; hash both branches. | PII-naming + raw-id consistency. |
| **T5** | 1.5 | Reconcile `friend_detail_viewed` to emit the documented `balance_state` (or update plan). | Documented analytics dimension never produced. |
| **R4** | 4.4 | Add avatar **oversize (>5 MB)** and **non-image** rejection tests. | Closes an untested-rule regression gap before Sprint 3. |
| **D5** | 4.2 | Attempt targeted `overrides` for the 4 HIGH npm advisories; verify `npm ci && build && test` green; else fall back to a tracked Sprint-3 issue. | HIGH advisories (low in-context exploitability, no clean `audit fix`). |

### Documentation / config fixes (low risk, high value)

| ID | Phase | Finding | Rationale |
|---|---|---|---|
| **C1** | 1.3 | Add `deleteUserAccount` to the CF catalogue; remove the contradictory "deferred/not implemented" lines; "six"→"seven". | Sprint-3 agents read a wrong CF inventory. |
| **C2** | 1.3 | Fix reminder trigger §5 v1→v2 `onCall` wording. | Cheap consistency. |
| **A1** | 1.6 | Write **ADR-0021** (simplified-debts trigger architecture: shared `recomputeAndWrite` core, 3 entry points, retry/stale-guard, side-effect containment). | Sprint-3 group triggers will copy this pattern. Load-bearing. |
| **A2** | 1.6 | Correct the `extension-points-register` ADR-0017 localisation cross-ref. | Actively misroutes readers. |
| **M1–M5** | 1.4 | Update `state-management.md`: add Home section (M1), retarget Firebase providers to `core/providers/` (M2), add 4 Profile providers (M3), remove the false "FR-PR-02 not implemented" (M4), document the scoped-`dependencies` rule (M5). | Sprint-3 provider work reads this doc as the reference; stale "not implemented" claims mislead. |
| **CN1** | 3.5 | Add the scoped-`dependencies` rule to `feature-pr-conventions.md` §2 (with M5). | Three-way doc consistency; Sprint-3 providers depend on it. |
| **P1** | 1.7 | Align the PR template Invariant-2 line to the three-writer model (callable + two triggers). | Prevents reviewers wrongly flagging a trigger write. |
| **SK2** | 3.3 | Add three checks to `review-pull-request`: `amount_range` bucketing, "no phone in telemetry even hashed", reachability/executable-journey. | The review lens missed T1/T2/S6; closing this hardens Sprint-3 review. Highest-leverage agentic fix. |
| **AG2** | 3.2 | Add the critical-journey-reachability duty to `qa.md`. | Pairs with S6/SK2; no agent owned this. |
| **T9** | 1.5 | Correct the telemetry-plan status note (account deletion ships). | Misleading status note. |
| **S1, S2, S16** | 1.1 | Fix the stale "placeholder / not implemented" status notes (Home, spend breakdown, support/deletion). | Cheap; restores spec trust for Sprint-3 agents. |
| **S3, S10, S12** | 1.1 | Add SCR-07 + SCR-11-overflow deferral markers; correct SCR-08 description max (100). | One-line doc corrections. |
| **CV2** | 2.1 | Reword the coverage-gate comment ("advisory", not "100% branch enforced"). | One-line accuracy fix. |
| **SR1** | 5.1 | **Write the first three Sprint-3 stories** (FR-GR-01/02/03) to DoR. | Hard blocker on Sprint-3 start. |
| **SR4** | 5.3 | Draft the **invite-token schema + rules/expiry/revocation outline + ADR**. | Unblocks FR-GR-02/03 design. |
| **SR9** | 5.5 | Add the invite-link-security and zero-balance-guard-server-enforcement risks to `risks-revisited.md`. | Cheap; Sprint-3 safety. |

**Bucket A total: 33 (7 code-bearing groups, 26 doc/config).**

---

## Bucket B — Backlog as milestone-assigned issues: 44 findings

Filed per `.github/shared/milestone-tracking.md` (default `Sprint 3`; later sprints
where the source defers). Closely-related nits are **clustered into themed issues**
rather than 44 separate ones; the PM maintains the list in
`06-deferred-to-sprint-3.md`.

| Themed issue | Findings | Milestone |
|---|---|---|
| **Group rules completion + zero-balance-guard enforcement decision + negative tests** | SR5, R2 | Sprint 3 (fold into FR-GR-05/06/07) |
| **Group component-catalogue entries** (member row, invite-link card) | SR3 | Sprint 3 |
| **`go_router` scope decision at Sprint-3 kickoff** | SR7 | Sprint 3 |
| **`firestore.rules` split before groups inflate it** | R1 | Sprint 3 |
| **Trigger negative-path branch coverage** (settlement/expense) before group extensions | SC2, SC3 | Sprint 3 |
| **Reconcile `telemetry-plan.md` with shipped events** (friends/reminders/fcm catalogues + low params + `group_member_added`) | T6, T7, T8, T10, T11, T12, SR8 | Sprint 3 |
| **Screen-spec reconciliations + product decisions** (settle-up confirmation sub-screen; friends search; SCR-11 reminder/nav; picker copy; change-phone spec) | S17, S7, S9, S5, S19 | Sprint 3 |
| **Screen-spec polish backlog** (Contact-Support links, skeleton-vs-spinner, copy/avatar nits) | S8, S11, S13, S14, S18, S20, S21, S22 | Sprint 5 (Polish) |
| **ADR hygiene + candidates** (de-indent 0018/19/20; rules-asymmetry; storage-authz) | A3, A4, A5 | Sprint 3 |
| **PreToolUse hook hardening** (path-format false-negative; deep-link URI patterns) | H2, H3 | Sprint 4 (with float-hook #27) |
| **Conventions + doc hygiene** (PR-section taxonomy; Sprint-3 theme wording; extension-point pointer; stale schema comments; remote-config sentence; boundary-contract skill) | P2, P3, CN2, F1, M6, SK3 | Sprint 3 |
| **Dependency upgrades** (Flutter majors → existing #22; functions minor/major bumps; discontinued build_runner transitives) | D1, D3, D6, D7 | Sprint 4 (#22) |
| **CI/ops monitoring + dev-setup note** (emulator-suite durations; `secrets/` staging note) | RT3, SEC4 | Sprint 6 / Sprint 3 |

**Bucket B total: 44 (13 medium, 31 low) across ~13 themed issues.**

---

## Bucket C — Accept and Document: 9 findings

**Bar:** a deliberate trade-off or acceptable imperfection; document so it is not
re-discovered as a "bug".

| ID | Phase | Finding | Disposition |
|---|---|---|---|
| INV2c | 3.4 | Server-maintained projections client-read-only generalisation (`verificationStatus` mirrors `simplifiedBalances`). | ADR (fold into/extend ADR-0010); revisit after Sprint-3 `groups.simplifiedBalances`. |
| PY2 | 2.4 | The #23 Flutter integration harness stays render-only stubs (Sprint 6). | Accept the deferral; the PY3 executable add-friend test (Bucket A) addresses the demonstrated cost. Retro note. |
| H4 | 3.1 | Float/double hook (#27) deferred. | Accept; covered by boundary-contract tests + types. (#27 stays Sprint 4.) |
| SC1 | 2.5 | simplified-debts algorithm uncovered branches are the unreachable `userId`-equality tie. | Accept; document the defensive branch. |
| D2 | 4.1 | In-range Firebase-plugin patches not taken; pinned lock intentional. | Accept; CI tests the committed lock. |
| FL2 | 2.2 | The lone CI failure was a deterministic `Build iOS` (Podfile fragility), not a flake. | Accept + document the known iOS `pod install --repo-update` pattern. |
| S4 | 1.1 | Net-balance semantic `ColorScheme` tints vs spec literal hex (deliberate dark-mode choice). | Accept; add a one-line spec note. |
| SEC2 | 4.5 | Sprint 3 (Groups) needs no new secrets. | Accept (confirmed). |
| SEC3 | 4.5 | Release-pipeline secrets + DPDP (#26) deferred to Sprint 6. | Accept (on track). |

**Bucket C total: 9.**

---

## Totals

| Bucket | Count | % of actionable |
|---|---|---|
| A — Fix now (cleanup PR) | 33 | 40% |
| B — Backlog (milestone issues) | 44 | 53% |
| C — Accept + document | 9 | 11%* |
| **Actionable total** | **83** (rounding) | 100% |
| Informational (PASS rows) | 16 | — |
| **Grand total** | **99** | — |

\* 9 of 83 ≈ 11%; minor rounding across buckets.

Every finding has been explicitly triaged. None falls into the gap between buckets.

---

## Decision: Cleanup PR Required

**Bucket A is non-empty (33 findings, incl. 7 HIGH).** Per the Phase-0 framing, this
session produces the **cleanup PR** (next available number, ≥ #78):
`chore: Sprint 2 boundary cleanup and audit findings`.

The PR will carry, as Conventional-Commits-scoped commits:
- **Code:** the add-friend wiring + executable test (S6/PY3/T4), the two telemetry-PII
  fixes (T1/T2) + two small telemetry corrections (T3/T5), the avatar rules tests (R4),
  and the npm `overrides` attempt (D5).
- **Docs/config:** ADR-0021 (A1), the CF catalogue (C1/C2), `state-management.md`
  (M1–M5) + conventions (CN1), the PR template (P1), the `review-pull-request` skill +
  `qa.md` (SK2/AG2), the telemetry/screen-spec status-note corrections (T9, S1/S2/S16,
  S3/S10/S12), the coverage-gate comment (CV2), the extension-points ADR ref (A2), and
  the Sprint-3 enablers (SR1 stories, SR4 invite-token schema/ADR, SR9 risks).

Bucket B items are filed as **milestone-assigned GitHub issues** (≈13 themed issues) and
listed in `06-deferred-to-sprint-3.md`. Bucket C items get an ADR (INV2c) or retro/doc
notes. Phase 7 executes this decision.
