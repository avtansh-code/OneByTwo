# Phase 2 — Test-Suite Health Check

**Date:** 2026-06-24
**Lead:** QA
**Consulting:** Flutter Dev, Functions Dev

Method: ran the full Flutter suite with coverage (`fvm flutter test --coverage`) and the
Functions Jest coverage run locally; parsed `coverage/lcov.info` per feature and the
Jest coverage summary per module; counted the test pyramid by content
(`testWidgets(` vs `test(`); scanned the last 40 `pr.yml` CI runs for flaky
(failed-then-re-passed) patterns; inspected the coverage-gate and RT2 logic in
`.github/workflows/pr.yml`; spot-checked the load-bearing simplified-debts and trigger
modules. SRS §5.7 thresholds: ≥70% non-UI per feature/module, ≥50% overall.

---

## 2.1 Coverage Trend vs SRS §5.7

**Flutter (local run: 1595 passed, 30 skipped):** overall **84.7%** lines (6918/8168) —
far above the ≥50% floor. Per-feature line coverage (includes UI; the SRS ≥70% non-UI
figure is therefore at least this high):

| Module | Lines % | ≥70%/50% |
|---|---|---|
| core | 87.3% | ✓ |
| features/activity | 83.6% | ✓ |
| features/auth | 75.6% | ✓ (lowest feature) |
| features/expenses | 78.6% | ✓ |
| features/friends | 86.2% | ✓ |
| features/home | 100.0% | ✓ |
| features/notifications | 77.1% | ✓ |
| features/profile | 87.5% | ✓ |
| features/reminders | 95.0% | ✓ |
| features/settlements | 93.9% | ✓ |
| features/shell | 99.3% | ✓ |

