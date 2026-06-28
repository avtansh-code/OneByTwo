# Sprint 4 Kickoff Readiness

**Date:** 2026-06-24
**Author:** PM
**QA sign-off:** posted on PR #91 (see below)
**Status:** GREEN LIGHT — Sprint 4 (Groups and Settlements) may begin once PR #91 merges.

> **Renumbered (2026-06-25):** this was originally the *Sprint 3* (Groups and Settlements)
> kickoff readiness. A Design Conversion sprint (migration to the Haldi visual system, ADR-0024)
> was inserted as the new **Sprint 3**, so the Groups-and-Settlements sprint is now **Sprint 4**.
> Forward-looking sprint references below are updated to Sprint 4; names that predate the
> renumber (the "Sprint 2 → Sprint 3 boundary audit" and the audit file
> `docs/audits/sprint-2/05-sprint-3-readiness.md`) keep their original numbering. See
> `docs/audits/design-conversion/`.

This document is the green light to start Sprint 4. It confirms that the Sprint 2 ->
Sprint 3 boundary audit (`docs/audits/sprint-2/`) is fully resolved and that the first
Sprint-4 PR is unblocked.

---

## 1. Audit resolution — all five phases closed

| Phase | Report | Resolution |
|---|---|---|
| 1 Documentation drift | `01-documentation-drift.md` | Bucket-A doc fixes in PR #91; remainder filed on milestones (#83, #84, #85, #86, #88). |
| 2 Test-suite health | `02-test-suite-health.md` | S6 executable add-friend test added (PY3); trigger-branch coverage filed (#82); harness deferral (#23) accepted. |
| 3 Agentic infrastructure debt | `03-agentic-infrastructure-debt.md` | Review-skill checks + QA reachability duty in PR #91 (SK2/AG2); hook hardening filed (#87). |
| 4 Dependency and security | `04-dependency-and-security.md` | 4 HIGH npm advisories cleared (D5); avatar rules tests added (R4); rules split + deps filed (#81, #89). No committed secrets. |
| 5 Sprint 3 readiness | `05-sprint-3-readiness.md` | FR-GR-01/02/03 stories written (SR1); invite-token model designed (SR4); Groups risks added (SR9); group-rules + components + go_router filed (#78, #79, #80). |

### Bucket disposition

- **Bucket A (33) — fixed** in PR #91 (10 scoped commits; all CI green).
- **Bucket B (44) — filed** as milestone-assigned issues #78-#90 (+ D1 on #22); tracker
  `06-deferred-to-sprint-3.md`.
- **Bucket C (9) — accepted** and documented (ADR-0022 server-projection generalisation;
  screen-spec notes; the #23 harness deferral retained for Sprint 6).

No finding is unresolved or untriaged.

---

## 2. First three Sprint-4 PRs queued

| # | Issue | Story file | DoR | Notes |
|---|---|---|---|---|
| 1 | **#92 FR-GR-01** Create group | `stories/FR-GR-01-create-group.md` | Compliant (6 AC, 2 negative) | **The first Sprint-4 PR. Unblocked.** Schema, create rule, screen spec, wireframe, mockup, telemetry all exist. |
| 2 | #93 FR-GR-02 Invite members | `stories/FR-GR-02-invite-members.md` | Compliant (6 AC, 2 negative) | Builds on the invite-token model (ADR-0023 + `groupInvites` schema/rules). Invariant 3 governs the share link. |
| 3 | #94 FR-GR-03 Invite-link expiry/revocation | `stories/FR-GR-03-invite-link-expiry.md` | Compliant (5 AC, 2 negative) | 7-day expiry + admin revocation enforced server-side (risk R-18). |

The Sprint 4 milestone is populated with these three stories plus the Bucket-B
follow-ups (#78-#88) and the carried `#8` Node.js-24 CI chore.

---

## 3. First Sprint-4 PR — identified and unblocked

**FR-GR-01 (Create group) — issue #92 — is the first Sprint-4 PR.** It is unblocked:

- Story file exists and is DoR-compliant (SR1 resolved).
- `groups/{groupId}` schema is complete and the create rule is live in `firestore.rules`
  (Invariant 2: no `simplifiedBalances` at create).
- Screen spec (SCR-14), wireframe, mockup, and `group_created` telemetry exist.
- `lib/features/groups/` is an empty stub — the feature-first scaffold is the first build
  step (no migration needed).
- `go_router` is **not** required for FR-GR-01 (imperative navigation to SCR-15 on
  success); the go_router scope decision (#80) is needed only before FR-GR-02/04.

**Open design prerequisites for the dependent stories** (not FR-GR-01 blockers, tracked):
the zero-balance-guard enforcement decision and group-rules completion (#78), and the
member-row / invite-link-card components (#79).

---

## 4. QA sign-off

QA has reviewed PR #91 (all eight CI checks green: Title Lint, change-detection,
Flutter Lint & Test, Cloud Functions Lint & Test, Build Android, Build iOS, Integration
Tests, Coverage Gate) and the audit resolution, and posts the sign-off comment on PR #91.
On merge of #91, Sprint 4 is cleared to begin with FR-GR-01 (#92).

---

## 5. Sprint 3 → Sprint 4 boundary sweep addendum (2026-06-28)

A Design Conversion sprint (Sprint 3, the Haldi visual system — ADR-0024) was inserted and
completed (18 issues, 0 open) after this readiness was first written. The Sprint 3 → Sprint 4
boundary sweep (`docs/audits/sprint-3/`) re-validated the shipped conversion before Groups
opens. Its resolution:

| Phase | Report | Resolution |
|---|---|---|
| 1 Design fidelity | `01-design-fidelity-validation.md` | 9 rupee-glyph (₹-in-Hanken) tofu renders + 7 single-line-fit amount figures fixed in **PR #144**. |
| 2 Golden + a11y | `02-golden-and-a11y-health.md` | `expectGoldenState` guards on dc07/08/09; a11y families green; goldens re-baselined on ubuntu. |
| 3 Docs + decisions | `03-documentation-and-decision-drift.md` | 22 superseded-doc banners; ADR-0026; coding-standards back-ports. |
| 4 Infra/dep/deploy | `04-infra-dependency-and-deploy.md` | HIGH: golden/a11y not required checks → **#145** (owner action, before Sprint 4). |
| 5 Sprint 4 readiness | `05-sprint-4-readiness.md` | Groups is READY on Haldi; all gaps already tracked (#78/#79/#81). |

### Bucket disposition

- **Bucket A — fixed** in **PR #144** (rupee-glyph + single-line-fit + golden guards + docs/ADR-0026).
- **Bucket B — filed:** **#145** (require Golden & A11y + Accessibility Gate checks — Sprint 4),
  **#146** (verify nightly deploy green — Sprint 4), **#147** (dependency refresh — Post-v1.0).
  Tracker: `docs/audits/sprint-3/06-deferred-to-sprint-4.md`.
- **Bucket C — accepted:** the segmented-split running-total; historical planning-checklist notes.

### Design readiness for Groups (updated)

Groups must be built **Haldi-native** — the group Haldi components (group list tile, member row,
invite-link card, group settle-up surfaces, group tab bar) **do not exist yet** and are Sprint 4
PR #1's first build step (#79), never a later reskin. The Phase3d handoff reference exists.

### Pre-Sprint-4 gate

**#145 (required-checks registration) is an owner repo-setting action and should be applied
before Sprint 4 opens** so the Groups epic inherits enforced visual/accessibility gates. It does
not block PR #144.

### QA sign-off (Sprint-3 retro)

On merge of **PR #144**, the Haldi system is fidelity-clean (no money renders the rupee as tofu;
every one-line amount scales to fit; goldens regenerated on ubuntu and image-reviewed; a11y
families green) and Groups can be built on it. Sprint 4 (FR-GR-01, building the group Haldi
components first) is cleared to begin, contingent on the #145 owner action.
