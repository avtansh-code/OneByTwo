# Sprint 2 Plan

> Last updated: PR #31.

---

## Sprint Goal

Deliver the **Friends epic** (FR-FR-01 through FR-FR-04), establishing the social
graph that all downstream features (expenses, settlements, groups) depend upon.

---

## PR Tracking

| PR | Story | Title | SP | Status |
|---|---|---|---|---|
| #31 | FR-FR-01 (UI) | Contact picker UI for add-friend flow | 3 | In flight |
| #32 | FR-FR-01 (Matching) | User lookup and friendship creation | 2 | Queued |
| #33 | TBD | Per Sprint 2 plan — likely FR-FR-02 or FR-FR-03 | TBD | Queued |
| #34 | TBD | Per Sprint 2 plan | TBD | Queued |

---

## Velocity

This is the first Sprint 2 data point. No meaningful velocity comparison against
Sprint 1 (43 SP across 10 PRs) is possible until at least 3 Sprint 2 PRs have
merged.

Sprint 1 reference:

| Metric | Sprint 1 |
|---|---|
| PRs merged | 10 (#1 through #10) |
| Story points delivered | 43 |
| Chore/cleanup PRs | 4 (#11 through #14, plus hotfix #29 and chore #30) |

---

## Scope Notes

- FR-FR-01 has been split into two sub-stories: the contact picker UI (PR #31)
  and the matching and friendship creation logic (PR #32). This split follows
  ADR-0013 (Contact Matching Strategy — Local Intersection).
- FR-FR-02 (link existing user or invite via system share sheet) and FR-FR-03
  (friends list with simplified net balance) are both DoR-compliant with story
  files written in PR #14.
- FR-FR-04 (per-friend transaction history) depends on FR-EX-01 and may slip to
  a later sprint if expense work is not yet available.
