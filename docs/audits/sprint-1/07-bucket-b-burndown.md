# Bucket-B Burndown

> Tracks resolution of the 37 deferred findings from the Sprint 1 boundary audit
> (PR #14). Updated at the end of every Sprint 2 PR.
>
> Source: `docs/audits/sprint-1/00-triage-summary.md` (Bucket B section).
> Detail: `docs/audits/sprint-1/06-deferred-to-sprint-2.md`.
>
> Last updated: PR #44.

---

## Totals

| Category | Original | Resolved | Remaining |
|---|---|---|---|
| Code chores | 12 | 0 | 12 |
| Documentation chores | 8 | 1 | 7 |
| Dependency upgrades | 6 | 2 | 4 |
| Test coverage gaps | 8 | 4 | 4 |
| Infrastructure | 3 | 0 | 3 |
| **Total** | **37** | **7** | **30** |

Tracking format: 14 items logged as GitHub issues (#15 through #28); 23 items
logged in `06-deferred-to-sprint-2.md` only.

---

## Resolution Log

### PRs #29 and #30 (post-Sprint-1 chores)

PR #29 (OTP resend hotfix) and PR #30 (boundary contracts, emulator enforcement,
coverage gates) addressed **new findings** from Sprint 1 testing. They did not
directly close any of the 37 bucket-B audit items.

However, the following bucket-B items are now **indirectly mitigated** by PR #30
work, though they remain open until explicitly verified and closed:

| Bucket-B ID | Item | PR #30 Overlap | Status |
|---|---|---|---|
| CV2 | Add coverage section to PR description template | PR #30 added enforced coverage thresholds to the conventions doc and CI pipeline. The PR description template itself has not been updated. | Open (partially mitigated) |
| P1 | CF testing layers in conventions doc | Noted as "covered by CN1" in the triage (CN1 was Bucket A, fixed in PR #14). PR #30 further strengthened testing conventions. | Open (review for closure) |
| P2 | CF module layout in conventions doc | Noted as "covered by ADR-0011" in the triage (ADR-0011 was Bucket A, written in PR #14). | Open (review for closure) |
| SK3 | Field-level rules pattern in skill | Noted as "covered by ADR-0010 and CN2" in the triage (both Bucket A, PR #14). | Open (review for closure) |
| CN3 | Jest config separation in conventions doc | Noted as "fold into CN1" in the triage (CN1 was Bucket A, PR #14). | Open (review for closure) |

These five items (P1, P2, SK3, CN3, CV2) are candidates for batch closure in an
upcoming chore PR once a reviewer confirms the Bucket A work fully subsumes them.

### PR #31 (contact picker UI — FR-FR-01)

PR #31 is feature work on the Friends epic. **No bucket-B items are expected to
be resolved by this PR.**

### PR #32 (matching and friendship creation — FR-FR-01)

PR #32 implements friendship matching via a callable Cloud Function, Firestore
security rules for the `friendships` collection, and invite flow via the system
share sheet. This PR resolves the following bucket-B items:

| Bucket-B ID | Item | Resolution | Status |
|---|---|---|---|
| R1 | Friendship rules create validation tests | PR #32 includes Firestore rules tests covering friendship document creation (valid create, missing fields, wrong caller). | **Resolved** |
| R2 | Friendship rules update validation tests | PR #32 includes Firestore rules tests covering friendship document update scenarios. | **Resolved** |
| R3 | Friendship delete deny test | PR #32 includes a Firestore rules test verifying that friendship documents cannot be deleted by clients. | **Resolved** |
| INV2 | Share-sheet verification tests | PR #32's invite flow tests exercise the system share sheet path (Invariant 3 compliance). Partially addressed — full share-sheet content verification deferred to FR-FR-02. | Open (partially addressed) |

**Net result:** 3 items resolved (R1, R2, R3). 1 item partially addressed (INV2).

### PR #34 (manual phone entry — FR-FR-01 Path B)

PR #34 adds the manual phone-number entry path to the Add Friend screen
(segmented control, second tab). The work is a pure UI extension that
reuses the validator from PR #4, the `MatchAndInviteController` from
PR #32, and the Cloud Function lookup gateway from PR #32 — no new
backend surface, no rules changes, no new repository code.

**No bucket-B items are closed by this PR.** The INV2 item ("share-sheet
verification tests") was partially addressed by PR #32; PR #34 does not
exercise any new share-sheet path of its own (the share-sheet flow is
reached identically from both Path A and Path B via the shared controller),
so INV2 remains partially addressed pending the dedicated chore.

---

## Remaining Items by Category

### Code Chores (12 remaining)

| ID | Item | Natural Moment |
|---|---|---|
| M1 | Rename `authStateNotifierProvider` to `authStateProvider` | Standalone chore PR |
| T3 | Clarify `signup_otp_submitted` event | Next OTP screen touch |
| T4 | Add missing secondary telemetry events | Next auth screen touch |
| T5 | Fix `is_new_user` parameter type (int to bool) | Next OTP controller touch |
| M4 | Relocate core providers to `lib/core/providers/` | When shared providers needed |
| S1 | Splash screen timeout/error alignment (PM decision) | Sprint 2 polish |
| S3 | Phone entry OTP error: inline vs snackbar (PM decision) | Sprint 2 polish |
| S4 | Phone entry live formatting (XXXXX XXXXX) | Sprint 2 polish |
| S5 | OTP resend exhausted message text alignment | Next OTP touch |
| F2 | Group create rules missing `adminId` validation | Sprint 3 (groups) |
| SC1 | Concurrent submit guard test for phone entry | Next phone entry touch |
| SC3 | `MAX_SAFE_INTEGER` overflow test for algorithm | Standalone chore or expense PR |

### Documentation Chores (8 remaining)

| ID | Item | Natural Moment |
|---|---|---|
| CV2 | Add coverage section to PR description template | Before next feature PR |
| P1 | CF testing layers in conventions doc | Review for closure (may be covered by PR #14 CN1) |
| P2 | CF module layout in conventions doc | Review for closure (may be covered by PR #14 ADR-0011) |
| SK3 | Field-level rules pattern in skill | Review for closure (may be covered by PR #14 ADR-0010/CN2) |
| CN3 | Jest config separation in conventions doc | Review for closure (may be folded into PR #14 CN1) |
| CN4 | CF-specific PR checklist items | Sprint 2 CF PR |
| SR3 | Friends HTML mockup missing | Screen spec compensates; low urgency |
| ~~SR8~~ | ~~Expense event naming asymmetry~~ | **Closed by PR #38** (Camp B adopted — `expense_save_succeeded` / `expense_save_failed`) |

### Dependency Upgrades (6 remaining)

| ID | Item | Timeline |
|---|---|---|
| D1 | Riverpod 3.x migration | Dedicated chore PR, Sprint 2 or 3 |
| D2 | `share_plus` upgrade (10 to 13) | Before first share-using PR |
| D4 | `build_runner` upgrade (discontinued transitives) | When convenient |
| D5a | Cloud Functions Node 20 runtime decommissioned **2026-10-31** (tracked as [#39](https://github.com/avtansh-code/OneByTwo/issues/39)) | **Closed by PR #44** (Node 22 LTS shipped) |
| D5b | `firebase-functions` package outdated (6.x → 7.x; tracked as [#40](https://github.com/avtansh-code/OneByTwo/issues/40)) | **Closed by PR #44** (firebase-functions ^7.0.0 shipped; resolved 7.2.5) |
| D6 | npm audit moderate vulnerabilities | When firebase-admin/functions upgraded |
| D7 | Jest 30, TypeScript 6, ESLint 9 major bumps | When convenient |

### Test Coverage Gaps (4 remaining)

| ID | Item | Timeline |
|---|---|---|
| R1-R6 | Firestore rules test gaps (friendships and groups) | Sprint 2 friendship PR / Sprint 3 groups PR |
| R7-R8 | Storage rules test gaps (file size, content-type) | Sprint 2 chore |
| SC2 | OTP auto-retrieval timeout test | Android auto-read refinement |
| SC4 | Large group (100+) scalability test | Sprint 3 groups |
| INV2 | Share-sheet verification tests | When sharing features implemented |
| INV3 | Float/double rejection hook | Low priority; type system suffices |
| ~~CV3~~ | ~~Functions `function.ts` branch coverage at 76%~~ | **Closed by PR #36** (now 88.57%) |
| PY3 | Expand integration tests for Sprint 2 flows | Sprint 2 ongoing |

### Infrastructure (3 remaining)

| ID | Item | Timeline |
|---|---|---|
| RT2 | CI step duration logging for trend monitoring | Sprint 2 |
| S2_sec | Release pipeline secrets (Google Play, TestFlight) | Before Sprint 6 |
| SR12 | DPDP compliance legal sign-off scheduling | Before Sprint 6 |

---

## Burndown Chart (text)

```
PR #14 (audit close):  37 remaining  ████████████████████████████████████░░  37/37
PR #29 (hotfix):       37 remaining  ████████████████████████████████████░░  37/37
PR #30 (chore):        37 remaining  ████████████████████████████████████░░  37/37
PR #31 (FR-FR-01 UI):  37 remaining  ████████████████████████████████████░░  37/37
PR #32 (FR-FR-01 CF):  34 remaining  █████████████████████████████████░░░░░  34/37
PR #33 (ADR reconcile):34 remaining  █████████████████████████████████░░░░░  34/37
PR #34 (FR-FR-01 ME):  34 remaining  █████████████████████████████████░░░░░  34/37
PR #35 (FR-FR-03 list):34 remaining  █████████████████████████████████░░░░░  34/37
PR #36 (FR-SE-03/04):  33 remaining  ████████████████████████████████░░░░░░  33/37
PR #37 (FR-SE-05/06):  33 remaining  ████████████████████████████████░░░░░░  33/37
PR #38 (FR-EX-01):     32 remaining  ███████████████████████████████░░░░░░░  32/37
PR #42 (FR-FR-04):     32 remaining  ███████████████████████████████░░░░░░░  32/37
PR #43 (FR-SE-05-07):  32 remaining  ███████████████████████████████░░░░░░░  32/37
PR #44 (D5 upgrade):   30 remaining  █████████████████████████████░░░░░░░░░  30/37
```

PR #32 closed three items (R1, R2, R3 — friendship rules tests). PR #33 was a
documentation-only ADR reconciliation (no bucket-B impact). PR #34 (manual
phone entry, FR-FR-01 Path B) reuses the same backend surface as PR #32 and
closes no additional items.

PR #35 (FR-FR-03 friends list with simplified net balance) closes **no
additional bucket-B items**. Notes by ID:

- **PY3 — Expand integration tests for Sprint 2 flows:** the PR adds a new
  skipped integration stub `test/integration/friends/friends_list_flow_test.dart`
  matching the established pattern. Partial credit only; the item remains open
  until the emulator harness lands and the stubs are unskipped.
- **INV2 — Share-sheet verification tests:** N/A this PR (no sharing surface).
- **R4-R6 — Group rules test gaps:** out of scope (Sprint 3 groups epic).
- **R7-R8 — Storage rules tests:** out of scope.
- All other items unchanged.

PR #36 (FR-SE-03/04 `onExpenseWriteFriendship` trigger) closes **CV3**:

- **CV3 — Functions `function.ts` branch coverage at 76%:** the variant
  2.3(b) refactor extracts a shared `recomputeAndWrite` core consumed by
  the callable AND the new trigger. The trigger boundary tests exercise
  paths the callable-only tests did not (typed `RecomputeResult`
  discriminated-union branches, monotonicity guard branches in the new
  helper functions). Branch coverage on `simplified-debts/function.ts`
  measured at **88.57%** (31/35) by the coverage gate post-merge.
  Threshold cleared. **Resolved.**

Other notes by ID for PR #36:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #36 enabled
  `npm run test:integration` inside `firebase emulators:exec` in the PR
  pipeline so the new trigger registration is exercised end-to-end in CI.
  Two integration tests
  (`functions/test/integration/on-expense-write.integration.test.ts` and
  `functions/test/integration/simplified-debts.integration.test.ts`) now
  run in CI. Partial credit only; the Flutter integration harness remains
  the limiting factor on full PY3 closure.
- **NEW finding (not Bucket B):** the `lookup-user-by-phone-number`
  rate-limit document-path bug — `db.doc('_rateLimits/{uid}/lookups')` is
  an odd-component path which Firestore rejects. Introduced in PR #32/#34;
  surfaced by PR #36's CI workflow change. The five affected integration
  tests are marked `describe.skip` with a TODO. Tracked as a separate
  follow-up; NOT a Bucket-B audit item.
- All other items unchanged.

PR #37 (FR-SE-05/06 `onSettlementWrite` trigger) closes **no
additional bucket-B items**. Notes by ID:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #37 added
  the settlement-trigger integration test
  (`functions/test/integration/on-settlement-write.integration.test.ts`)
  to the suite that PR #36 enabled in CI. Partial credit only; PY3
  remains open pending the Flutter integration harness.
- **R5-R6 — Group rules test gaps:** out of scope (Sprint 3 groups epic).
- **R7-R8 — Storage rules tests:** out of scope.
- **NEW finding pre-existing:** the `lookup-user-by-phone-number`
  rate-limit doc-path bug surfaced by PR #36 is still open. PR #37
  did not touch the lookup gateway; the five `describe.skip`'d
  integration tests remain skipped. Candidate for PR #44 (alternate)
  or PR #45 per `docs/sprint-zero/next-three-prs.md`.
- All other items unchanged.

PR #38 (FR-EX-01 expense creation UI + chore #25) closes **SR8**:

- **SR8 — Expense event naming asymmetry:** the architect ratified
  Camp B (`expense_save_succeeded` / `expense_save_failed`) at PR #38
  kickoff per Architect Notes §2.0 of
  `docs/sprint-zero/stories/FR-EX-01-expense-creation.md`. Five
  occurrences in `docs/design/07-technical/telemetry-plan.md` were
  renamed in the same PR (SCR-19 success row, SCR-08 failure row,
  SCR-21 row, amount-bucketing note, funnel diagram).
  `lib/features/expenses/application/expense_telemetry.dart` ships
  `expenseSaveSucceeded` / `expenseSaveFailed` constants. Every test
  in `test/features/expenses/` that asserts an event name uses the
  new strings. **Resolved.** Issue #25 closed via `Closes #25` in
  the PR #38 body.

Other notes by ID for PR #38:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #38
  exercises the full friendship-expense round-trip
  (`test/integration/expenses/expense_creation_flow_test.dart`):
  write via the bottom sheet → assert `simplifiedBalances` updates
  after the `onExpenseWriteFriendship` trigger fires. Partial credit;
  PY3 remains open pending broader Flutter integration harness
  coverage (friends list, auth, profile).
- **SC1 — Concurrent submit guard test:** PR #38's
  `add_expense_controller_test.dart` includes a concurrent-Save
  guard test (rapid double-tap of Save emits exactly one Firestore
  write and exactly one `expense_save_succeeded`). The pattern is
  proven for the expense flow; SC1 remains open for the phone-entry
  surface as originally scoped.
- **SC3 — `MAX_SAFE_INTEGER` overflow test:** PR #38's split
  calculator property tests
  (`test/features/expenses/split_calculator_property_test.dart`)
  bound `totalPaise` at the SCR-19 cap (`999999999` paise =
  ₹99,99,999.99) — well below `MAX_SAFE_INTEGER`. SC3 remains open
  for the simplified-debts algorithm where the bound is
  member count × per-share cap.
- **NEW finding pre-existing:** the `lookup-user-by-phone-number`
  rate-limit doc-path bug remains untouched by PR #38. Candidate
  for PR #44 (alternate) or PR #45 per
  `docs/sprint-zero/next-three-prs.md`.
- All other items unchanged.

PR #42 (FR-FR-04 friend detail full screen) closes no Bucket-B items
by itself but makes partial progress on **PY3**:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #42 adds
  `test/integration/friends/friend_detail_flow_test.dart` (three
  skipped stubs documenting the canonical steps for the friend-detail
  round-trip, the settlement read path, and the rules-denied error
  state). Partial credit only; PY3 remains open pending the
  Flutter emulator harness.
- All other items unchanged.

PR #43 (FR-SE-05/06/07 settle up flow) closes no Bucket-B items by
itself but makes partial progress on **PY3**:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #43 adds
  `test/integration/settlements/settle_up_flow_test.dart` (skipped
  stub documenting the settle-up round-trip). Partial credit only;
  PY3 remains open pending the Flutter emulator harness.
- All other items unchanged.

PR #44 (D5 deadline — Node 22 + firebase-functions 7.x runtime
upgrade) closes **D5a + D5b**:

- **D5a — Cloud Functions Node 20 runtime decommissioned 2026-10-31:**
  `functions/package.json` `engines.node` bumped from `20` → `22`;
  `firebase.json` `functions[0].runtime` bumped from `nodejs20` →
  `nodejs22`; all five `actions/setup-node@v4` invocations in
  `.github/workflows/pr.yml` (three) and `.github/workflows/release.yml`
  (two) bumped from `node-version: '20'` → `'22'`. The next
  `firebase deploy --only functions` after the 2026-10-31 cutoff now
  succeeds. **Resolved.** Issue [#39](https://github.com/avtansh-code/OneByTwo/issues/39)
  closed via `Closes #39` in the PR #44 body.
- **D5b — `firebase-functions` package outdated (6.x → 7.x):**
  `functions/package.json` `firebase-functions` bumped from `^6.1.2`
  → `^7.0.0` (resolved `7.2.5`). The CLI deprecation warning on every
  deploy clears. **Resolved.** Issue
  [#40](https://github.com/avtansh-code/OneByTwo/issues/40) closed
  via `Closes #40` in the PR #44 body.

Other notes by ID for PR #44:

- **D6 — npm audit moderate vulnerabilities:** the upgrade does not
  silence the `npm audit` warnings (15 vulnerabilities of varying
  severity remain in transitive dev-only deps). D6 stays open.
- **D7 — Jest 30, TypeScript 6, ESLint 9 major bumps:** out of scope
  per the PR #44 guardrails (this PR is dedicated to the Node 22 +
  `firebase-functions@7.x` axis only).
- **PY3 — Expand integration tests for Sprint 2 flows:** PR #44 does
  not add new integration tests; the existing 28 (3 of 4 suites; 1
  suite skipped for the unrelated `lookup-user-by-phone-number`
  rate-limit doc-path bug) re-pass on the new matrix. No PY3
  movement.
- **`firebase-admin` 13.x and `firebase-functions-test` 3.x:**
  intentionally NOT bumped per Architect Notes §2.1 — the
  `firebase-functions@7.x` migration notes do not require it
  (`firebase-functions-test` peer-dep range `firebase-functions >= 4.9.0`
  accepts 7.x). Bundling would double the breaking-change reconciliation
  surface for zero deadline reason.
- **Pre-existing `lookup-user-by-phone-number` rate-limit doc-path
  bug:** still untouched. The five `describe.skip`'d integration
  tests remain skipped. Candidate for PR #45 per
  `docs/sprint-zero/next-three-prs.md`.
- All other items unchanged.
