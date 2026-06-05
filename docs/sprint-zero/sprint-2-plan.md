# Sprint 2 Plan

> Last updated: PR #35.

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
| #34 | FR-FR-01 (Manual Entry) | Manual phone-number friend-add | 2 | Merged |
| #35 | FR-FR-03 | Friends list with simplified net balance | 3 | Merged |

---

## Velocity

| PR | SP | Status |
|---|---|---|
| #31 | 3 | Merged |
| #32 | 3 | Merged |
| #34 | 2 | Merged |
| #35 | 3 | Merged |
| **Total** | **11** | **4 PRs so far** |

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
  manual phone entry path (PR #34, merged). This three-PR split validated
  clean pattern reuse of the phone validator, IndianPhoneInputFormatter, and
  MatchAndInviteController.
- ADR-0013/0014 reconciliation (PR #33, merged before PR #34) confirmed both
  ADRs cross-reference each other. No new ADR was needed for PR #34.
- FR-FR-02 (link existing user or invite via system share sheet) was implemented
  as part of PR #32's MatchAndInviteController. The story file exists at
  `docs/sprint-zero/stories/FR-FR-02-link-or-invite-friend.md`.
- FR-FR-03 (friends list with simplified net balance) shipped in PR #35 — the
  first client surface to read `simplifiedBalances` (Invariant 2 read path) and
  the first to display monetary values in INR (Invariant 1). It introduced the
  shared `formatInrFromPaise` formatter and `netBalancePaise` pure function in
  `lib/core/`, the `userProfileProvider.family(uid)` caching pattern, and a
  composite Firestore index `memberIds + lastActivityAt`.
- FR-FR-04 (per-friend transaction history) depends on FR-EX-01 and may slip to
  a later sprint if expense work is not yet available.

## Pattern Reuse Validation (PR #34)

PR #34 was intentionally the smallest feature PR in Sprint 2 to validate that
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

## Pattern Establishment (PR #35)

PR #35 introduced patterns that downstream balance-rendering screens will
inherit:

- **`lib/core/formatters/inr_formatter.dart`** — single source of truth for
  paise → INR string formatting (Indian numbering, Unicode minus, always two
  decimal places). Every future screen that shows money must call this
  formatter; inline arithmetic is forbidden by the boundary contract grep.
- **`lib/core/balances/net_balance.dart`** — pure read-side reducer for the
  nested `simplifiedBalances` map. Reusable for the Home dashboard
  (`netBalanceProvider`, FR-HD-01) and groups (`group_list_provider`).
- **`lib/core/telemetry/event_id_hash.dart`** — SHA-256-truncated hash for
  opaque correlation IDs in telemetry. Used by `friend_row_tapped`; reuse for
  any future event that would otherwise carry a deterministic UID-composed ID.
- **`userProfileProvider.family(uid)`** caching pattern — one-shot cached user
  doc lookups, keyed per uid via Riverpod family. Reusable for any screen that
  resolves "the other user's display profile" by uid (group member list,
  expense splits, etc.).
- **`FriendDetailPlaceholderScreen`** — intentional minimal placeholder; the
  FR-FR-04 PR replaces it with the real Friend Detail screen and keeps the
  same call site in `FriendsListScreen.onRowTap`.
