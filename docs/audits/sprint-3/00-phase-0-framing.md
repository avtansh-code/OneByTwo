# Phase 0 — Scope and Output Framing

**Date:** 2026-06-28
**Session type:** Sprint 3 → Sprint 4 boundary sweep — design-conversion audit and remediation
**Orchestrator commitment:** This framing is binding for the duration of this session.

---

## What This Session Is

This is a **design-conversion AUDIT + REMEDIATION**, not feature work. It inspects the
boundary between **Sprint 3** (the Design Conversion — the "Direction A — Haldi" visual
system, `design_handoff_one_by_two/`; DC-01..DC-13 plus the trailing #128/#110 and the
design-fidelity follow-up #143) and **Sprint 4** (the Groups epic).

Sprint 3 was a **visual/UX conversion only** — it changed no data model, security rule,
Cloud Function, trigger, schema, or telemetry contract (ADR-0024 §3). The headline audit
dimension is therefore **design fidelity against the Haldi handoff**, not backend
correctness. The stakeholder directive is explicit: **find ALL the gaps and FIX the ones
that matter.** Triage biases toward **Bucket A (fix now)**; this is a remediation pass,
not a report-only audit.

It mirrors the Sprint-1 (`docs/audits/sprint-1/`) and Sprint-2 (`docs/audits/sprint-2/`)
retro precedent, and is run **before** the Sprint 4 Groups epic (FR-GR-01..07,
FR-SE-05..08, FR-EX-06/07 in group context — 13 open issues on the `Sprint 4` milestone)
opens.

---

## What This Session Is Not

- **Not feature work.** Nothing from Sprint 4's scope (Groups, group settle-up, group-context
  expenses) is implemented here. The Groups epic is **not** started. No Groups screen is converted.
- **Not a backend change.** No finding in this session may alter a Cloud Function, a Firestore
  or Storage rule, `firestore.indexes.json`, the schema, a trigger, the simplified-debts
  algorithm, or a telemetry-event contract. A finding that appears to require one is mis-scoped:
  it is re-routed to the owning backend area as a **Bucket-B** issue, never "fixed" inside this
  visual cleanup.
- **Not an SRS edit.** `docs/OneByTwo_Requirements_Spec.md` is not touched.

**Refusal protocol applies.** Any change that would weaken an invariant or the SRS, or that
would touch a backend contract, is refused with the SRS section / invariant quoted and a
compliant alternative proposed (re-route as a Bucket-B issue on the owning milestone).

---

## Invariants (re-affirmed, not touched)

The Haldi handoff re-states the four invariants verbatim (ADR-0024); this audit strengthens
rather than disturbs them. Every Bucket-A fix in this session is visual/test-only:

1. **Money is integer paise.** `formatInrFromPaise()` stays the sole paise→INR display
   boundary. Re-styling an amount (font family/size for the rupee-glyph and single-line-fit
   fixes) changes the *display*, never the value; no `paise / 100`, no `double` money math.
2. **`simplifiedBalances` is server-maintained, client-read-only.** Pills and tiles READ the
   projection only; no client write is added.
3. **System share sheet only.** Untouched.
4. **Single Firebase project.** Untouched (no backend change in this pass; the nightly deploy
   pipeline reviewed in Phase 4 is single-project-guarded).

---

## Sprint 3 Close-out Baseline (verified this session)

