# Sprint 2 Plan

> Last updated: PR #32.

---

## Sprint Goal

Deliver the **Friends epic** (FR-FR-01 through FR-FR-04), establishing the social
graph that all downstream features (expenses, settlements, groups) depend upon.

---

## PR Tracking

| PR | Story | Title | SP | Status |
|---|---|---|---|---|
| #31 | FR-FR-01 (UI) | Contact picker UI for add-friend flow | 3 | Merged |
| #32 | FR-FR-01 (Matching) | User lookup and friendship creation | 3 | In flight |
| #33 | TBD | Per Sprint 2 plan — likely FR-FR-02 or FR-FR-03 | TBD | Queued |
| #34 | TBD | Per Sprint 2 plan | TBD | Queued |

---

## Velocity

| PR | SP | Status |
|---|---|---|
| #31 | 3 | Merged |
| #32 | 3 | In flight |
| **Total** | **6** | **2 PRs so far** |

Sprint 1 reference:

| Metric | Sprint 1 |
|---|---|
| PRs merged | 10 (#1 through #10) |
| Story points delivered | 43 |
| Chore/cleanup PRs | 4 (#11 through #14, plus hotfix #29 and chore #30) |

---

## Scope Notes

- FR-FR-01 is now **complete** across two PRs: the contact picker UI (PR #31,
  merged) and the matching and friendship creation logic (PR #32, in flight).
  This split followed ADR-0013 (Contact Matching Strategy — Local Intersection).
- ADR-0014 (Cloud Function Gateway) was ratified during PR #32 to govern the
  matching mechanism via a callable Cloud Function rather than direct client
  Firestore queries against the users collection.
- FR-FR-02 (link existing user or invite via system share sheet) and FR-FR-03
  (friends list with simplified net balance) are both DoR-compliant with story
  files written in PR #14.
- FR-FR-04 (per-friend transaction history) depends on FR-EX-01 and may slip to
  a later sprint if expense work is not yet available.
