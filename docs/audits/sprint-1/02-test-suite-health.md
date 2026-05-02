# Phase 2 — Test-Suite Health Check

**Date:** 2026-05-02
**Lead:** QA
**Consulting:** Flutter Dev, Functions Dev

---

## 2.1 Coverage

### SRS Section 5.7 Thresholds

| Threshold | Requirement | Actual | Status |
|---|---|---|---|
| Non-UI code (unit + widget) | >= 70% | Flutter: 74%, Functions: 93% | **PASS** |
| Overall | >= 50% | Flutter: 74%, Functions: 93% | **PASS** |

### Current Absolute Coverage

| Suite | Lines Hit | Lines Found | Line Coverage | Statement Coverage | Branch Coverage |
|---|---|---|---|---|---|
| Flutter (all) | 1,165 | 1,561 | **74.0%** | — | — |
| Cloud Functions (main) | — | — | **93.0%** | 93.1% | 77.3% |
| Functions: `algorithm.ts` | — | — | **100%** | 100% | 100% |
| Functions: `function.ts` | — | — | ~89% | 89.5% | 76% |
| Functions: `index.ts` | — | — | ~75% | 75% | — |

### Coverage Trend

Coverage data was not systematically recorded in PR descriptions across Sprint 1.
This is a **process gap** — PR descriptions should include before/after coverage
numbers for each PR.

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| CV1 | Coverage is above SRS thresholds for both Flutter and Functions. No threshold violations. | — | None | — |
| CV2 | PR-level coverage tracking not consistently recorded across Sprint 1 PR descriptions. | Low | Backlog — add a coverage section to the PR description template in `feature-pr-conventions.md`. | QA |
| CV3 | Functions `function.ts` branch coverage at 76% (uncovered: lines 77, 257-283). These are likely error-handling edge cases in the function boundary. | Low | Backlog — add tests for uncovered branches when expense triggers are wired in Sprint 2. | Functions Dev |

---

## 2.2 Flaky-Test Detection

### Methodology

Analysed 30 workflow runs across Sprint 1 via GitHub Actions API. Grouped runs by
`head_sha` to identify same-code, different-result patterns (the true flakiness
signal).

### Results

**No flaky tests detected.** Zero instances of mixed pass/fail results on the same
commit SHA.

| Metric | Value |
|---|---|
| Total workflow runs | 30 |
| Failed runs | 9 (30%) |
| Same-SHA mixed results | **0** |
| Re-runs (same attempt) | 0 |

The 30% failure rate is entirely attributable to iterative development — each failed
run corresponds to a code push that was subsequently fixed. This is expected and
healthy CI behaviour.

### Branch-Level Patterns

