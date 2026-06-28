# Phase 6 — Triage Summary

**Owner:** Orchestrator
**Input:** Phases 1–5 (`01`–`05` under `docs/audits/sprint-3/`).
**Rule:** every finding lands in exactly one bucket with a rationale; per the stakeholder
directive, the triage biases to **Bucket A**.

---

## Bucket A — Fix now (the cleanup PR)

### Code / test (staged in this branch)

| # | Finding (phase) | Fix | Files |
|---|---|---|---|
| A1 | ₹-in-Hanken tofu: standalone "Total" on `titleMedium` (1) | swap to `OBTText.amount` | `step_2_split_and_payer.dart` |
| A2 | ₹-in-Hanken tofu: 5 sentence/message sites — 3 found by grep + 2 decoupled domain→presentation renders caught by golden image review (1) | new `OBTText.rupeeAware(theme, style)` glyph fallback | `obt_settle_up_sheet.dart`, `obt_segmented_split_control.dart`, `friend_history_screen.dart`, `split_validation_message.dart`, `obt_amount_input.dart` |
| A3 | single-line-fit: 7 unprotected amount figures (1) | `FittedBox(scaleDown)` + `maxLines:1`/`softWrap:false` (`Flexible` in rows) | settle-up sheet/card, activity row, friend-history, friend-detail-timeline, spending-breakdown, split-row |
| A4 | new pinned cases (1) | `rupeeAware` contract test + focal scale-to-fit test | `test/core/theme/obt_text_test.dart`, `obt_settle_up_card_test.dart` |
| A5 | golden blind-spot: no content guard on dc07/08/09 (2) | shared `expectGoldenState` + wired into the 3 error loops | `golden_harness.dart`, `dc07/dc08/dc09` |
| A6 | superseded visual docs unmarked (3) | `> [!WARNING]` banner on 21 docs + scoped banner on the package README | `docs/design/**` |
| A7 | DC/#143 decisions not ratified; patterns uncodified (3) | ADR-0026 + coding-standards + feature-pr-conventions back-ports | `decision-log.md`, `coding-standards.md`, `feature-pr-conventions.md` |

### Owner action (repo setting — cannot be a PR code change)

| # | Finding (phase) | Action | Owner |
|---|---|---|---|
| A8 | **HIGH** — `golden-a11y-checks` (DC-13) + `a11y-checks` (DC-12) are **not required status checks** in ruleset `15802807`; the visual/accessibility gates can be bypassed at merge (4) | add both contexts to the ruleset's required checks **before Sprint 4** | Repo owner |

---

## Bucket B — Backlog (milestone-assigned issues, filed at Phase 7)

| # | Finding (phase) | Milestone | Rationale |
|---|---|---|---|
| B1 | Dependency-refresh: `firebase_*` minor patch bumps + 34 moderate/low transitive `npm audit` advisories in the `firebase-admin` tree (4) | Post-v1.0 | No HIGH/CRITICAL, none Sprint-3-introduced; a refresh is its own project (a major `firebase-admin`/`riverpod 3.x` bump is out of scope for a visual cleanup). |
| B2 | Nightly deploy unverified-green: no run recorded yet (4) | Sprint 4 | Wiring is correct; needs one `workflow_dispatch` run to confirm the service-account + deploy path before relying on the unattended cron. |
| B3 | Track A8 (required-checks gap) as an issue so the owner action is auditable (4) | Sprint 4 | A repo-settings change should have a tracking issue even though it is not a code change. |

---

## Bucket C — Accept and document

| # | Finding (phase) | Where recorded |
|---|---|---|
| C1 | `obt_segmented_split_control.dart:183` running allocated-total left un-wrapped — bounded by a single expense total inside a control that already uses `FittedBox` for its labels; cannot realistically overflow | `01-design-fidelity-validation.md` §6 |
| C2 | Historical planning-time annotations in `02-conversion-checklist.md` (e.g. pill "~80% built") left as a snapshot rather than rewritten | `03-documentation-and-decision-drift.md` §3.3 |

---

## Out of scope (refused / re-routed — none triggered)

No finding required altering a Cloud Function, a Firestore/Storage rule, `firestore.indexes.json`,
the schema, a trigger, the simplified-debts algorithm, or a telemetry-event contract. The Phase-4
required-checks gap (A8) is a **repo setting**, not a backend contract. Nothing was refused for
invariant/SRS conflict; all four invariants hold (display/test/docs only).

---

## Decision (feeds Phase 7)

Bucket A is **non-empty** → open the **cleanup PR** (next slot ≥ #144) carrying A1–A7, the
`docs/audits/sprint-3/` reports, this prompt, and the goldens **re-baselined on ubuntu**. A8 is
handed to the owner (and tracked as B3). B1/B2 are filed as milestone issues. C1/C2 are recorded.

**Goldens to re-baseline on ubuntu before merge** (Phase-1 visual deltas): `dc05`–`dc09`,
`haldi_components`, `obt_widgets_reskin` — every changed PNG reviewed as an image; the only delta
must be the ₹/scale-to-fit change.
