# Sprint 2 Plan

> Last updated: PR #51 (FR-EX-07 — activity feed write-side, friendship expenses) — 15th merged PR.

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

**Status: RESOLVED (PR #38, merged 2026-06-06).**

- **Decision:** Camp B — `expense_save_succeeded` / `expense_save_failed`.
  PM had recommended Camp B on consistency grounds with the SCR-21
  edit / delete cluster already in `telemetry-plan.md` §1.6; the
  architect ratified the recommendation at PR #38 kickoff.
- **Rationale citation:** `docs/sprint-zero/stories/FR-EX-01-expense-creation.md`
  §2.0 (Architect Notes — one-paragraph rationale and rollout plan).
- **Files updated in PR #38:**
  - `docs/design/07-technical/telemetry-plan.md` — 5 occurrences
    renamed (the SCR-19 success row, the SCR-08 failure row, the
    SCR-21 row, the amount-bucketing note, and the funnel diagram).
  - `lib/features/expenses/application/expense_telemetry.dart` —
    `expenseSaveSucceeded` / `expenseSaveFailed` constants.
  - All expense test files under `test/features/expenses/` that
    assert event names.
- **Issue closure:** [#25](https://github.com/avtansh-code/OneByTwo/issues/25)
  closed by `Closes #25` in the PR #38 body.
- **Downstream effect:** SR8 is now CLOSED in
  `docs/audits/sprint-1/07-bucket-b-burndown.md`; the Documentation
  chores bucket drops from 8 remaining to 7.

---

## PR Tracking

| PR | Story | Title | SP | Status |
|---|---|---|---|---|
| #31 | FR-FR-01 (UI) | Contact picker UI for add-friend flow | 3 | Merged |
| #32 | FR-FR-01 (Matching) | User lookup and friendship creation | 3 | Merged |
| #34 | FR-FR-01 (Manual Entry) | Manual phone-number friend-add | 2 | Merged |
| #35 | FR-FR-03 | Friends list with simplified net balance | 3 | Merged |
| #36 | FR-SE-03/04 | `onExpenseWriteFriendship` Firestore trigger | 3 | Merged |
| #37 | FR-SE-05/06 | `onSettlementWrite` Firestore trigger + settlements rules + algorithm extension | 5 | Merged |
| #38 | FR-EX-01 + chore #25 | Expense creation UI (friendship) + adopt `expense_save_*` event names | 5 | Merged |
| #41 | chore | D5 deadline backlog cross-refs | 0 | Merged |
| #42 | FR-FR-04 | Friend Detail full screen (per-friend transaction history) | 5 | Merged |
| #43 | FR-SE-05/06/07 | Settle Up flow (record settlement + real-time round-trip + Friend Detail CTA card) | 5 | Merged |
| #44 | CHORE-D5 | D5 runtime upgrade — Node 22 + firebase-functions 7.x (closes #39 #40) | 3 | Merged |
| #45 | CHORE-PR45 | Lookup rate-limit doc-path fix + post-PR-#38 cleanup (3 S4 items) | 3 | Merged |
| #46 | FR-EX-06 | Edit / delete expense (friendship) — bottom-sheet edit-mode + Expense Detail screen + soft-delete with confirmation | 5 | Merged |
| #48 | FR-EX-05 | Receipt attachment (friendship) — Step 3 (SCR-21) + ReceiptStorageService + storage.rules friendship + group receipts predicates + Expense Detail thumbnail | 5 | Merged |
| #51 | FR-EX-07 | Activity feed write-side (friendship) — activity-writer + payload-builder + activity-validator + activity/{userId}/items rules + trigger emission + 12 new rules tests + 41 new unit tests + 3 integration round-trips | 5 | Merged |

---

## Velocity

| PR | SP | Status |
|---|---|---|
| #31 | 3 | Merged |
| #32 | 3 | Merged |
| #34 | 2 | Merged |
| #35 | 3 | Merged |
| #36 | 3 | Merged |
| #37 | 5 | Merged |
| #38 | 5 | Merged |
| #41 | 0 | Merged (docs-only) |
| #42 | 5 | Merged |
| #43 | 5 | Merged |
| #44 | 3 | Merged |
| #45 | 3 | Merged (chore — Stream A + Stream B) |
| #46 | 5 | Merged |
| #48 | 5 | Merged |
| #51 | 5 | Merged |
| **Total** | **55** | **15 PRs so far** |

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
- FR-FR-04 (per-friend transaction history) shipped in PR #42 — the
  first client surface to read the `friendships/{fid}/expenses/{eid}`
  subcollection PR #38 wrote to, and the first surface to read the
  top-level `settlements/{settlementId}` collection PR #37 shipped
  rules + a trigger for. It introduced
  `lib/features/settlements/` (the read-side scaffolding for the
  settlements feature folder), extended `ExpenseRepository` with
  `watchExpensesByFriendship`, added a combined `friendDetailProvider`
  that joins three real-time streams (friendship doc + expenses +
  settlements) into a `FriendDetailState` sealed union, and replaced
  the PR #35 placeholder screen with `FriendDetailScreen`. The
  settlements composite index was extended from
  `(contextType, contextId)` to `(contextType, contextId, date)` to
  unblock the canonical query — DevOps deploys the updated
  `firestore.indexes.json` before merge.

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

## Post-Merge Cleanup Backlog

Small follow-up items surfaced during a feature PR's QA sign-off that
were judged too minor to block merge. Listed here so they are not lost
between sprints. Severity per the project bug grading scale: **S4 =
nice-to-have, no functional impact**.

### From PR #38 (FR-EX-01 expense creation UI) — **CLOSED BY PR #45**

QA sign-off was APPROVED WITH CAVEATS — see the "QA Sign-Off" section in
`docs/sprint-zero/stories/FR-EX-01-expense-creation.md`. Three S4 items
were deferred to a follow-up cleanup PR and shipped as Stream B of
**PR #45** (chore — bundled with the Stream A lookup-user rate-limit
doc-path fix; squash commit landed 2026-06-06).

1. **Stale `expense_added` / `expense_add_failed` references in 3 design docs**
   — **RESOLVED in PR #45.** Renamed to `expense_save_succeeded` /
   `expense_save_failed` in the six legacy positions:
   - `docs/design/03-architecture/non-functional-design.md:399`
   - `docs/design/06-screen-specs/06-08-home-and-search.md:152, 517, 519`
   - `docs/design/06-screen-specs/19-22-expenses.md:360, 386`

   The `type: 'expense_added'` notification-type schema discriminator
   (per SRS §7.2; `firestore-schema.md:202`) was deliberately left
   untouched — see PR #45 AC-B1 + AC-X4 negative guard.

2. **Splitter test descriptions still label `99999999` as "the maximum
   permitted total"** — **RESOLVED in PR #45.** Updated the cap labels
   and the dependent share assertions in both files to use the real
   cap `999999999` (= ₹99,99,999.99 per SCR-19). See PR #45 chore-story
   Architect Notes §2.7 for the coordinated share-assertion
   reconciliation rationale.

3. **Missing `// TODO(SCR-08)` comment in `friends_list_screen.dart`**
   — **RESOLVED in PR #45.** Added the comment block at the top of
   the file (immediately after the import block), citing
   `FriendDetailScreen` (the real screen since PR #42) rather than the
   pre-PR-#42 `FriendDetailPlaceholderScreen` wording.

### From PR #38 deploy (Firebase CLI warnings, 2026-06-06) — **CLOSED BY PR #44**

Two **deadline-bound** items surfaced by the post-PR #38 functions deploy.
Filed as standalone GitHub issues (not S4 — these are S2 because of the
hard 2026-10-31 deploy-blocker) and tracked separately from the S4 set
above. **Both shipped together in PR #44 (D5 runtime upgrade).**

4. **Cloud Functions runtime Node 20 decommissioned 2026-10-31** —
   tracked as [#39](https://github.com/avtansh-code/OneByTwo/issues/39).
   After this date, `firebase deploy --only functions` would have been
   rejected for the Node 20 runtime. **Closed by PR #44** — Node 22 LTS
   shipped: `functions/package.json` `engines.node = "22"`,
   `firebase.json` `functions[0].runtime = "nodejs22"`, and all five
   `actions/setup-node@v4` invocations across `.github/workflows/pr.yml`
   (three) and `.github/workflows/release.yml` (two) pinned to `'22'`.

5. **`firebase-functions` package outdated (6.x → 7.x)** — tracked as
   [#40](https://github.com/avtansh-code/OneByTwo/issues/40). CLI warned
   on every deploy. **Closed by PR #44** — `firebase-functions` upgraded
   from `^6.1.2` to `^7.0.0` (resolved `7.2.5`); the CLI deprecation
   warning on every deploy clears.

**Outcome:** zero source-code reconciliations required (the v6 → v7
breaking changes do not apply to our v2-only callsites — see
`docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect Notes
§2.4 and §2.7 for the applicability matrix). The five-layer test
pyramid stays green on the new matrix:

| Layer | Suite count | Test count |
|---|---|---|
| 1 + 2 + 3 (algorithm unit + property + boundary) | 9 / 9 | 100 / 100 pass |
| 4 (Firestore + Storage rules) | 7 / 7 | 149 / 149 pass |
| 5 (full-emulator integration) | 3 / 4 + 1 skipped suite | 28 pass / 5 skipped |

Coverage on `functions/src/simplified-debts/function.ts` stays at
89.13% branch (PR #36 baseline 88.57%; unchanged within margin).

Both items close umbrella item D5 in
`docs/audits/sprint-1/07-bucket-b-burndown.md`. Issue #22 (umbrella
dependency-upgrade backlog) retains D1, D2, D4, D6, D7.

---

## Pattern Establishment (PR #44)

PR #44 establishes the **dependency-upgrade chore pattern** that
future deadline-bound deploy-toolchain bumps (Node 24, future
`firebase-functions@8.x`, etc.) will inherit:

- **Atomic runtime + SDK bundling** — Node 22 + `firebase-functions@7.x`
  ship in the same PR so the rollback story is a single `git revert`.
  Splitting would double the breaking-change reconciliation surface
  AND require two reverts to recover. The "split into PR #44a + PR
  #44b" escape hatch in Architect Notes §2.1 was not exercised; the
  default single-PR approach worked.
- **Pre-implementation breaking-change applicability matrix** — the
  architect populates §2.4 of the chore story with a row-per-breaking-
  change table mapping each v6 → v7 (or analogous) change to our
  codebase. Validated post-implementation in §2.7. For PR #44 the
  prediction was "zero reconciliations required"; the test pyramid
  confirmed it.
- **Five-layer test pyramid as the upgrade gate** — every layer
  (algorithm unit, property, boundary, rules, integration) must stay
  green on the new matrix BEFORE merge. The CI pipeline already
  enforces this; the chore-story Architect Notes §2.6 codifies the
  execution order.
- **CI runner pin scheme** — the five `actions/setup-node@v4`
  invocations across `pr.yml` (three) and `release.yml` (two) move
  in lockstep with the `functions/package.json` `engines.node` and
  `firebase.json` `functions[0].runtime` pins. Future runtime bumps
  follow the same pattern.
- **Forward-compatibility note in §2.9** — the chore story documents
  the next foreseeable runtime forcing event (Node 22 deprecation
  2027-04-30 / decommission 2027-10-31), so the next D-row update
  can be slotted ~6 months ahead of the cutoff.

The architect notes appended to
`docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` ratify the
PR #44 design decisions.

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
| [#22](https://github.com/avtansh-code/OneByTwo/issues/22) | Dependency upgrades — Riverpod 3.x, share_plus, firebase-functions 7.x | D1, D2, D4, D5, D6, D7 | **Open — D5 now URGENT** (split into [#39](https://github.com/avtansh-code/OneByTwo/issues/39) Node 20 decommissioned **2026-10-31** and [#40](https://github.com/avtansh-code/OneByTwo/issues/40) firebase-functions 6→7) | Sprint 1 audit deferral. D5 was reinforced by the post-PR #38 deploy warnings (2026-06-06) and split into two deadline-aware sub-issues; #39 has ~5 months runway before the next `firebase deploy --only functions` is rejected. D1, D2, D4, D6, D7 remain tracked on the umbrella. |
| [#23](https://github.com/avtansh-code/OneByTwo/issues/23) | Expand integration tests for Sprint 2 flows | PY3, RT2, INV2 | Partially addressed | **PR #36 enabled `npm run test:integration` inside `firebase emulators:exec`** — every future trigger PR exercises its actual registration in CI (helps PY3). Friend-add stub `test/integration/friends/friends_list_flow_test.dart` shipped in PR #35 (still skipped). RT2 (CI step duration logging) not yet added. INV2 (share-sheet verification) — system share sheet is the only path, but no test asserts the package-import boundary. Expense-create flow integration tests blocked on FR-EX-01. |
| [#24](https://github.com/avtansh-code/OneByTwo/issues/24) | Conventions doc — CF PR checklist and Jest config separation | CN3, CN4 | Open | `feature-pr-conventions.md` does not yet enumerate the Jest config split (`jest.config.js` vs `jest.rules.config.js` vs `jest.integration.config.js`) nor CF-specific PR checklist items (region pinning, error-code mapping, transaction usage, idempotency). |
| [#25](https://github.com/avtansh-code/OneByTwo/issues/25) | Expense event naming convention decision | SR8 | **Closed by PR #38** (Camp B adopted — see Critical Constraint C-1 above, marked RESOLVED) | Decision: `expense_save_succeeded` / `expense_save_failed` per Architect Notes §2.0 of FR-EX-01. Five telemetry-plan occurrences renamed; `lib/features/expenses/application/expense_telemetry.dart` ships the matching constants. `Closes #25` recorded in PR #38 body. |
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
| **Post-PR #38 cleanup PR (1 SP, candidate for PR #45)** | none required | The three S4 items from the PR #38 QA sign-off (stale event names in 3 design docs; splitter test cap labels; missing `// TODO(SCR-08)` comment). Pure docs + test-description fixes; ~10 lines diff total. See "Post-Merge Cleanup Backlog" section above and `docs/sprint-zero/next-three-prs.md` PR #45 slot for full detail. |
| **Standalone chore PR (Sprint 2 polish — 3 SP)** | **#15, #17, #19** | Pure mechanical refactor + template edit. Low risk. Fast feedback. |
| **Standalone chore PR (telemetry sweep — 2 SP)** | **#16, #18 (S5 only)** | Both touch auth/OTP screens; one PR keeps the analytics changes coherent. |
| **Pre-FR-EX-01 design polish PR (2 SP)** | **#18 (S1, S3, S4), #28** | Spec alignment + friends mockup before the expense screens land so the design system stabilises. |
| **Standalone CF chore PR (Sprint 3 ramp — 3 SP)** | **#24** | CF PR checklist + Jest config docs make Sprint 3's groups trigger work less ambiguous. |
| **Defer to Sprint 3** | **#21 (R5-R8)** | Group rules tests pair with the groups epic; Storage size/content-type can also wait. |
| **Defer to Sprint 4+** | **#22 (D1/D2/D4/D6/D7 remaining), #27** | Dependency upgrades and the Invariant-1 hook are non-urgent; type system + boundary contracts suffice for now. **D5 has been split out into #39 (Node 20 decommissioned 2026-10-31) and #40 (firebase-functions 6→7) and is URGENT** — slot the pair into PR #44 (default plan per `docs/sprint-zero/next-three-prs.md`) so the Cloud Functions deploy path stays open past the cutoff. |
| **Defer to Sprint 6** | **#26** | Release-only secrets and DPDP review explicitly tied to release execution. |
| **Already covered** | **#23 (PY3 partial)** | PR #36 enabled `test:integration` in CI. Remaining INV2 / RT2 sub-items deferred. |
