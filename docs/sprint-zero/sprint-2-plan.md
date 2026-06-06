# Sprint 2 Plan

> Last updated: PR #37 + chore-backlog audit (issues #15-#28).

---

## Sprint Goal

Deliver the **Friends epic** (FR-FR-01 through FR-FR-04), establishing the social
graph that all downstream features (expenses, settlements, groups) depend upon.

---

## ⚠ Critical Cross-PR Constraints

These constraints span multiple PRs and MUST be honoured. They are surfaced
here so the next orchestrator / PM / architect cannot accidentally violate
them by sequencing PRs in isolation.

### C-1: Bundle chore #25 with PR #38 (FR-EX-01)

**Chore #25** ([Expense event naming convention decision](https://github.com/avtansh-code/OneByTwo/issues/25))
MUST be resolved in the same PR as FR-EX-01 (expense creation UI). The
choice is between `expense_added` / `expense_add_failed` and
`expense_save_succeeded` / `expense_save_failed`.

**Why bundle:** PR #38 is the FIRST PR that logs any expense analytics
event. Once the first event ships, every downstream funnel chart, alert,
and Sprint 3+ instrumentation inherits the naming convention. Splitting
the decision into a separate later chore PR would force a backfill on the
event taxonomy AND on every test that asserts event names — a meaningful
rework cost for zero benefit.

**Operational rule:** PR #38 cannot ship without:
1. The naming-convention decision recorded in
   `docs/design/07-technical/telemetry-plan.md` (and any related
   telemetry index).
2. All expense events in `lib/features/expenses/**` using the chosen
   names.
3. Issue #25 closed in the same PR (`Closes #25` in the PR body) with a
   comment summarising the decision and citing the affected files.

**Architect's call:** the decision itself is the architect's at PR #38
kickoff. The orchestrator MUST refuse to start FR-EX-01 implementation
work until the decision is recorded in the story file's Architect Notes.

---

## PR Tracking

| PR | Story | Title | SP | Status |
|---|---|---|---|---|
| #31 | FR-FR-01 (UI) | Contact picker UI for add-friend flow | 3 | Merged |
| #32 | FR-FR-01 (Matching) | User lookup and friendship creation | 3 | Merged |
| #34 | FR-FR-01 (Manual Entry) | Manual phone-number friend-add | 2 | Merged |
| #35 | FR-FR-03 | Friends list with simplified net balance | 3 | Merged |
| #36 | FR-SE-03/04 | `onExpenseWriteFriendship` Firestore trigger | 3 | Merged |
| #37 | FR-SE-05/06 | `onSettlementWrite` Firestore trigger + settlements rules + algorithm extension | 5 | In review |

---

## Velocity

| PR | SP | Status |
|---|---|---|
| #31 | 3 | Merged |
| #32 | 3 | Merged |
| #34 | 2 | Merged |
| #35 | 3 | Merged |
| #36 | 3 | Merged |
| #37 | 5 | In review |
| **Total** | **19** | **6 PRs so far** |

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
- FR-SE-03/04 (`onExpenseWriteFriendship` trigger) shipped in PR #36 — the
  first Firestore trigger in the application and the first non-callable
  producer of `simplifiedBalances` (Invariant 2 server-side writer). It
  added a shared `recomputeAndWrite` core to the simplified-debts module,
  the `lastActivityAt` monotonicity guard, the bounded-enumeration sum
  check in Firestore Security Rules for the
  `friendships/{id}/expenses/{id}` subcollection, and enabled
  `npm run test:integration` inside `firebase emulators:exec` so future
  triggers exercise their registration end-to-end in CI.
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

## Pattern Establishment (PR #36)

PR #36 introduced patterns that downstream Cloud Functions triggers will
inherit:

- **Shared core extraction (`recomputeAndWrite`)** — the simplified-debts
  callable and the new `onExpenseWriteFriendship` trigger now both consume
  a typed-result core that takes an `alsoSet` payload for atomic
  additional writes. Future triggers (`onExpenseWriteGroup` in Sprint 3,
  `onSettlementWrite` next) reuse this seam without re-implementing the
  algorithm.