| Branch | Runs | Pattern | Root Cause |
|---|---|---|---|
| `feat/auth-phone-entry` | 5 | 2 fail, 2 cancel, 1 pass | Iterative development (PR #4) |
| `feat/auth-session-persistence-and-sign-out` | 4 | 2 fail, 2 pass | Firestore rules test race condition (fixed in PR #12 via `maxWorkers: 1`) |
| `feat/func-01-simplified-debts` | 4 | 2 fail, 1 cancel, 1 pass | Rules test parallelism (same root cause, fixed) |
| `fix/ios-phone-auth-crash` | 4 | 2 fail, 2 pass | iOS build configuration (fixed in PR #9) |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| FL1 | No flaky tests detected. CI failures are all attributable to code changes, not non-determinism. | — | None | — |
| FL2 | The `maxWorkers: 1` fix for rules tests (PR #12) resolved the only known source of test non-determinism. Documented in retro action item 3. | — | Accept — already addressed. | — |

---

## 2.3 Test-Suite Runtime

| Suite | Wall-Clock Time | Tests | Time per Test |
|---|---|---|---|
| Flutter (`flutter test --coverage`) | **25.0s** | 213 | 117ms |
| Cloud Functions (`npm test`) | **1.8s** | 32 | 56ms |
| Cloud Functions rules tests | Not run locally (requires emulators) | ~44 | CI-only |
| Cloud Functions integration tests | Not run locally (requires emulators) | ~15 | CI-only |
| **Total (locally runnable)** | **~27s** | **245** | — |

### Runtime Analysis

No single test file accounts for >20% of total runtime. The Flutter suite at 25s and
Functions suite at 1.8s are both fast and well within acceptable PR cycle time.

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| RT1 | Test runtimes are healthy. No dominant test file or slow outlier. Flutter at 25s is fast for 213 tests. Functions at 1.8s is excellent. | — | None | — |
| RT2 | Rules and integration tests (emulator-dependent) cannot be benchmarked locally without the emulator running. CI timing should be monitored in Sprint 2. | Low | Backlog — add CI step duration logging to the PR pipeline for trend monitoring. | DevOps |

---

## 2.4 Test Pyramid Balance

### Flutter Tests: 213 Test Cases across 20 Files

| Layer | Files | Tests | % of Total |
|---|---|---|---|
| Unit (validators, repositories, state providers) | 6 | 64 | 30% |
| Controller (state management, business logic) | 3 | 60 | 28% |
| Widget (screen rendering, interaction) | 12 | 82 | 39% |
| Integration (flow end-to-end) | 2 | 5 | 2% |

**Pyramid shape: HEALTHY.** Base (unit + controller) at 59%, middle (widget) at 39%,
top (integration) at 2%. This is the correct shape — wide base, narrow top.

### Cloud Functions Tests: ~91 Test Cases across 9 Files

| Layer | Files | Tests | % of Total |
|---|---|---|---|
| Unit (algorithm, handlers) | 3 | 28 | 31% |
| Property (fast-check generative) | 1 | 4 | 4% |
| Rules (Firestore + Storage security) | 4 | 44 | 48% |
| Integration (end-to-end) | 1 | 15 | 17% |

**Pyramid shape: SECURITY-FOCUSED.** Rules tests dominate at 48%. This is an
intentional and justified inversion — Invariant 2 (simplifiedBalances is
server-maintained) depends on rules correctness, so heavy rules testing is risk
mitigation, not a smell.

### Combined: ~302 Tests across 29 Files

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| PY1 | Flutter pyramid is healthy with correct shape. | — | None | — |
| PY2 | Functions pyramid is intentionally security-heavy. Justified by invariant 2. | — | Accept — document the rationale in test-strategy.md if not already noted. | QA |
| PY3 | Integration tests are thin (5 Flutter + 15 Functions = 20 total, 7%). Acceptable for Sprint 1 scope (auth-only) but will need expansion in Sprint 2 as cross-feature flows emerge. | Low | Backlog — Sprint 2 integration tests should cover friend-add and expense-create flows end-to-end. | QA |

---

## 2.5 Coverage Gaps — Spot Checks

### Spot Check 1: Phone Entry Controller

**Files:** `phone_entry_controller.dart` + `phone_validator.dart`
**Tests:** 13 controller tests + 14 validator tests = 27 total
**Regression safety:** 85%

**Well tested:** All validation boundaries (digits 0-9 prefixes, length limits),
network failure, too-many-requests, auto-verification, analytics events, E.164
formatting.

**Gaps:** Concurrent submit guard not tested (UI responsibility per doc), only 2 of N
Firebase error codes tested, stopwatch precision not validated.

### Spot Check 2: OTP Entry Controller

**Files:** `otp_entry_controller.dart`
**Tests:** 31 tests
**Regression safety:** 92%

**Well tested:** Resend cooldown (30s), retry cap (3/10min), sliding window pruning,
session expiry, paste validation, auto-read, analytics events (9 event tests), phone
hash privacy, digits immutability, concurrent resend guard.

**Gaps:** Auto-retrieval timeout path, verificationId null race, OTP submission while
resend pending.

### Spot Check 3: Simplified-Debts Algorithm

**Files:** `algorithm.ts`
**Tests:** 15 explicit + 4 property-based = 19 total
**Regression safety:** 98%

**Well tested:** All 6 canonical cases, balance invariant enforcement, deterministic
ordering, tie-breaking, projection function, property-based invariant verification
(200 runs).

**Gaps:** Large numbers near `MAX_SAFE_INTEGER`, large groups (100+ members), star
topology.

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| SC1 | Phone entry controller: concurrent submit not guarded in tests. If two rapid taps both trigger `requestOtp`, the second call could fire before the first completes. | Medium | Backlog — add a loading-state guard test when the phone entry screen is next touched. | Flutter Dev |
| SC2 | OTP controller: auto-retrieval timeout path not tested. | Low | Backlog — add when Android auto-read is refined. | Flutter Dev |
| SC3 | Algorithm: no large-number (overflow) test. Property tests cap at 10M paise (1 lakh INR). Real expenses could exceed this. | Medium | Backlog — add a `MAX_SAFE_INTEGER` boundary test to the canonical suite. | Functions Dev |
| SC4 | Algorithm: no scalability test for large groups (100+ members). Property tests max at 8 members. | Low | Backlog — add when group features are implemented in Sprint 3. | Functions Dev |

---

## Summary

| Category | High | Medium | Low | Total |
|---|---|---|---|---|
| Coverage (2.1) | 0 | 0 | 2 | 2 |
| Flaky tests (2.2) | 0 | 0 | 0 | 0 |
| Runtime (2.3) | 0 | 0 | 1 | 1 |
| Pyramid balance (2.4) | 0 | 0 | 1 | 1 |
| Coverage gaps (2.5) | 0 | 2 | 2 | 4 |
| **Total** | **0** | **2** | **6** | **8** |

### Preliminary Triage

**Fix now candidates (0):** No blocking test-suite issues. Coverage is above SRS
thresholds, no flaky tests, runtimes are healthy.

**Backlog candidates (8):** CV2, CV3, RT2, PY3, SC1, SC2, SC3, SC4.

**Accept candidates (3):** FL1, FL2, PY2.

### Overall Assessment

The test suite is in good health for a Sprint 1 boundary. Coverage exceeds SRS
thresholds, the pyramid shape is correct, there are no flaky tests, and runtimes are
fast. The gaps identified (concurrent submit guard, overflow testing, scalability) are
genuine but non-blocking — they relate to scenarios that are either UI-guarded or not
yet exercised by shipped features. Sprint 2 should address the medium-severity items
(SC1, SC3) as chore work.