| Fact | Value |
|---|---|
| Sprint 3 status | Closed at 100% (milestone `Sprint 3`, **18 issues, 0 open**) |
| Delivered | DC-01..DC-13 (#113–#125), #128 (§4.1 reconciliation / ADR-0025), #110 (nightly deploy pipeline / #142), #143 (design-fidelity follow-up) |
| Governing decisions | ADR-0024 (adopt Haldi), ADR-0025 (§4.1 reconciliation) |
| Highest PR | #143 (`32168c8`) |
| Highest issue | #128 |
| **Next available slot** | **#144** (issues and PRs share one sequential namespace) |
| Live milestones | Sprint 4 (13 open), Sprint 5 (5), Sprint 6 (1), Sprint 7 (5), Post-v1.0 (2) |
| Toolchain | fvm-pinned Flutter 3.44.x / Dart 3.12.x; `OBTText.amount*` helpers present |

---

## Possible Outcomes

This session has exactly two possible outcomes, determined by the findings; the orchestrator
does **not** pre-commit to either:

1. **Cleanup PR (next available number, ≥ #144)** — the *expected* outcome. Title (single-token
   scope, ASCII ≤ 72 chars): `fix: Sprint 3 design-conversion cleanup and audit findings`
   (`chore:` if the changes are purely non-functional docs/tests). Opens if and only if
   Bucket A is non-empty.

2. **Standalone audit report (docs-only PR)** — only if Bucket A is genuinely empty. A
   `docs/**`-only PR runs **only** the PR Title Lint under the path-based change detection in
   `.github/workflows/pr.yml`; the Flutter/Functions/build/integration/coverage jobs skip.

A cleanup PR that touches `lib/**`, `test/**`, the rules, or a workflow re-engages the
corresponding CI jobs (so the golden, a11y, and Flutter jobs run).

---

## Triage Buckets

Every finding from Phases 1–5 is explicitly triaged into exactly one bucket with a rationale.
No finding falls into the gap between buckets. **Per the stakeholder directive, bias toward
Bucket A.**

### Bucket A — Fix now (the cleanup PR)
**Bar:** a visible divergence from the Haldi handoff, an accessibility regression, a
money-rendering defect (e.g. the rupee-glyph tofu), a one-line component that wraps/truncates,
a broken or self-deceiving golden, a doc/ADR back-port that Sprint 4 depends on, or any deploy
drift — anything that would make Sprint 4 inherit design debt.

### Bucket B — Backlog as a milestone-assigned issue
**Bar:** a non-blocking polish item, or a larger divergence whose fix is a project of its own.
Filed as a **GitHub issue on the owning milestone** (per `.github/shared/milestone-tracking.md`
— default `Sprint 4`; `Post-v1.0` for explicitly post-launch items). No deprecated labels. A
finding that turns out to need a backend-contract change is filed here, re-routed to the owning
backend area.

### Bucket C — Accept and document
**Bar:** a deliberate, defensible deviation from the handoff. Recorded against ADR-0024/0025 as
an ADR note, or as a retro line, so it is not re-discovered later as a "bug".

---

## Phases

| Phase | Title | Owner (Lead) | Consulting | Output |
|---|---|---|---|---|
| 0 | Scope and output framing | Orchestrator | — | `00-phase-0-framing.md` |
| 1 | Design-fidelity validation (headline) | Designer + Flutter Dev | Architect, QA | `01-design-fidelity-validation.md` (+ Bucket-A fixes) |
| 2 | Golden and accessibility harness health | QA | Flutter Dev | `02-golden-and-a11y-health.md` (+ fixture/guard fixes) |
| 3 | Documentation and decision drift | Architect | PM, Designer | `03-documentation-and-decision-drift.md` |
| 4 | Infra, dependency, and deploy audit | DevOps | Architect | `04-infra-dependency-and-deploy.md` |
| 5 | Sprint 4 (Groups) pre-flight readiness | PM | Architect, Designer | `05-sprint-4-readiness.md` |
| 6 | Triage and decision | Orchestrator | — | `00-triage-summary.md` |
| 7 | Decide: cleanup PR (≥ #144) or standalone report | Orchestrator | — | PR + `06-deferred-to-sprint-4.md` |
| 8 | Sprint 4 kickoff readiness confirmation | PM | QA | `docs/sprint-zero/sprint-4-kickoff-readiness.md` |

---

## Method — the design-fidelity lens (Phase 1)

Phase 1 runs `docs/copilot_prompts/sprint_3/retro-design-validation.md` as its method, carrying
its two confirmed findings in as known inputs:

1. **The single-line-fit standard.** Every element the handoff draws on one line
   (`white-space:nowrap` pills/chips, amounts/balances, one-line row titles/subtitles) must
   render on one line and **scale text down to fit** (`FittedBox(scaleDown)` + `maxLines:1` +
   `softWrap:false`) — never wrap, and **money must never truncate/ellipsise**. #143 fixed the
   balance pill, the home top-balance row, and the Settle-Up gap; Phase 1 verifies those held
   and extends the standard app-wide.

2. **The rupee-glyph (₹-in-Hanken) finding.** Amounts rendered in a Hanken `textTheme` slot show
   U+20B9 as tofu (Bricolage carries ₹, the bundled Hanken static instance does not). Every
   `formatInrFromPaise(...)` render must resolve to an `OBTText.amount*` Bricolage helper, never a
   Hanken `titleMedium`/`bodyMedium`/… slot. #143 fixed the Friends-summary band; this phase fixes
   the remaining confirmed sites and any the matrix surfaces.

**Already verified this session** (seeds Phase 1): `step_2_split_and_payer.dart` (Total, on
`titleMedium`) and `obt_settle_up_sheet.dart` (the "You paid … ₹…" success sentence, on
`bodyMedium`) are genuine unfixed tofu sites; `expense_detail_screen.dart` and
`settlement_history_screen.dart` already render their amounts via `OBTText.amount`.

---

## Determinism and golden discipline (binding)

Goldens are host-sensitive. Baselines are authored **only** on `ubuntu-latest` via the
`golden-refresh` `workflow_dispatch` job, downloaded as the `golden-baselines` artifact, and
**every changed PNG is reviewed as an image** before commit. **macOS `--update-goldens` bytes
are never committed.** Multi-tag CI selection uses the boolean-OR selector
(`--tags "golden || a11y-contrast || a11y-dynamic-type"`).

---

## PR Numbering Note

Issues and PRs share one sequential namespace. The highest PR is #143 and the highest issue is
#128, so any cleanup PR lands as **#144** (or the next free number if a Bucket-B issue is filed
first). The slot label is reconciled at PR open.

---

## Execution Protocol

- Phase by phase: stop after each, wait for explicit "proceed" before the next.
- Phases 1–5 produce audit reports under `docs/audits/sprint-3/`, each finding a row:
  *location, divergence/finding, severity, action (fix now / backlog / accept), owner*.
  Phases 1–2 also stage code/test fixes.
- Phase 6 triages every finding into Buckets A/B/C.
- Phase 7 acts on the triage: open the cleanup PR (≥ #144), or commit the reports as a docs-only
  PR if Bucket A is empty. Bucket-B items are filed as milestone-assigned GitHub issues and
  listed in `06-deferred-to-sprint-4.md`; Bucket-C items get an ADR/retro note.
- Phase 8 confirms Sprint 4 readiness (`sprint-4-kickoff-readiness.md`), reconciles
  `sprint-3-plan.md` (mark fully closed; record the cleanup PR) and `next-three-prs.md` (add the
  cleanup/audit row; flip the Sprint-4 Groups epic to next-up), and QA posts a sign-off.

---

## References Read Before Framing

- `.github/copilot-instructions.md`, `.github/shared/invariants.md` (four invariants confirmed)
- `.github/shared/decision-log.md` (ADRs through ADR-0025; Haldi adoption + §4.1 reconciliation)
- `.github/shared/milestone-tracking.md`, `coding-standards.md`, `handoffs.md`, `test-strategy.md`
- `.github/skills/review-pull-request/SKILL.md` (the design-grounded review lens)
- `design_handoff_one_by_two/` (Phase1 Foundations, Phase2 Components, Phase3a/b/c/e/f/g;
  Phase3d Groups + Phase4 Marketing out of scope)
- `docs/audits/design-conversion/` (the Sprint-3 planning pack)
- `docs/copilot_prompts/sprint_3/retro-design-validation.md` (Phase-1 method + two confirmed findings)
- `docs/audits/sprint-2/` (the precedent this session mirrors)
- Live GitHub state: milestones, 13 open Sprint-4 issues, highest PR #143 / issue #128, next slot #144
