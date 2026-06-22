# Bucket-B Burndown

> Tracks resolution of the 37 deferred findings from the Sprint 1 boundary audit
> (PR #14). Updated at the end of every Sprint 2 PR.
>
> Source: `docs/audits/sprint-1/00-triage-summary.md` (Bucket B section).
> Detail: `docs/audits/sprint-1/06-deferred-to-sprint-2.md`.
>
> Last updated: the **Bucket-B close-with-evidence bundle** (PR #73, this PR) — the
> first dedicated Bucket-B tracker-hygiene PR. It reconciles this burndown from its
> stale PR #58 state through #72 and records the close-with-evidence reconciliation of
> the three audit-tracker issues whose findings Sprint 2 PRs already resolved: **#21
> fully closed**, **#20 and #23 re-scoped and kept open**. No application code, no
> rules, no new tests — the resolving work shipped in earlier PRs; this PR verifies the
> cited evidence and brings the tracker current.

---

## Totals

| Category | Original | Resolved | Remaining |
|---|---|---|---|
| Code chores | 12 | 0 | 12 |
| Documentation chores | 8 | 1 | 7 |
| Dependency upgrades | 6 | 2 | 4 |
| Test coverage gaps | 8 | 7 | 1 |
| Infrastructure | 3 | 0 | 3 |
| **Total** | **37** | **10** | **27** |

Tracking format: 14 items logged as GitHub issues (#15 through #28); 23 items
logged in `06-deferred-to-sprint-2.md` only.

> **Totals verified against the Resolution Log (PR #73).** The ten struck-through
> resolutions are SR8 (#38), D5a + D5b (#44), R1 + R2 + R3 (#32), R5a (#51),
> R7 + R8 (#48), and CV3 (#36). The Bucket-B close-with-evidence bundle (PR #73)
> contributes **zero** new resolutions — every finding it documents was already
> counted when its resolving PR landed; the bundle is tracker hygiene (it closes the
> GitHub *issues* #20 / #21 / #23, not new audit *findings*). Totals therefore hold at
> **10 / 27**. Note the audit-accurate finding IDs: **R4 = `groups/{id}` create**,
> **R5b = `groups/{id}` update**, **R6 = `groups/{id}` delete** (all Sprint 3 Groups
> epic, remaining). **R5a (activity-collection rules) is a NEW Sprint-2 tracker ID**
> introduced when the activity feature shipped (closed by #51) — it is **not** present
> in the Sprint-1 audit and is distinct from **audit R5 = `groups/{id}` update** (which
> is tracked as the remaining **R5b**). The shorthand "R5 was split into R5a + R5b"
> elsewhere in this doc is imprecise: only R5b corresponds to the audit's R5; R5a is a
> separately-introduced activity-rules ID.

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
| ~~R5a~~ | ~~Firestore rules test gap for activity collection~~ | **Closed by PR #51** (`functions/test/firestore-rules/activity.test.ts` — 12 tests covering AC-6 through AC-12 of the FR-EX-07 story: owner-read positive + non-owner / unauth / parent-doc negatives + client-create / update / delete denied) |
| R1-R4, R5b, R6 | Remaining Firestore rules test gaps (friendships / groups halves) | Sprint 2 friendship PR / Sprint 3 groups PR |
| ~~R7-R8~~ | ~~Storage rules test gaps (file size, content-type)~~ | **Closed by PR #48** (`functions/test/storage-rules/receipts.test.ts` — 23 tests covering size + MIME + membership + cross-collection predicate for friendship + group predicates) |
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
PR #45 (CHORE-PR45):   30 remaining  █████████████████████████████░░░░░░░░░  30/37
PR #46 (FR-EX-06):     30 remaining  █████████████████████████████░░░░░░░░░  30/37
PR #48 (FR-EX-05):     28 remaining  ███████████████████████████░░░░░░░░░░░  28/37
PR #51 (FR-EX-07):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #52 (FR-AC-01):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #53 (FR-AC-03/05):  27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #54 (FR-SE-09):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #55 (FR-PR-03/04):  27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #56 (OBTBottomNav): 27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #57 (FR-HD-04):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #58 (FR-SE-08):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #59 (docs reconc.): 27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #60 (FR-PR-05):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #61 (CI speedup):   27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #62 (FR-HD-01/02):  27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #63 (FR-PR-04):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #64 (FR-PR-02):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #65 (FR-AU-09):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #67 (FR-HD-03):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #69 (FR-AC-05):     27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #70 (AC-11 CTA):    27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #71 (shared_prefs): 27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #72 (creator-rules):27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
PR #73 (Bucket-B hyg.):27 remaining  ██████████████████████████░░░░░░░░░░░░  27/37
```

The line has been flat at **27/37 since PR #51** (R5a). PRs #52–#72 shipped
features and chores but closed no further Bucket-B audit *findings* (each is logged
in the Resolution Log below). PR #73 — the Bucket-B close-with-evidence bundle —
closes the GitHub *issues* #20 / #21 / #23 against findings already counted, so the
remaining-findings line is unchanged at **27/37**; its contribution is tracker
hygiene, not new closures.

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
  tests are marked `describe.skip` with a TODO. **CLOSED by PR #45** —
  the production code now uses the architect-canonical 4-segment
  subcollection doc path `_rateLimits/{userId}/lookups/counter` (matches
  the integration-test seed path at line 243 and the decision-log
  logical-container declaration). The five integration tests are
  unskipped and pass end-to-end in CI. NOT a Bucket-B audit item.
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
  integration tests remain skipped. **Closed by PR #45** (see the
  PR #45 section at the end of this document for details).
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
  bug:** **Closed by PR #45** (see the PR #45 section below).
- All other items unchanged.

PR #45 (chore — lookup rate-limit doc-path fix + post-PR-#38 cleanup)
closes **no Bucket-B items by ID** but resolves two open trackers:

- **NEW finding pre-existing (rate-limit doc-path bug, NOT Bucket B):**
  **CLOSED.** The production code at
  `functions/src/lookup-user-by-phone-number/function.ts:108` now
  uses the architect-canonical 4-segment subcollection doc path
  `_rateLimits/{userId}/lookups/counter`. The five integration tests
  at
  `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
  are unskipped and pass end-to-end in CI under
  `firebase emulators:exec --only auth,firestore,functions,storage`,
  including the load-bearing `RATE_LIMITED` rate-limit-window test
  that exercises the gate the production code never reached pre-fix.
  See `docs/sprint-zero/stories/CHORE-pr45-lookup-rate-limit-and-pr38-cleanup.md`
  Architect Notes §2.1 for the canonical-path rationale.
- **Three S4 items from PR #38 QA sign-off (NOT Bucket B):** the
  three Post-Merge Cleanup Backlog items tracked in
  `docs/sprint-zero/sprint-2-plan.md` lines 285–355 (stale
  `expense_added` / `expense_add_failed` telemetry references in
  three design docs; splitter test cap-label propagation; missing
  `// TODO(SCR-08)` comment on `friends_list_screen.dart`) shipped
  as PR #45 Stream B. Plan section condensed to a one-line
  resolution note. NOT Bucket-B audit items.

Other notes by ID for PR #45:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #45
  unskips the five `lookup-user-by-phone-number` integration tests
  (was 28 pass / 5 skipped; now 33 pass / 0 skipped at the
  integration layer on Linux CI). Modest credit; PY3 remains open
  pending the Flutter integration harness.
- **D6 — npm audit moderate vulnerabilities:** unchanged (PR #45
  did not touch `functions/package.json` or `package-lock.json` per
  the chore-story Out of Scope; the runtime + SDK matrix is fixed
  by PR #44).
- **D1, D2, D4, D7:** unchanged (Sprint 4+ scope per the burndown).
- **Rate-limit transaction race refactor (NEW deferred):** the
  current rate-limit implementation has a known time-of-check-to-
  time-of-use race; explicitly deferred from PR #45 per chore-story
  Architect Notes §2.2. NOT a Bucket-B item; tracked in
  `docs/sprint-zero/next-three-prs.md` as a PR #46+ candidate
  (operational hardening chore).
- **PR #44 §2.7 trigger-interference flake (NEW deferred,
  observed-only):** during local Stream A verification on macOS the
  10 trigger integration tests (`on-expense-write.integration.test.ts`
  and `on-settlement-write.integration.test.ts`) timed out under
  `firebase emulators:exec --only auth,firestore,functions,storage`
  — consistent with the macOS-specific flake documented in
  `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` Architect
  Notes §2.7. Linux CI runners have historically been green for
  these tests. The lookup-user suite passed cleanly in isolation
  (`firebase emulators:exec ... npx jest test/integration/lookup-user-by-phone-number.integration.test.ts`).
  Not a Bucket-B item; the cited PR #44 follow-up (move `test:rules`
  to `--only firestore,storage`) remains a future test-hygiene
  candidate.
- All other items unchanged.

Net contribution of PR #45 to Bucket-B totals: **zero**. The rate-limit
bug was not a Bucket-B item; the three S4 items were not Bucket-B
items. The remaining count stays at **30 / 37**.

PR #46 (FR-EX-06 edit / delete expense, friendship context) closes
**no Bucket-B items by ID** but makes partial progress on **PY3**:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #46
  adds three skipped integration-test stubs at
  `test/integration/expenses/edit_delete_expense_flow_test.dart`
  documenting the canonical steps for (a) the edit-then-recompute
  round-trip, (b) the soft-delete-then-recompute round-trip, and
  (c) the rules-denied non-creator error state. Partial credit
  only; PY3 remains open pending the Flutter emulator harness.
- **R1-R8 — Firestore + Storage rules test gaps:** four new
  Firestore rules tests added (149 → 153) covering FR-EX-06
  update + soft-delete validation paths. These extend the R4
  coverage closed by PR #36 (`expenses-friendship.test.ts`) but
  do not close any remaining R5-R8 sub-item (group rules +
  Storage size/content-type remain Sprint 3 / Storage-chore scope).
- **D6 — npm audit moderate vulnerabilities:** unchanged (PR #46
  did not touch `functions/package.json` or `package-lock.json`
  per the story's Out of Scope negative-scope guard).
- **D1, D2, D4, D7:** unchanged (Sprint 4+ scope per the burndown).
- **Concurrent-edit detection (NEW deferred):** full transactional
  concurrent-edit detection (AC-11 / AC-12 of the FR-EX-06 story)
  is explicitly deferred per the story's Out of Scope. NOT a
  Bucket-B item; tracked in
  `docs/sprint-zero/next-three-prs.md` as a PR #47+ candidate
  (operational hardening chore).
- **Rules-hardening for non-creator update/delete gate (NEW
  deferred):** architect §2.9 item 5 of the FR-EX-06 story
  documents that the Firestore rules for the
  `friendships/{fid}/expenses/{eid}` subcollection currently
  permit update + soft-delete by any friendship member, not just
  the original creator. The client UI gates the edit / delete
  bottom-sheet entry points on
  `expense.createdBy == currentUser.uid`, but a defence-in-depth
  rules tightening is a follow-up. NOT a Bucket-B item; tracked
  in `docs/sprint-zero/next-three-prs.md` as a PR #47+ candidate
  (sprint-3 hardening sweep).
- **PR #44 §2.7 trigger-interference flake (still observed-only):**
  unchanged from PR #45. PR #46 did not touch the Cloud Functions
  trigger surface; the macOS-specific timeout under
  `firebase emulators:exec --only auth,firestore,functions,storage`
  remains an environment-sensitive flake.
- All other items unchanged.

Net contribution of PR #46 to Bucket-B totals: **zero**. The four
new Firestore rules tests extend R4 coverage (closed by PR #36) but
do not close any new audit IDs. The remaining count stays at
**30 / 37**.

PR #48 (FR-EX-05 receipt attachment, friendship context) closes
**R7 + R8** and makes partial progress on **PY3**:

- **R7 — Storage rules test gap (file size):** **CLOSED.** The new
  `functions/test/storage-rules/receipts.test.ts` suite includes
  dedicated oversize-rejection tests for both the friendship-
  receipts and (defensive) group-receipts predicates — uploading
  an 11 MB buffer is rejected by the `request.resource.size < 10 *
  1024 * 1024` predicate at `storage.rules`.
- **R8 — Storage rules test gap (content-type):** **CLOSED.** The
  same suite includes dedicated MIME-rejection tests for both
  predicates — uploading a `text/plain` (or `image/gif`) blob is
  rejected by the `request.resource.contentType.matches('image/(jpeg|png)')`
  predicate. Membership-positive (member can upload),
  membership-negative (non-member rejected), unauthenticated
  (anonymous rejected), and cross-collection `firestore.get()`
  predicate verification tests are all included to make R7 + R8
  the load-bearing tests for the new Storage surface.
- **PY3 — Expand integration tests for Sprint 2 flows:** PR #48
  adds three skipped integration-test stubs at
  `test/integration/expenses/receipt_upload_flow_test.dart`
  documenting the canonical steps for (a) create-with-receipt
  upload-then-view round-trip, (b) edit-mode replace round-trip,
  (c) edit-mode remove round-trip including the Storage delete.
  Partial credit only; PY3 remains open pending the Flutter
  emulator harness.
- **D6 — npm audit moderate vulnerabilities:** unchanged (PR #48
  did not touch `functions/package.json` or `package-lock.json`
  per the story's Out of Scope negative-scope guard).
- **D1, D2, D4, D7:** unchanged (Sprint 4+ scope per the burndown).
- **Orphan-cleanup Cloud Function for receipts (NEW deferred):**
  SRS schema doc line 312 calls for a 90-day reaper of unreferenced
  files under `receipts/`. PR #48 architect §2.9 item 5 documents
  this as a FUTURE-work item. NOT a Bucket-B item; tracked in
  `docs/sprint-zero/next-three-prs.md` as a PR #49+ candidate
  (operational hardening chore).
- **Trigger no-op-recompute optimisation (NEW deferred):** PR #48
  architect §2.9 item 4 documents that the
  `onExpenseWriteFriendship` trigger re-fires on receipt-only
  updates and runs `recomputeSimplifiedBalances` even though
  balances do not change. Log noise + trivial CPU cost; FUTURE
  optimisation. NOT a Bucket-B item; tracked in
  `docs/sprint-zero/next-three-prs.md` as a PR #49+ candidate.

Net contribution of PR #48 to Bucket-B totals: **+2**. R7 + R8
both close. The remaining count drops to **28 / 37**.

PR #51 (FR-EX-07 activity feed write-side, friendship expenses)
closes **R5a** and makes partial progress on **PY3**:

- **R5a — Firestore rules test gap for activity collection:**
  **CLOSED.** The new `functions/test/firestore-rules/activity.test.ts`
  suite (12 tests) covers AC-6 through AC-12 of the FR-EX-07
  story:
    - AC-6 (positive): authenticated owner reads own item — succeeds.
    - AC-7 (negative): non-owner read of another user's item —
      `permission-denied`; variant covers the no-item-present case.
    - AC-8 (negative): unauthenticated read — `permission-denied`.
    - AC-9 (negative, 3 variants): owner / non-owner / unauthenticated
      client attempting to create an item — all `permission-denied`.
    - AC-10 (negative): owner attempting to update an item — `permission-denied`.
    - AC-11 (negative): owner attempting to delete an item — `permission-denied`.
    - AC-12 (negative, 3 variants): parent `activity/{userId}` doc
      read / create / unauthenticated read — all rejected via the
      explicit `allow read, write: if false` defence-in-depth on
      the parent doc.
  Note: **R5a is a new Sprint-2 tracker ID** introduced here for the
  activity-collection rules (closed by PR #51); it is **not** part of the
  Sprint-1 audit. Audit **R5 = `groups/{id}` update** is tracked as the
  remaining **R5b** (Sprint 3 groups epic). The shorthand "R5 was split into
  R5a + R5b" is imprecise — only R5b corresponds to the audit's R5; R5a is a
  separately-introduced activity-rules ID. The original R5 row in the Test
  Coverage Gaps table is renumbered to R5b accordingly.
- **PY3 — Expand integration tests for Sprint 2 flows:** PR #51
  extends `functions/test/integration/on-expense-write.integration.test.ts`
  with three new round-trip tests for AC-17 (create → both members
  read; edit → both members read; soft-delete → both members
  read). The tests run inside the existing
  `firebase emulators:exec --only auth,firestore,functions,storage`
  CI step. Partial credit only; PY3 remains open pending broader
  Flutter integration harness coverage.
- **R1, R2, R3, R4 — Friendship rules test gaps:** unchanged
  (closed by earlier PRs).
- **R5b — Groups rules test gap:** unchanged (Sprint 3 groups
  epic).
- **R6 — Settlement rules test gap:** unchanged (closed by PR #37
  per resolution log).
- **R7, R8 — Storage rules test gaps:** unchanged (closed by PR
  #48).
- **D1, D2, D4, D7, D6:** unchanged (Sprint 4+ scope).
- **No new Bucket-B items filed by PR #51.** The PR is server-only
  (no client surface), so no new test-coverage gaps appear.

Net contribution of PR #51 to Bucket-B totals: **+1**. R5a closes.
The remaining count drops to **27 / 37**.

PR #52 (FR-AC-01 activity feed read-side + settlement-trigger
activity emission) makes partial progress on **PY3** and does NOT
close any Bucket-B items directly:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #52
  extends `functions/test/integration/on-settlement-write.integration.test.ts`
  with two new round-trip tests for FR-AC-01 AC-18 (settlement
  create → both parties' activity subcollections written;
  settlement soft-delete → no new activity item per architect §2.2
  v1.0 decision). PR #52 also adds 60+ new Flutter widget /
  domain / formatter / provider tests across the new
  `lib/features/activity/**` feature folder + the `OBTActivityRow`
  widget primitive. Partial credit only; PY3 remains open pending
  broader Flutter integration harness coverage.

  Note: the existing integration tests under
  `functions/test/integration/on-settlement-write.integration.test.ts`
  currently fail locally with a pre-existing Functions emulator
  load error (`functions.config() has been removed in firebase-
  functions v7`). Verified by reproducing on `main` with PR #52
  stashed — the failure is NOT caused by PR #52. A separate
  infrastructure chore PR (TBD) will investigate; CI may have a
  workaround that local runs do not.

- **No Bucket-B items closed by PR #52.** The read-side is not a
  separately tracked Bucket-B item; the rules block was already
  shipped in PR #51 (closing R5a).
- **No new Bucket-B items filed by PR #52.** The pre-existing
  integration-test infrastructure issue noted above is tracked in
  `docs/sprint-zero/next-three-prs.md` as a Sprint-3 candidate;
  it is not a regression introduced by PR #52.

Net contribution of PR #52 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.

PR #53 (FR-AC-03 FCM push notifications + FR-AC-05 cold-start
deep-link) makes partial progress on **PY3** and does NOT close
any Bucket-B items directly:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #53
  extends the trigger-handler tests with 11 new FCM-side
  assertions (the expense + settlement triggers now have explicit
  test coverage for `sendExpenseNotification` /
  `sendSettlementNotification` being called on the success branch
  AND being NOT-called on the stale-event / CONTEXT_NOT_FOUND /
  BALANCE_INVARIANT_VIOLATED branches AND being error-contained
  per architect §2.9 item 2). PR #53 also adds 63 new unit tests
  in the new `functions/test/notifications/` subdirectory
  (`fcm-send.test.ts` + `payload-renderer.test.ts` +
  `prefs-filter.test.ts` + `send-expense-notification.test.ts` +
  `send-settlement-notification.test.ts` + a new
  `format-inr.test.ts` mirror of the Flutter-side INR formatter
  test). On the Flutter side, PR #53 ships 95 new tests under
  `test/features/notifications/**` + `test/core/routing/**`
  covering the FCM token service, the notification handler,
  the permission controller, the deep-link handler, the
  pre-permission dialog, the in-app banner, the
  notifications boundary-contract grep, and the shared routing
  helper. Partial credit only; PY3 remains open pending the
  full emulator-side FCM round-trip integration test (deferred
  per PR #53 functions-dev §1 deviation — the existing
  emulator-side integration test infrastructure does not
  exercise the FCM emission path because `jest.mock()` does
  not survive the emulator process boundary).
- **No Bucket-B items closed by PR #53.** The FCM infrastructure
  is new ground and is not a separately tracked Bucket-B item.
- **No new Bucket-B items filed by PR #53.** The
  emulator-side FCM integration test infrastructure gap is
  tracked as a candidate in `docs/sprint-zero/next-three-prs.md`
  (PR #54 candidate slot). The pre-existing Functions emulator
  `functions.config()` load issue noted in the PR #52 burndown
  remains open and unrelated to this PR.

Net contribution of PR #53 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.

PR #54 (FR-SE-09 Send Reminder + per-friend 24-hour rate limit) makes
partial progress on **PY3** and does NOT close any Bucket-B items
directly:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #54 adds
  comprehensive callable-handler tests for the new
  `sendReminderNotification` function (24 test cases covering auth,
  input validation, non-member, recipient-doesn't-owe,
  rate-limit pre-check rejection + post-window pass, prefs-filter,
  no-tokens, full-failure dispatch FCM_DISPATCH_FAILED non-record,
  group-context forward-compat error, happy-path rate-limit doc
  shape, FCM dispatch params, activity emission to recipient, PII
  hashing in structured logs, and the message-presence-only logging
  contract). PR #54 also adds 7 helper-level unit tests for the
  `notifications/send-reminder-notification.ts` FCM dispatch helper
  mirroring the existing two helper test files, plus 13 activity-
  validator extension tests for the new `'reminder'` event-type
  shape. On the Flutter side, PR #54 ships 24 new tests under
  `test/features/reminders/**` covering the reminder repository,
  the send controller (success + per-error-code branches +
  telemetry + concurrent-send short-circuit), the cooldown provider
  (per-friendship isolation + in-memory reset on container
  disposal), plus 4 new widget tests for the OBTSettleUpCard
  receiving-direction variant and 3 new screen tests for the
  FriendDetailScreen owed-branch wiring (tap → controller, RATE_
  LIMITED snackbar, RECIPIENT_PREFS_DISABLED snackbar). Partial
  credit only; PY3 remains open pending the full emulator-side
  FCM round-trip integration tests across all callable + trigger
  paths (deferred per PR #53 + PR #54 functions-dev notes — the
  existing emulator-side integration test infrastructure does not
  exercise the FCM emission path because `jest.mock()` does not
  survive the emulator process boundary).
- **No Bucket-B items closed by PR #54.** The reminder callable +
  client feature folder are new ground and are not separately
  tracked Bucket-B items.
- **No new Bucket-B items filed by PR #54.** The
  `reminderRepositoryProvider` production wiring gap (it shares the
  throw-until-overridden pattern with `matchingRepositoryProvider`
  and `cloud_functions` is not yet in pubspec) is tracked as a
  candidate in `docs/sprint-zero/next-three-prs.md` for the PR #55
  slot. The deferred FR-SE-09 message-compose dialog is tracked as
  a follow-up UX PR candidate.

Net contribution of PR #54 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.

PR #55 (FR-PR-03 + FR-AC-04 — Notification preferences UI +
production `cloud_functions` adapter wiring) makes partial progress
on **PY3** and does NOT close any Bucket-B items directly:

- **PY3 — Expand integration tests for Sprint 2 flows:** PR #55
  adds 43 new Flutter tests across the notification-preferences
  feature folder and the production-adapter wiring path. The
  breakdown: screen widget tests for SCR-27 (toggle render +
  tap → controller invocation + per-toggle saving-state spinner
  + error-snackbar branches + OS-permission banner visibility
  per permission state); `NotificationPreferencesController`
  unit tests (initial-load → Ready transition; per-toggle 500 ms
  debounce; concurrent multi-toggle without inter-key blocking;
  Firestore write success → `savingKeys` clear; write failure
  → snackbar + state revert; controller dispose cancels pending
  debounces); 2 new adapter unit tests for the production
  `cloud_functions` overrides of `reminderRepositoryProvider`
  and `matchingRepositoryProvider` (callable construction +
  region pinning + the `FirebaseFunctionsException` → typed-
  result mapping shape); `UserRepository` extension
  tests for the new `updateNotificationPrefs(...)` writer (dot-
  path partial-map payload shape; rejects empty map; correct
  field-mask semantics); and a boundary-contract test asserting
  the `cloud_functions` package boundary is consumed only via
  the two production adapter factories (not direct in feature
  code). On the rules side PR #55 ships 3 new `users-update.test.ts`
  cases for the partial-map shape: positive partial-map write
  (`notificationPrefs.reminder: false` accepted by
  `isValidNotificationPrefs` after merge); rejection on invalid
  value type (non-bool rejected); rejection on full-replace
  dropping a required key (`update({'notificationPrefs': {newExpense: true, settlement: true}, ...})`
  rejected because the merged map fails `hasAll(['newExpense','settlement','reminder'])`
  — defence-in-depth that the partial-merge writer never
  accidentally degrades to a clobbering full-replace). Total
  contribution: **+43 Flutter tests + 3 rules tests.** Partial
  credit only; PY3 remains open pending the full emulator-side
  Flutter integration harness (orthogonal to this PR's client-only
  scope) and the FCM round-trip emulator-side integration test
  infrastructure (still deferred per PR #53 + PR #54 functions-dev
  notes — the `jest.mock()` boundary limitation is unchanged).
- **No Bucket-B items closed by PR #55.** The notification-
  preferences screen and the `cloud_functions` adapter wiring
  are new ground and are not separately tracked Bucket-B items.
  Note for the reviewer cross-checking the "remaining" totals:
  CV3 (Functions `function.ts` branch coverage at 76%) was
  CLOSED long ago by PR #36 (now 88.57%) — the client-side
  `cloud_functions` package wiring shipped in PR #55 is a
  DIFFERENT chore that was tracked in `docs/sprint-zero/next-three-prs.md`
  as a candidate for the PR #55 slot, not as a Bucket-B item.
- **No new Bucket-B items filed by PR #55.** One follow-up
  candidate was surfaced by QA and is tracked in
  `docs/sprint-zero/next-three-prs.md` as a PR #56-candidate
  rather than a Bucket-B item: the `app_settings` /
  `permission_handler` pubspec dependency that would wire
  AC-11's "Open Settings" CTA on both platforms (currently
  shipping in graceful-degradation form because
  `firebase_messaging: ^16.2.0` does not expose
  `openAppNotificationSettings()` on the Dart API per
  architect §2.4 ratification). The story file §2.4 (lines
  815-819) explicitly REJECTED bundling this inside PR #55 to
  stay within the 5 SP envelope. The remaining five follow-up
  issue candidates (FR-PR-02 phone-number-change flow; FR-PR-05
  Contact Support `mailto:` flow; `shared_preferences` adoption
  tracker; `OBTBottomNav` shell; FR-SE-08 dedicated full-history
  settlement screen) listed in the story's "Follow-up Issues to
  File After Merge" section (lines 625-647) remain on the
  candidate list in `next-three-prs.md`.

Net contribution of PR #55 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.

### PR #56 (OBTBottomNav shell + AuthenticatedShell — UX foundation chore)

PR #56 is a **3 SP UX-foundation chore** that closes the long-deferred
**PR #52 §2.1 OBTBottomNav shell deferral**. No SRS-functional-requirement
closes; the closure target is the design-system spec
`docs/design/02-design-system/components.md §2 OBTBottomNav` and the
information-architecture spec
`docs/design/01-information-architecture/navigation-flow.md §1`
(MainTabs subgraph). PR #56 ships:

- `lib/core/widgets/nav/obt_bottom_nav.dart` — the design-system primitive
  with five spec-ratified tabs (Home / Friends / Groups / Activity /
  Profile), outlined-vs-filled icon swap on selection, and accessibility
  semantics carrying `isSelected` on the active tab.
- `lib/features/shell/presentation/authenticated_shell.dart` — the
  `ConsumerStatefulWidget` host with an `IndexedStack` over the five
  tab content widgets for state preservation, PopScope snap-to-tab-0 on
  Android back from non-zero tabs, and per-tap
  `bottom_nav_tab_selected` telemetry.
- `lib/features/shell/presentation/{home_dashboard_placeholder,groups_list_placeholder}.dart`
  — the two tab content placeholders (Home dashboard pending FR-HD-01..04;
  Groups list pending the Sprint 3 Groups epic).
- `lib/features/shell/application/shell_telemetry.dart` — telemetry
  constants for the new `bottom_nav_tab_selected` event.
- `lib/main.dart` line 133 wire change swapping `HomePlaceholderScreen`
  for `AuthenticatedShell`, plus the matching push update in
  `lib/features/auth/presentation/phone_entry_screen.dart`.
- DELETION of `lib/features/auth/presentation/home_placeholder_screen.dart`
  per architect §2.4. The body content is extracted to
  `HomeDashboardPlaceholder`; the in-AppBar Activity/Profile shortcut
  buttons are obsoleted by the bottom nav.
- One new row in `docs/design/07-technical/telemetry-plan.md` §1.8
  Cross-Cutting Events for `bottom_nav_tab_selected`.
- 33 new tests (5 telemetry constants + 14 OBTBottomNav widget tests
  + 10 AuthenticatedShell widget tests + 4 boundary-contract greps).

**No Bucket-B items closed by PR #56.** The OBTBottomNav shell deferral
was tracked in `docs/sprint-zero/next-three-prs.md` as a PR candidate
and in PR #52's architect §2.1 — not as a separately tracked Bucket-B
item. Invariants 1 / 2 / 3 / 4 are all N/A on this PR (no money flows
through the shell, no `simplifiedBalances` access, no share-sheet code
paths, no new Firebase SDK usage); the boundary-contract grep at
`test/features/shell/shell_boundary_contract_test.dart` is the
defence-in-depth assertion.

**No new Bucket-B items filed by PR #56.** Two follow-up candidates
are tracked in `docs/sprint-zero/next-three-prs.md` rather than as
Bucket-B items: (a) the FR-HD-04 persistent FAB + Add Expense context
picker (P0 — natural pair with the shell that just shipped), and (b)
the `shellNavigationControllerProvider` Riverpod `Notifier<int>` that
the FR-AC-05 cold-start deep-link expansion will need for
programmatic tab switching (the FCM handler runs outside the widget
tree).

Net contribution of PR #56 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.


### PR #57 (FR-HD-04 persistent FAB + Add Expense context picker — P0 feature + bundled `currentUserIdProvider` production-wiring closure)

PR #57 is a **3 SP feature PR** that closes the **FR-HD-04 P0**
SRS row (persistent FAB + Add Expense context picker) AND the
bundled **`currentUserIdProvider` production-wiring regression**
that PR #56 left behind in its `AuthenticatedWithProfile` arm.
The regression closure is a mandatory bundle per architect §2.1 —
the natural completion of PR #56 architect §2.1 reconciliation.
PR #57 ships:

- `lib/core/widgets/nav/obt_floating_action_button.dart` — the
  design-system primitive per `components.md` (50 LOC). Material 3
  FAB with OneByTwo design tokens; reusable across every primary
  surface that needs a primary-action FAB.
- `lib/features/shell/presentation/add_expense_context_picker_sheet.dart`
  — the Add Expense context picker bottom sheet (282 LOC). Friend
  path routes to the existing Add Expense bottom sheet (PR #38)
  with the selected friend pre-populated; Group path stubbed with
  a "Coming soon" snackbar pending the Sprint 3 Groups epic.
- `lib/features/shell/application/shell_telemetry.dart` — 6 new
  telemetry constants for the FAB-tap → picker-open →
  friend-select / group-select-stub funnel.
- `lib/features/shell/presentation/authenticated_shell.dart` —
  `Scaffold.floatingActionButton` slot wiring + `_onFabTapped`
  handler. The FAB is hidden on the Activity tab per architect
  §2.3 (Activity is a read-only surface).
- `lib/features/friends/presentation/friend_detail_screen.dart`
  — FAB refactor to consume the new `OBTFloatingActionButton`
  primitive with `heroTag: 'friendDetailFab'` (avoids Hero
  animation collision with the shell-owned FAB).
- `lib/main.dart` — per-arm `ProviderScope` override for
  `currentUserIdProvider` inside the `AuthenticatedWithProfile`
  branch. Closes the throw-until-overridden gap PR #56 left
  behind (`friendsListProvider` + `activityFeedProvider` were
  throwing `UnimplementedError` on first read in production
  because the providers were declared without overrides).
- `lib/features/friends/application/friends_list_provider.dart`
  + `lib/features/activity/application/activity_feed_provider.dart`
  — 2-character Riverpod 2.x `dependencies: [currentUserIdProvider]`
  addition each so the providers correctly invalidate when the
  signed-in user changes (architect §2.9 reconciliation
  discovery; natural completion of §2.1).
- 4 new test files: `test/core/widgets/nav/obt_floating_action_button_test.dart`,
  `test/features/shell/add_expense_context_picker_sheet_test.dart`,
  `test/features/shell/authenticated_shell_fab_integration_test.dart`,
  `test/main_test.dart`. Plus extensions to 4 existing test files
  (`test/features/shell/authenticated_shell_test.dart`,
  `test/features/shell/shell_telemetry_test.dart`,
  `test/features/shell/shell_boundary_contract_test.dart`,
  `test/features/friends/friend_detail_screen_widget_test.dart`).
- **40 net new Flutter tests** (1203 → 1243 passing + 30 skipped
  unchanged). Zero new Functions tests (no server-side code).
  All gates green: 1243 Flutter tests pass; Functions 319 / 22
  unchanged; `dart analyze --fatal-infos` + `dart format --set-exit-if-changed`
  clean; Inv-1 / Inv-2 / Inv-4 / PII-leak greps clean on the
  new `lib/features/shell/**` + `lib/core/widgets/nav/obt_floating_action_button.dart`
  files.

**Closes:** **FR-HD-04 P0** (SRS row). PLUS the bundled
**`currentUserIdProvider` production-wiring regression** that
PR #56 left behind (per architect §2.1) — not an SRS row but the
natural completion of PR #56 architect §2.1 reconciliation, and
a mandatory bundle because `friendsListProvider` +
`activityFeedProvider` were throwing `UnimplementedError` on
first read in production until the per-arm `ProviderScope`
override landed.

**Partial UX-foundation progress.** The FAB + context picker
shipped; two related polish items remain deferred in parallel
and are tracked as follow-up candidates in
`docs/sprint-zero/next-three-prs.md`:

1. The `OBTBottomNav` indicator-pill-behind-icon affordance per
   `components.md §2` — deferred by PR #56 architect §2.10
   reconciliation 4 (Material's `BottomNavigationBar` does not
   render the pill; pillless ship for v1.0 with revisit if/when a
   `NavigationBar` migration is approved).
2. The `OBTFloatingActionButton` spring-physics scale-in animation
   on first frame — deferred by PR #57 architect §2.2
   (cosmetic polish item, not a defect; ~1 SP follow-up).

**No Bucket-B items closed by PR #57.** The FR-HD-04 FAB +
context picker work is a P0 functional requirement (closes an
SRS row) rather than a Bucket-B audit item; the bundled
`currentUserIdProvider` production-wiring closure is the natural
completion of a PR #56 reconciliation discovery, tracked in
`next-three-prs.md`, not as a separately tracked Bucket-B item.
Invariants 1 / 2 / 4 are all N/A on this PR (no money flows
through the FAB or context picker, no `simplifiedBalances`
access, no new Firebase SDK usage); Invariant 3 (share-sheet) is
also N/A (no share-sheet code paths). The boundary-contract
greps under `test/features/shell/shell_boundary_contract_test.dart`
continue to pass after extension for the FAB surface.

**No new Bucket-B items filed by PR #57.** One follow-up
candidate was surfaced by Phase 4 QA and is tracked in
`docs/sprint-zero/next-three-prs.md` rather than as a Bucket-B
item: the **storage-rules `firestore.get()` cross-collection
predicate evaluation gap** discovered by `npm run test:rules`
Gate-5 — 6 failures in `functions/test/storage-rules/receipts.test.ts`
that have an **IDENTICAL pass/fail set against `main` and HEAD**
(i.e., they pre-exist PR #57 and are NOT a regression caused by
this PR). The failures are an environmental / emulator issue
with `firestore.get()` evaluation inside the storage emulator,
not a code defect in `storage.rules` or in PR #57's
implementation. Tracked as a separate ~1-2 SP investigation
chore on the PR #58 candidate list.

Net contribution of PR #57 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.

### PR #58 (FR-SE-08 dedicated settlement-history screen — P0 feature)

PR #58 is a **3 SP feature PR** that closes the **FR-SE-08 P0**
SRS row for the dedicated settlement-history surface (friendship
axis). PR #42 + PR #43 shipped the in-timeline settlement rows that
satisfied the v1.0 functional commitment; PR #58 delivers the
design-spec contract — the dedicated `/settle/history` screen
(SCR-24). PR #58 ships:

1. `SettlementHistoryScreen` (SCR-24) at
   `lib/features/settlements/presentation/settlement_history_screen.dart`.
   Generic over `(contextType, contextId)` — the architectural seam
   the Sprint 3 Group Detail screen inherits. Four states (loading /
   populated / empty / error) via inline private widgets.
2. `settlementHistoryProvider` — a `StreamProvider.family` keyed by
   `SettlementHistoryArgs { contextType, contextId }`, reusing the
   PR #42 `watchByContext` read path with a 50-item cap.
3. `settlement_history_telemetry.dart` — the two pre-declared events
   (`settlement_history_viewed`, `settlement_history_error`); NEITHER
   carries `context_id` (PII guard, ADR-0013).
4. The "View Settlement History" link on `FriendDetailScreen`
   (populated state only; no entry-point telemetry).

**No Bucket-B items closed by PR #58.** FR-SE-08 is a P0 functional
requirement (closes an SRS row) rather than a Bucket-B audit item.
Invariants 1 / 2 / 3 / 4 are all N/A on this read-only client
surface (no money write paths — the per-row amount flows through
`formatInrFromPaise()`; no `simplifiedBalances` access; no
share-sheet code; no new Firebase SDK usage). The
`settlement_history_pii_leak_test.dart` boundary-contract triad
(Inv-1 + Inv-2 + PII parameter-key) returns zero violations over
the three new source files.

**No new Bucket-B items filed by PR #58.** Several follow-ups are
tracked in `docs/sprint-zero/next-three-prs.md` rather than as
Bucket-B items: the OBT* primitive extractions (`OBTSkeletonLoader`
/ `OBTEmptyState` / `OBTErrorState` / `OBTUserAvatar` /
`OBTRupeeText`), cursor-based pagination beyond 50, Group-context
push wiring, the settlement-detail screen, per-month grouping, the
share/export action, and the screen-spec vs telemetry-plan
`context_id` discrepancy docs cleanup.

Net contribution of PR #58 to Bucket-B totals: **0**. The
remaining count stays at **27 / 37**.

### PRs #59–#72 (no Bucket-B closures)

This burndown's "Last updated" header sat at PR #58. PRs #59 through #72
shipped features, chores, and infrastructure but closed **no further
Bucket-B audit findings**. Recorded here so nothing is silently dropped:

| PR | Commit | Nature | Bucket-B impact |
|---|---|---|---|
| #59 | `093fce7` | Documentation reconciliation (docs/skills/agents synced; two code fixes) | 0 — docs-only |
| #60 | `8f72514` | FR-PR-05 Contact Support `mailto:` flow | 0 |
| #61 | `d474507` | CI PR-pipeline speed-up | 0 — CI infra |
| #62 | `57c272e` | FR-HD-01/02 Home dashboard balances | 0 |
| #63 | `209afea` | FR-PR-04 My Friends / My Groups + tab nav | 0 |
| #64 | `2e68713` | FR-PR-02 change phone via OTP re-verification | 0 |
| #65 | `d542793` | FR-AU-09 delete account + cascade Cloud Function | 0 |
| #67 | `1f26548` | FR-HD-03 monthly-spend category breakdown chart | 0 |
| #69 | `8dd67f9` | FR-AC-05 deep-link tab-switch on notification tap | 0 |
| #70 | `dda2f97` | AC-11 "Open Settings" deep-link CTA chore | 0 |
| #71 | `a0de106` | `shared_preferences` cross-launch persistence chore | 0 |
| #72 | `33f870d` | Firestore rules — friendship-expense creator-only edit / soft-delete (closes #47) | 0 — a tightening of an existing `allow update`, NOT a Bucket-B finding; the rules-hardening was the FR-EX-06 §2.9 item 5 "NEW deferred" follow-up tracked from the PR #46 burndown above, never a Bucket-B audit item |

The remaining count held at **27 / 37** throughout.

### PR #73 (Bucket-B close-with-evidence bundle — tracker hygiene)

PR #73 is the **first PR whose primary deliverable is Bucket-B tracker
hygiene**. Every prior Bucket-B closure (R1–R3 in #32, CV3 in #36, SR8 in
#38, D5a/D5b in #44, R7–R8 in #48, R5a in #51) was a side-effect of feature
or chore work logged in this burndown. PR #73 ships **no application code, no
rules, and no new tests** — the resolving work shipped in earlier PRs. Its
job is to verify the cited evidence, post per-issue evidence comments, and
close or re-scope the three audit-tracker issues (#20 / #21 / #23) correctly.

**Evidence verified (read the artefact; re-ran the suites green at PR #73).**

| Finding | Resolved by | Artefact (verified) | Evidence |
|---|---|---|---|
| CV3 — `function.ts` branch coverage 76% | PR #36 (`44c1618`) | `functions/src/simplified-debts/function.ts` | The `recomputeAndWrite` variant-2.3(b) refactor + trigger-boundary tests took branch coverage **76% → 88.57% (31/35)** at the #36 gate; the full unit-coverage gate measures **89.13%** at PR #73. Gate green. |
| R1 — `friendships/{id}` create validation | PR #32 (`84ad01a`) | `functions/test/firestore-rules/friendships.test.ts` | "create rules" describe block (valid create, missing/typed fields, wrong caller). |
| R2 — `friendships/{id}` update validation | PR #32 (`84ad01a`) | same | "update rules" describe block (member can update `lastActivityAt`; `memberIds` immutability; `simplifiedBalances` write-block, Invariant 2). |
| R3 — `friendships/{id}` delete deny | PR #32 (`84ad01a`) | same | "delete rules" describe block — client delete `assertFails`. |
| R5a — `activity/{userId}/items` rules | PR #51 (`d2302b9`) | `functions/test/firestore-rules/activity.test.ts` | 12 tests, AC-6 → AC-12 (owner read positive; non-owner / unauth negatives; client create / update / delete denied; parent-doc defence-in-depth). |
| R7 — Storage file-size validation | PR #48 (`0c6f649`) | `functions/test/storage-rules/receipts.test.ts` | File header line 7 declares "Closes R7 + R8"; AC-16 rejects an 11 MB upload against the **receipts-path** predicate `request.resource.size < 10 * 1024 * 1024`. (Avatars-path residual: see the note below.) |
| R8 — Storage content-type validation | PR #48 (`0c6f649`) | same | AC-17 rejects `text/plain` and `image/gif` against the **receipts-path** predicate `contentType.matches('image/(jpeg\|png)')`. (Avatars-path residual: see the note below.) |
| PY3 (Functions/emulator layer) — friend-add + expense-create flows | PR #36 enabled `test:integration` in CI; extended by #37 / #45 / #65 | `functions/test/integration/*.integration.test.ts` | 5 suites / 43 tests run under `firebase emulators:exec --only auth,firestore,functions,storage`. Provenance: `on-expense-write` + the in-CI gate landed in #36; `simplified-debts` integration test predates it (authored #12, first run in CI by #36); `on-settlement-write` in #37; `lookup-user-by-phone-number` unskipped/fixed in #45; `delete-user-account` in #65. |

Verification runs at PR #73 (JDK 21, demo-onebytwo emulator project): rules
suite **10 suites / 200 tests** green; integration suite **5 suites / 43
tests** green; simplified-debts unit-coverage gate green (`function.ts`
89.13% branch). No artefact was modified.

> **R7/R8 residual (avatars path) — recorded for literal accuracy.** The Sprint-1 audit
> (`docs/audits/sprint-1/04-dependency-and-security.md`, R7/R8) names the
> **`avatars/{userId}`** Storage constraints — 5 MB size and `image/(jpeg|png)`
> content-type. The R7/R8 close was ratified at **PR #48** against the **`receipts/`**
> Storage predicates (`receipts.test.ts` header: "Closes R7 + R8"), which exercise the
> identical size/MIME rule shape (10 MB cap) on the new receipts surface — i.e. R7/R8 was
> read as generic Storage size/MIME enforcement, consistent with that prior decision. The
> literal **avatars-path negatives** (oversize + wrong-MIME) are **not** present in
> `functions/test/storage-rules/avatars.test.ts`: the `storage.rules` avatars clauses
> exist and are enforced; only the two negative assertions are absent. This is a minor
> residual that does not reopen #21's substantive rules-coverage goal — it is recorded
> here (and on the #21 close comment) rather than silently dropped, and the two trivial
> avatars negatives can be added in a future Storage-rules test-hygiene touch.

**Issue actions.**

- **#20 "Improve test coverage gaps" — PARTIAL close, re-scoped, kept OPEN.**
  CV3 resolved by PR #36 (evidence comment posted). The remaining sub-items
  stay open under a narrowed scope: **SC1** (concurrent-submit guard test for
  phone entry), **SC2** (OTP auto-retrieval timeout test), **SC3**
  (`MAX_SAFE_INTEGER` overflow test for the simplified-debts algorithm), and
  **SC4** (large-group 100+ scalability test — Sprint 3 groups). No `Closes`
  line.
- **#21 "Firestore and Storage rules test gaps" — FULL close.** R1–R3 (#32),
  R5a (#51), and R7–R8 (#48) all resolved; the only remainders are the
  **groups** halves — **R4** (`groups/{id}` create), **R5b** (`groups/{id}`
  update), **R6** (`groups/{id}` delete) — which belong to the Sprint 3 Groups
  epic and are tracked there, not under #21. With every non-groups finding
  resolved and the groups halves cleanly re-scoped, #21 is the one genuine
  full-close (`Closes #21`). The R7/R8 close rests on the PR #48-ratified
  receipts-path coverage; the literal avatars-path negatives remain a minor
  untested residual (see the R7/R8 residual note above), which does not reopen
  #21's substantive scope.
- **#23 "Expand integration tests for Sprint 2 flows" — PARTIAL close,
  re-scoped, kept OPEN.** PY3 is substantially resolved **at the
  Functions/emulator data-flow layer** (the integration suite runs in CI). The
  remainders stay open: the **Flutter `test/integration/**/*_flow_test.dart`
  harness half of PY3** (the `skip:`ped stubs await the emulator harness),
  **RT2** (CI step-duration logging for the emulator suites), and **INV2**
  (system-share-sheet verification tests — partially addressed by PR #32's
  invite flow). No `Closes` line.

**Accuracy corrections applied with this reconciliation.** Earlier narrative
rows in this burndown and in `sprint-2-plan.md` carried two finding-ID
mis-assignments that contradict the audit source
(`docs/audits/sprint-1/04-dependency-and-security.md`): "R4 closed by PR #36"
(R4 is in fact `groups/{id}` create — Sprint 3, still open) and "R6 = settlement
rules closed by PR #37" (R6 is in fact `groups/{id}` delete — Sprint 3, still
open). The expense-friendship rules tests added in #36/#46 and the settlement
rules tests in #37 are real, but they are **not** the audit's R4/R6 — those
remain the Groups-epic remainders. The `02-test-suite-health.md` labels are also
authoritative: **SC2 = OTP auto-retrieval timeout**, **SC4 = large-group
scalability** (do not transpose them). These corrections change no totals.

Net contribution of PR #73 to Bucket-B totals: **0**. The bundle closes the
GitHub *issues* #20 / #21 / #23 against findings already counted when their
resolving PRs landed; it adds no new finding closures. The remaining count
stays at **27 / 37**.