- **`lastActivityAt` monotonicity guard** — `max(existing, eventTimestamp)`
  applied inside the same Firestore transaction as the
  `simplifiedBalances` write. Prevents out-of-order Cloud Functions
  delivery from regressing the friends-list ordering (FR-FR-03 AC-6).
- **Bounded enumeration sum check in Firestore Security Rules** — the
  `friendships/{id}/expenses/{id}` block enumerates split positions up to
  the schema-natural cap (N=2 for a two-member friendship) with each
  index access guarded by `splits.size() > i`. The groups subcollection
  (Sprint 3) will declare its own bounded enumeration matching the
  group-member cap.
- **First Firestore trigger registration end-to-end in CI** — the PR
  pipeline now runs `npm run build && npm run test:integration` inside
  `firebase emulators:exec --only auth,firestore,functions,storage`, so
  every future trigger PR exercises its registration, not just its
  handler in isolation.
- **First non-callable producer of `simplifiedBalances`** — Invariant 2
  transitioned from a read-side abstraction to a live server-side
  production-data writer. The DoD invariant grep confirms exactly one
  write site remains in `functions/src/` (variant 2.3(b) collapses the
  callable and trigger to a shared writer).

The architect notes appended to
`docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md`
ratify all design decisions taken in this PR.

## Pattern Extension (PR #37)

PR #37 extends the patterns ratified by PR #36 to ship the
`onSettlementWrite` trigger:

- **Shared core takes an additional read source** —
  `recomputeAndWrite` now reads both the per-context expenses
  subcollection AND the top-level `settlements` collection inside the
  same Firestore transaction. `computeNetBalances` accepts both and
  folds them together (expenses credit payer / debit splits;
  settlements credit `fromUserId` / debit `toUserId`). The public
  signature of `recomputeAndWrite` is unchanged — settlements are an
  internal implementation detail.
- **First trigger on a top-level collection** — the
  `onSettlementWrite` trigger registers at `settlements/{settlementId}`
  and reads the context discriminator (`contextType`, `contextId`)
  from the document data rather than the trigger path. Naturally
  handles both friendship and group contexts without modification when
  groups ship in Sprint 3.
- **Invariant-2 parallel for `verificationStatus` on settlements** —
  enforced by the new `match /settlements/{settlementId}` security
  rules block (field-level diff rejects client mutation). v1.0 has no
  server-side writer; the rules are the enforcement mechanism per
  ARCH-EXT-06.
- **Settlements schema additions** — `deleted: bool` (default `false`)
  for soft-delete and `createdAt: timestamp` (immutable) for audit
  history. The settlements rules permit ONLY soft-delete on update;
  every other field is immutable. Hard-delete is admin-only.
- **In-code soft-delete filter for settlements** — the algorithm
  filters `deleted === true` settlements in JavaScript inside
  `computeNetBalances` rather than chaining a third Firestore
  `where('deleted', '!=', true)` on the cross-field query. This avoids
  an over-specified three-field composite index for negligible
  computational cost (settlements per context are small).
- **Composite index for settlements queries** — declared in
  `firestore.indexes.json`:
  `{collectionGroup: 'settlements', fields: [contextType ASC, contextId ASC]}`.

The architect notes appended to
`docs/sprint-zero/stories/FR-SE-05-06-settlement-trigger.md`
ratify the PR #37 design decisions.

---

## Sprint 2 Chore Backlog (open GitHub issues)