**Functions (local run: 24 suites, 341 tests):** **91.46% lines / 77.8% branch** overall;
every module ≥70% lines (lowest: on-settlement-write 84.2% lines, simplified-debts
94.4%, delete-user-account 94.8%, lookup 93.0%, notifications 93.5%, reminder 92.6%,
utils 100%). Branch coverage is thinner on the two triggers (see 2.5).

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| CV1 | (whole sprint) per-PR coverage fields (#65 profile 87.3%, delete-user 97.5%; #67 home 99.8%, expenses 78.8%) vs current run | **Coverage trend is flat-and-healthy, comfortably above SRS §5.7.** Recorded per-PR figures match the current run (home 99.8%→100%, profile 87.3%→87.5%, expenses ~78.6%). No feature/module is below threshold; no downward trend. | — | None (PASS) | — |
| CV2 | `.github/workflows/pr.yml:485` vs `:641-650` | **Workflow comment overstates enforcement.** The coverage-gate header says it enforces "simplified-debts 100% branch coverage," but the code emits simplified-debts branch % as an **advisory INFO** metric (correctly deferring to the canonical matrix as authoritative; Istanbul branch % includes implicit `??`/short-circuit/ternary branches). The comment is misleading. | Low | Fix now (cheap) — reword the comment to "advisory simplified-debts branch metric; canonical matrix authoritative". | DevOps |

---

## 2.2 Flaky-Test Detection

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| FL1 | last 40 `pr.yml` runs (31 success, 8 cancelled, 1 failure) | **No flaky tests detected.** The emulator-dependent suites (Firestore/Storage rules, integration, canonical) show consistent green across the sprint. The 8 "cancelled" runs are concurrency-superseded (a new push cancels the in-progress run), not failures. No `// FLAKY` annotations exist and none are needed. | — | None (PASS) | — |
| FL2 | run 27423637906 (`feat/contact-support-mailto` / PR #60, sha 5925b0c7) | The single failure in 40 runs was the **`Build iOS (no signing)`** job — **all test jobs (Flutter, Functions, Integration, Coverage Gate, Android) passed**. The same sha shows only the one failure (no same-sha re-pass), and it was fixed forward by a later commit that merged. This is a **deterministic iOS-build failure, not a test flake**; it cross-references the known iOS Podfile.lock / `pod install` fragility (see Phase 4). | Low | Accept here; route the iOS-build fragility to Phase 4 (dependency/build). | DevOps |
| FL3 | all `skip:` sites | Every skip uses the documented `skip: '<reason>'` string form (the 30 skipped tests are the `test/integration/**/*_flow_test.dart` stubs — see 2.4); there is **no silent `skip: true`** and no swallowed flakiness. | — | None (PASS) | — |

---

## 2.3 Test-Suite Runtime and Change-Detection Pipeline

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| RT1 | `.github/workflows/pr.yml:286-335` | **RT2 step-duration logging is present and correct.** Three emulator suites (rules-tests, integration-tests, canonical-tests) wrap execution in `start=$(date +%s)` … `duration=…` with both a `RT2 step-duration:` line and a `::notice title=CI step duration::` annotation. The #76 RT2 deliverable shipped as designed. | — | None (PASS) | — |
| RT2 | `.github/workflows/pr.yml:41-52` (changes job, `dorny/paths-filter@v3`) | **Path-based change detection is wired** and per-job `if:` gating references it (validated structurally; behavioural confirmation belongs to Phase 3/4). A docs-only PR is expected to run only PR Title Lint. | — | None (PASS); Phase 3 to confirm gating behaviour | — |
| RT3 | RT2 logs (emulator suites) | **The emulator suites (integration + Firestore/Storage rules) dominate the PR cycle** — they require an emulator boot and JDK 21, whereas the Flutter suite ran ~44s and the Functions unit suite ~7s locally. No single suite is pathological, but the emulator jobs are the long pole; the RT2 logs now make this monitorable. | Low | Backlog — watch the RT2 durations; revisit sharding only if a suite trends past the PR-cycle budget. | DevOps |

---

## 2.4 Test Pyramid Balance

**Flutter:** 1067 unit-test cases (94 files without `testWidgets`) + 480 widget-test
cases (51 files with `testWidgets`) — a wide unit base under a solid widget tier.
**Functions:** 341 unit tests (24 non-emulator suites) + the Firestore/Storage rules
suites + the emulator integration suite. The base is wide; the pyramid is healthy.

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| PY1 | `test/**`, `functions/test/**` | **Pyramid shape is healthy** — unit ≫ widget ≫ integration, with no inversion. | — | None (PASS) | — |
| PY2 | `test/integration/**/*_flow_test.dart` (11 files, all `skip:`); no `integration_test/` dir | **The #23 remainder stands: the Flutter integration layer is render-only stubs, all `skip:'Requires emulator suite'/'…production code'`; there is no executable `integration_test/` harness.** Deferral to the `Sprint 6` milestone (issue #23) is correctly reflected and the skips are honest (not silent). | Medium | Accept the deferral **with a caveat** (see PY3): the deferral has a demonstrated cost. | QA |
| PY3 | `test/integration/friends/match_and_invite_flow_test.dart` (skipped) vs Phase-1 **S6** | **The deferred integration layer let a real defect ship.** The add-friend critical journey has only a *skipped* `match_and_invite_flow_test.dart`; no executable test exercises the screen→pop→match-and-invite wiring, which is exactly the gap that allowed S6 (unreachable add-friend flow) to merge green. Unit/widget tests pass each piece in isolation; nothing tests the seam. | Medium | Fix now (paired with S6) — when S6 is fixed, add **one executable end-to-end test** (widget-level with fakes if the emulator harness is still deferred) covering add-friend → friendship created. Re-confirm the rest of #23 stays Sprint 6. | QA + Flutter Dev |

---

## 2.5 Coverage Gaps That Look Like Risk (spot-checks)

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SC1 | `functions/src/simplified-debts/algorithm.ts:86,94` (78.9% branch) | **Spot-check 1 — load-bearing algorithm: the uncovered branches are unreachable.** Lines 86/94 are the `: 0` arm of the creditor/debtor tie-break ternary (`a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0`) — the equal-`userId` case, impossible for distinct map keys. The canonical, property, and boundary layers all pass. The "gap" is defensive, not risk. | — | Accept (document the unreachable tie-break branch) | Functions Dev |
| SC2 | `functions/src/triggers/on-settlement-write/function.ts` (66.1% branch / 82.8% lines; uncovered 194-201, 269-276, 425-431, 532, 542-559, 574-579) | **Spot-check 2 — settlement trigger failure paths are thin.** The happy path and stale-event guard are covered, but several error/guard branches (validation rejections, side-effect failure containment, monotonic-`lastActivityAt` skips) are not exercised. Sprint 3 extends settlements into group context, raising the cost of an untested branch here. | Medium | Backlog (Sprint 3) — add negative-path trigger tests before/with the group-settlement work. | Functions Dev |
| SC3 | `functions/src/triggers/on-expense-write/function.ts` (62.7% branch / 84.5% lines; uncovered 206-213, 496-578) | **Spot-check 3 — expense trigger failure paths are thin** (same shape as SC2: error/guard branches and side-effect containment under-tested). Lines pass the ≥70% gate; branches do not, but branch is not gated for Functions. | Low | Backlog (Sprint 3) — extend negative-path coverage when group-expense triggers are added. | Functions Dev |
| SC4 | `functions/test/simplified-debts/{algorithm,algorithm.boundary,algorithm.property,function}.test.ts` + `functions/test/integration/**` | **Verified — the simplified-debts layered tests still hold.** Canonical matrix (`algorithm.test.ts`), property (`algorithm.property.test.ts`), boundary/reserved-key + folding (`algorithm.boundary.test.ts`, `function.test.ts`), and the emulator-integration recompute (integration suite, fires `onExpenseWriteFriendship`/`onSettlementWrite`) are all green; Invariant 2 (`simplifiedBalances` server-only) preserved. The SC4 100+/1000-member scalability test from #76 de-risks the algorithm layer. | — | None (PASS) | — |

---

## Summary

| Sub-part | High | Medium | Low | PASS/None |
|---|---|---|---|---|
| 2.1 Coverage trend | 0 | 0 | 1 (CV2) | CV1 |
| 2.2 Flaky tests | 0 | 0 | 1 (FL2) | FL1, FL3 |
| 2.3 Runtime / change-detection | 0 | 0 | 1 (RT3) | RT1, RT2 |
| 2.4 Pyramid | 0 | 2 (PY2, PY3) | 0 | PY1 |
| 2.5 Spot-check risk | 0 | 1 (SC2) | 1 (SC3) | SC1, SC4 |
| **Total** | **0** | **3** | **4** | 7 PASS |

### Preliminary Triage (Phase 6 finalises)

- **Fix now:** CV2 (cheap workflow-comment fix), PY3 (add one executable add-friend
  end-to-end test alongside the S6 fix).
- **Backlog (Sprint 3):** SC2 + SC3 (trigger negative-path coverage, before group
  settlement/expense work), RT3 (monitor emulator-suite durations).
- **Accept:** SC1 (unreachable tie-break branch), FL2 (deterministic iOS build → Phase 4),
  PY2 (the #23 deferral stands, with the PY3 caveat).

> Headline: the test suite is **healthy** — no flakiness, coverage well above SRS §5.7
> on every module, a wide unit/widget base, and the simplified-debts layers intact. The
> one substantive theme is the **deferred Flutter integration harness (#23): its absence
> demonstrably let the Phase-1 S6 defect ship**. Phase 2 therefore recommends one
> targeted executable test for the add-friend journey now (with S6), while keeping the
> broader emulator harness on the Sprint 6 milestone, and shoring up the two triggers'
> negative-path branches before Sprint 3 extends them into groups.
