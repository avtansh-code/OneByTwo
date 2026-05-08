# Sprint 2 Plan

> Last updated: PR #33.

---

## Sprint Goal

Deliver the **Friends epic** (FR-FR-01 through FR-FR-04), establishing the social
graph that all downstream features (expenses, settlements, groups) depend upon.

---

## PR Tracking

| PR | Story | Title | SP | Status |
|---|---|---|---|---|
| #31 | FR-FR-01 (UI) | Contact picker UI for add-friend flow | 3 | Merged |
| #32 | FR-FR-01 (Matching) | User lookup and friendship creation | 3 | Merged |
| #33 | FR-FR-01 (Manual Entry) | Manual phone-number friend-add | 2 | In flight |
| #34 | FR-FR-03 | Friends list rendering | TBD | Queued |

---

## Velocity

| PR | SP | Status |
|---|---|---|
| #31 | 3 | Merged |
| #32 | 3 | Merged |
| #33 | 2 | In flight |
| **Total** | **8** | **3 PRs so far** |

Sprint 1 reference:

| Metric | Sprint 1 |
|---|---|
| PRs merged | 10 (#1 through #10) |
| Story points delivered | 43 |
| Chore/cleanup PRs | 4 (#11 through #14, plus hotfix #29 and chore #30) |

---

## Scope Notes

- FR-FR-01 is now **complete** across three PRs: the contact picker UI (PR #31,
  merged), the matching and friendship creation logic (PR #32, merged), and the
  manual phone entry path (PR #33, in flight). This three-PR split validated
  clean pattern reuse of the phone validator, IndianPhoneInputFormatter, and
  MatchAndInviteController.
- ADR-0013/0014 reconciliation (merged before PR #33) confirmed both ADRs
  cross-reference each other. No new ADR was needed for PR #33.
- FR-FR-02 (link existing user or invite via system share sheet) was implemented
  as part of PR #32's MatchAndInviteController. The story file exists at
  `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md`.
- FR-FR-03 (friends list with simplified net balance) is DoR-compliant and is
  the next PR (#34).
- FR-FR-04 (per-friend transaction history) depends on FR-EX-01 and may slip to
  a later sprint if expense work is not yet available.

## Pattern Reuse Validation (PR #33)

PR #33 was intentionally the smallest feature PR in Sprint 2 to validate that
the patterns from PRs #31/#32 generalise cleanly. Key findings:

- **Phone validator reuse:** `validateIndianMobile()` from `lib/core/validators.dart`
  lifted cleanly. No fork or wrapper needed. Already in shared location.
- **Input formatter reuse:** `IndianPhoneInputFormatter` from auth imported
  across feature boundary without friction. Future chore may relocate to
  `lib/core/widgets/`.
- **Controller reuse:** `MatchAndInviteController.performLookup()` consumed a
  `SelectedContact` from manual entry identically to the contact picker path.
  No subclassing or new methods required.
- **No friction surfaced.** The three-PR pattern split for FR-FR-01 validated
  cleanly.