The Sprint 1 boundary audit (PR #14) deferred 37 findings into Bucket B.
Fourteen of those were filed as labelled GitHub issues
(`sprint-2-chore`) with numbers **#15-#28**. None are closed on GitHub yet,
but several have been partially or fully addressed by Sprint 2 feature
PRs (#31-#36). The table below is the audited status as of PR #36.

Status legend:
- **Closed-in-code** — work is complete in the repository; the GitHub
  issue can be closed by ticking the relevant checklist and merging
  evidence of the fix. Sprint-1 burndown
  (`docs/audits/sprint-1/07-bucket-b-burndown.md`) is the authority on
  which Bucket-B IDs are formally resolved.
- **Partially addressed** — at least one named Bucket-B sub-item is
  resolved; remainder is still open under the same issue.
- **Open** — no work done yet.

| # | Title | Audit IDs | Status | Verification |
|---|---|---|---|---|
| [#15](https://github.com/avtansh-code/OneByTwo/issues/15) | Rename `authStateNotifierProvider` to `authStateProvider` | M1 | Open | 10+ references still use the old name across `lib/main.dart`, `lib/features/profile/**`, `lib/features/auth/presentation/**`. |
| [#16](https://github.com/avtansh-code/OneByTwo/issues/16) | Missing secondary telemetry events + `is_new_user` typing | T3, T4, T5 | Open | `phone_entry_viewed` / `phone_validation_failed` / `otp_verification_started` / `otp_send_requested` not yet emitted; `is_new_user` still logged as `int` (`otp_entry_controller.dart:215` — `value.isNewUser ? 1 : 0`); `signup_otp_submitted` decision not recorded. |
| [#17](https://github.com/avtansh-code/OneByTwo/issues/17) | Relocate core providers to `lib/core/providers/` | M4 | Open | `lib/core/providers/` does not exist; `firebaseFirestoreProvider`, `firebaseStorageProvider`, `phoneAuthRepositoryProvider` still in feature trees. |
| [#18](https://github.com/avtansh-code/OneByTwo/issues/18) | Screen-spec alignment (splash, phone entry, OTP) | S1, S3, S4, S5 | Open | Splash uses `Duration(seconds: 3)` (`splash_screen.dart:19`); spec says 1500 ms. Other items (inline-vs-snackbar OTP error, live phone formatting, exhausted-resend copy) still unresolved. |
| [#19](https://github.com/avtansh-code/OneByTwo/issues/19) | Add PR coverage tracking to conventions | CV2 | Partially addressed | `feature-pr-conventions.md` has an enforced-thresholds section and `.github/PULL_REQUEST_TEMPLATE.md` has a "Coverage thresholds maintained" checkbox. **Still missing:** explicit before/after coverage fields requested by the issue. |
| [#20](https://github.com/avtansh-code/OneByTwo/issues/20) | Improve test coverage gaps | SC1, SC2, SC3, SC4, **CV3** | Partially addressed | **CV3 closed by PR #36** — `functions/src/simplified-debts/function.ts` branch coverage now **90%** (was 76%) thanks to the `recomputeAndWrite` variant 2.3(b) refactor. SC1 (concurrent submit guard), SC2 (OTP auto-retrieval timeout), SC3 (`MAX_SAFE_INTEGER`), SC4 (large-group scalability) still open. |
| [#21](https://github.com/avtansh-code/OneByTwo/issues/21) | Firestore + Storage rules test gaps | **R1, R2, R3, R4**; R5-R8 | Partially addressed | **R1, R2, R3 closed by PR #32** (friendship create/update/delete rules tests). **R4 closed by PR #36** — new `expenses-friendship.test.ts` covers 45 cases including sum check, extension-point locks, immutables, soft-delete. R5-R6 (group rules) still open (Sprint 3). R7-R8 (Storage avatar file-size / content-type) still open — `storage-rules/avatars.test.ts` only covers basic read/write. |
| [#22](https://github.com/avtansh-code/OneByTwo/issues/22) | Dependency upgrades — Riverpod 3.x, share_plus, firebase-functions 7.x | D1, D2, D4, D5, D6, D7 | Open | No upgrade PRs merged. Firebase deploy warnings surfaced D5 (`firebase-functions` 6→7) and the Node 20 deprecation deadline (Oct 2026). |
| [#23](https://github.com/avtansh-code/OneByTwo/issues/23) | Expand integration tests for Sprint 2 flows | PY3, RT2, INV2 | Partially addressed | **PR #36 enabled `npm run test:integration` inside `firebase emulators:exec`** — every future trigger PR exercises its actual registration in CI (helps PY3). Friend-add stub `test/integration/friends/friends_list_flow_test.dart` shipped in PR #35 (still skipped). RT2 (CI step duration logging) not yet added. INV2 (share-sheet verification) — system share sheet is the only path, but no test asserts the package-import boundary. Expense-create flow integration tests blocked on FR-EX-01. |
| [#24](https://github.com/avtansh-code/OneByTwo/issues/24) | Conventions doc — CF PR checklist and Jest config separation | CN3, CN4 | Open | `feature-pr-conventions.md` does not yet enumerate the Jest config split (`jest.config.js` vs `jest.rules.config.js` vs `jest.integration.config.js`) nor CF-specific PR checklist items (region pinning, error-code mapping, transaction usage, idempotency). |
| [#25](https://github.com/avtansh-code/OneByTwo/issues/25) | Expense event naming convention decision | SR8 | **Open — blocking PR #38 (see Critical Constraint C-1 above)** | Decision must be taken before FR-EX-01 ships. No expense events shipped yet; `lib/` grep for `expense_added` / `expense_save_succeeded` returns zero matches. |
| [#26](https://github.com/avtansh-code/OneByTwo/issues/26) | Release pipeline secrets + DPDP legal sign-off | S2_sec, SR12 | Open | Sprint 6 work — explicit tracking required before release execution. |
| [#27](https://github.com/avtansh-code/OneByTwo/issues/27) | Float/double rejection hook for Invariant 1 | INV3 | Open — low priority | The type system already enforces Invariant 1; a hook would be belt-and-braces. DoD grep across `lib/**` and `functions/src/**` for `double.*amountPaise` returns 0 in PR #36, so the gap is theoretical. |
| [#28](https://github.com/avtansh-code/OneByTwo/issues/28) | Friends HTML mockup | SR3 | Open | `docs/design/05-mockups/` has 8 HTML mockups but no friends-flow mockup. Wireframes and screen specs exist; only the HTML is missing. |

### Issue closure candidates (close-with-evidence PR)

The following issues are partially or fully resolved by Sprint 2 feature
PRs and should be closed in a dedicated chore PR that adds a comment
linking the resolving commit:

- **#20** — close the CV3 sub-item with a comment citing the
  PR #36 coverage report (`functions/src/simplified-debts/function.ts`
  at 90% branch). The remaining sub-items (SC1, SC2, SC3, SC4) stay open
  under a re-scoped follow-up.
- **#21** — close the R1-R4 sub-items with comments citing PR #32
  (friendship rules tests) and PR #36 (`expenses-friendship.test.ts`).
  Re-scope the remaining sub-items (R5-R8) into the groups epic and a
  Storage-rules chore.

### Recommended sequencing (chores vs. feature pairing)

Some chores pair naturally with upcoming feature work; others are best
batched into a standalone chore PR. The orchestrator's recommendation:

| Pair with | Issues | Rationale |
|---|---|---|
| **PR #37 (`onSettlementWrite`)** | none required | Settlements work has its own scope; do not bundle chores. |
| **PR #38 (FR-EX-01 expense creation UI)** | **#25** | **MANDATORY bundle — see Critical Constraint C-1 at the top of this document.** Naming convention MUST be decided before the first expense event is logged; bundling avoids retrofitting every downstream funnel chart, alert, and test. |
| **Standalone chore PR (Sprint 2 polish — 3 SP)** | **#15, #17, #19** | Pure mechanical refactor + template edit. Low risk. Fast feedback. |
| **Standalone chore PR (telemetry sweep — 2 SP)** | **#16, #18 (S5 only)** | Both touch auth/OTP screens; one PR keeps the analytics changes coherent. |
| **Pre-FR-EX-01 design polish PR (2 SP)** | **#18 (S1, S3, S4), #28** | Spec alignment + friends mockup before the expense screens land so the design system stabilises. |
| **Standalone CF chore PR (Sprint 3 ramp — 3 SP)** | **#24** | CF PR checklist + Jest config docs make Sprint 3's groups trigger work less ambiguous. |
| **Defer to Sprint 3** | **#21 (R5-R8)** | Group rules tests pair with the groups epic; Storage size/content-type can also wait. |
| **Defer to Sprint 4+** | **#22, #27** | Dependency upgrades and the Invariant-1 hook are non-urgent; type system + boundary contracts suffice for now. |
| **Defer to Sprint 6** | **#26** | Release-only secrets and DPDP review explicitly tied to release execution. |
| **Already covered** | **#23 (PY3 partial)** | PR #36 enabled `test:integration` in CI. Remaining INV2 / RT2 sub-items deferred. |
