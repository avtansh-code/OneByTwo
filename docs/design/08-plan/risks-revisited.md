# Risks Revisited -- Post-Design Phase Assessment

## Purpose

After completing the full design phase (information architecture, design system,
architecture, wireframes, screen specifications, and technical specifications),
this document re-walks the 12 risks from the sprint-zero risk register
(`docs/sprint-zero/risk-register.md`). For each risk, it assesses whether the
design phase has strengthened or weakened the original mitigation, identifies new
information that changes the likelihood or impact, and cites specific design
artefacts that address the risk.

Four new risks identified during the design phase are appended at the end.

---

## Risk-by-Risk Assessment

| ID | Risk | Original Status | Updated Status | Assessment |
|----|------|-----------------|----------------|------------|
| R-01 | Single-environment Firebase (no staging) | OPEN | OPEN -- mitigation strengthened | See detailed assessment below. |
| R-02 | SMS OTP cost and Phone Auth quota limits | OPEN | OPEN -- mitigation strengthened | See detailed assessment below. |
| R-03 | Floating-point money errors | OPEN | OPEN -- mitigation substantially strengthened | See detailed assessment below. |
| R-04 | Hot documents on group balances | OPEN | OPEN -- mitigation strengthened | See detailed assessment below. |
| R-05 | Account deletion and DPDP compliance miss | OPEN | OPEN -- mitigation strengthened | See detailed assessment below. |
| R-06 | Bug in simplified-debts algorithm | OPEN | OPEN -- mitigation substantially strengthened | See detailed assessment below. |
| R-07 | No mail client on user device | OPEN | OPEN -- mitigation strengthened | See detailed assessment below. |
| R-08 | Phone Auth quota consumed during testing | OPEN | OPEN -- mitigation unchanged | See detailed assessment below. |
| R-09 | Firebase Dynamic Links sunset | OPEN | OPEN -- mitigation strengthened | See detailed assessment below. |
| R-10 | Riverpod 2.x breaking changes | OPEN | OPEN -- mitigation unchanged | See detailed assessment below. |
| R-11 | App Check enforcement blocking emulator traffic | OPEN | OPEN -- mitigation unchanged | See detailed assessment below. |
| R-12 | CI pipeline flakiness from emulator startup timing | OPEN | OPEN -- mitigation unchanged | See detailed assessment below. |

---

### R-01: Single-environment Firebase (no staging)

**Has the design phase strengthened or weakened the mitigation?**
Strengthened. The test design document (`07-technical/test-design.md`) codifies 12
integration tests (CUJ-1 through CUJ-12), all of which run exclusively against the
Firebase Emulator Suite. The offline-and-sync design (`07-technical/offline-and-sync.md`)
specifies emulator-based offline tests (section 6) including conflict resolution and
queued write persistence scenarios. The security rules design
(`07-technical/firestore-security-rules.md`) mandates 100% rule coverage against the
emulator. Together, these create a dense pre-merge validation layer that partially
compensates for the absence of a staging environment.

**New information from the design that changes likelihood or impact?**
The telemetry plan (`07-technical/telemetry-plan.md`) defines approximately 148
distinct analytics events across all screens. This level of instrumentation
provides strong post-release observability, enabling rapid detection of regressions
even in a single-environment deployment. Likelihood of an undetected bad release is
reduced, though impact remains high if one does occur.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/test-design.md` -- sections 1-5 (full test pyramid mapping, 12 CUJ integration tests, security rules test matrix).
- `docs/design/07-technical/offline-and-sync.md` -- section 6 (emulator-based integration tests).
- `docs/design/07-technical/telemetry-plan.md` -- full event catalogue for post-release monitoring.

---

### R-02: SMS OTP cost and Phone Auth quota limits

**Has the design phase strengthened or weakened the mitigation?**
Strengthened. The notifications design (`07-technical/notifications.md`, section 5)
confirms that the pre-permission dialog defers FCM token acquisition until after
authentication completes, which has no direct bearing on SMS costs but confirms the
auth flow is tightly scoped. The test design mandates all CUJ-1 tests run against
the Auth Emulator, reinforcing the original mitigation of never consuming real SMS
in testing.

**New information from the design that changes likelihood or impact?**
The telemetry plan includes `otp_send_requested`, `otp_send_succeeded`, and
`otp_send_failed` events with timing information. This provides the monitoring
infrastructure needed to detect quota exhaustion before users are affected. The
`otp_resend_tapped` and `otp_resend_exhausted` events cap resend attempts at three,
limiting per-user SMS consumption.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/telemetry-plan.md` -- section 1.2 (auth and onboarding events, OTP tracking).
- `docs/design/07-technical/test-design.md` -- section 4.1 (CUJ-1 integration test against Auth Emulator).

---

### R-03: Floating-point money errors

**Has the design phase strengthened or weakened the mitigation?**
Substantially strengthened. The design phase has embedded the integer-paise
constraint into every layer of the system. The Firestore schema
(`07-technical/firestore-schema.md`) specifies `amountPaise` as `integer` on every
expense, settlement, and balance field. The security rules outline
(`07-technical/firestore-security-rules.md`) mandates server-side validation that
`splits[*].sharePaise` sums to `amountPaise`. The simplified-debts algorithm
specification (`07-technical/simplified-debts-algorithm.md`) includes test case
SD-08 (float rejection) which explicitly validates that non-integer input is
rejected.

**New information from the design that changes likelihood or impact?**
The five split methods (equal, unequal, percentage, shares, exact) each produce
integer paise splits. The percentage and shares methods require rounding strategies
that could introduce off-by-one paise errors. This is a new dimension of risk not
fully addressed by the original mitigation (see R-13 below). Likelihood of
*floating-point* errors remains low; likelihood of *rounding* errors in percentage
and shares splits is moderate.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/firestore-schema.md` -- all `amountPaise` and `sharePaise` field definitions.
- `docs/design/07-technical/firestore-security-rules.md` -- splits-sum validation rules.
- `docs/design/07-technical/simplified-debts-algorithm.md` -- section 2 (worked examples, all in integer paise) and test case SD-08 (float rejection).
- `docs/design/07-technical/test-design.md` -- section 3 (canonical test matrix, verification rule 2: "Every amount is a positive integer").
- `docs/design/07-technical/cloud-functions-catalogue.md` -- section 1 (recomputeSimplifiedBalances invariant validation: sum-of-nets must equal zero).

---

### R-04: Hot documents on group balances

**Has the design phase strengthened or weakened the mitigation?**
Strengthened. The cloud functions catalogue (`07-technical/cloud-functions-catalogue.md`)
confirms that `recomputeSimplifiedBalances` operates inside a Firestore transaction,
serialising concurrent writes to the same context document. The algorithm is
idempotent, so retries caused by transaction contention converge correctly.

**New information from the design that changes likelihood or impact?**
The offline-and-sync design (`07-technical/offline-and-sync.md`, section 3.3) reveals
that when a user reconnects after an extended offline period, multiple queued writes
may trigger the Cloud Function independently and in rapid succession for the same
group. This increases the probability of write contention beyond what was anticipated
at sprint zero. Additionally, the `onExpenseWrite` trigger performs three side-effects
per invocation (recompute balances, write activity items, send notifications),
amplifying the write load per expense event.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/cloud-functions-catalogue.md` -- sections 1-3 (transaction semantics, retry policies).
- `docs/design/07-technical/offline-and-sync.md` -- section 3.3 (queued write replay behaviour).
- `docs/design/07-technical/test-design.md` -- section 4.9 (CUJ-9: large-data performance test with 10-member group and 55+ expenses).

---

### R-05: Account deletion and DPDP compliance miss

**Has the design phase strengthened or weakened the mitigation?**
Strengthened. The cloud functions catalogue specifies the `onUserDelete` function
(function 4) which handles data anonymisation and cleanup. The Firestore schema
confirms that user documents are scoped to `users/{userId}` with a strict
owner-only security rule, making the deletion surface area well defined. The test
design includes CUJ-10, a full end-to-end integration test for account deletion
that verifies data anonymisation, Auth record removal, and the zero-balance
pre-condition guard.

**New information from the design that changes likelihood or impact?**
The activity feed design (`firestore-schema.md`, `activity/{userId}/items/{itemId}`)
introduces per-user activity documents that must also be cleaned up during account
deletion. The extension points register (`07-technical/extension-points-register.md`)
includes ARCH-EXT-06 (settlement verification status), a server-only field that
must also be considered during data purge. These increase the scope of the deletion
function beyond the original estimate.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/cloud-functions-catalogue.md` -- section 4 (onUserDelete).
- `docs/design/07-technical/firestore-schema.md` -- `activity/{userId}/items/{itemId}` collection.
- `docs/design/07-technical/firestore-security-rules.md` -- user document delete denied to clients.
- `docs/design/07-technical/test-design.md` -- section 4.10 (CUJ-10: account deletion integration test).

---

### R-06: Bug in simplified-debts algorithm

**Has the design phase strengthened or weakened the mitigation?**
Substantially strengthened. This is the risk with the highest blast radius in the
system, and the design phase has provided the most thorough mitigation of any risk.

The simplified-debts algorithm specification (`07-technical/simplified-debts-algorithm.md`)
provides six fully worked examples (empty, single member, perfectly balanced, cyclic
to zero, three-person canonical, five-person flat-share) with step-by-step
intermediate state shown at every pairing iteration. The determinism rule (section 3)
is rigorously specified with a concrete tie-breaking example.

The test design document mandates 100% branch coverage of the canonical test matrix
(10 test cases: SD-01 through SD-10) with five verification rules applied to every
case. The cloud functions catalogue confirms the function is a pure, side-effect-free
module that is independently unit-testable, and that an invariant violation (non-zero
net-balance sum) triggers a hard failure with logging.

**New information from the design that changes likelihood or impact?**
The offline-and-sync design reveals that multiple concurrent recomputations may occur
during write replay (section 3.3). However, idempotency and transactional execution
ensure convergence. The CUJ-9 performance test (section 4.9 of test-design.md)
validates correctness with 10 members and 55+ expenses, providing confidence at
moderate scale.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/simplified-debts-algorithm.md` -- complete algorithm specification with 6 worked examples, determinism rule, and error semantics.
- `docs/design/07-technical/cloud-functions-catalogue.md` -- section 1 (recomputeSimplifiedBalances: idempotency, invariant validation, error handling).
- `docs/design/07-technical/test-design.md` -- section 2.3 (100% branch coverage target), section 3 (canonical test matrix SD-01 to SD-10), section 3.3 (5 verification rules).

---

### R-07: No mail client on user device

**Has the design phase strengthened or weakened the mitigation?**
Strengthened. The test design document includes CUJ-12 (section 4.12) which
explicitly tests both the happy path (mailto intent fires) and the fallback path
(no mail client -- fallback dialog with "Copy" button appears). The telemetry plan
includes a `support_email_opened` event with a `method` parameter distinguishing
`mailto` from `fallback_dialog`, providing production observability into how often
the fallback is triggered.

**New information from the design that changes likelihood or impact?**
No significant new information. The risk remains low impact and moderate likelihood.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/test-design.md` -- section 4.12 (CUJ-12: Contact Support integration test).
- `docs/design/07-technical/telemetry-plan.md` -- section 1.1 (`support_email_opened` event).

---

### R-08: Phone Auth quota consumed during testing

**Has the design phase strengthened or weakened the mitigation?**
Unchanged. The design phase does not introduce new technical measures beyond those
already specified in the sprint-zero register (Auth Emulator for all test runs,
pre-test reachability check). The test design document confirms that CUJ-1 uses the
Auth Emulator, which is consistent with the original mitigation but does not extend
it.

**New information from the design that changes likelihood or impact?**
No new information. The risk remains medium impact, medium likelihood, and is
primarily a DevOps configuration concern that will be addressed during CI pipeline
implementation.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/test-design.md` -- section 4.1 (CUJ-1 setup specifies Auth Emulator).

---

### R-09: Firebase Dynamic Links sunset

**Has the design phase strengthened or weakened the mitigation?**
Strengthened. The notifications design (`07-technical/notifications.md`, section 4)
specifies a deep-link map that uses route-based navigation (`/group/:contextId`,
`/friend/:contextId`, `/invite/group/:inviteToken`) rather than Firebase Dynamic
Links. The entity-not-found fallback table (section 4.2) provides graceful
degradation for every deep-link target. The CUJ-11 integration test (test-design.md,
section 4.11) verifies that shared invite links contain a universal link (iOS) or
App Link (Android), not a Firebase Dynamic Link.

**New information from the design that changes likelihood or impact?**
The deep-link resolution logic described in the notifications design (section 3.3
and section 4.1) introduces a cold-start flow: splash, auth guard, then deep-link
replay. This complexity is independent of the Dynamic Links sunset but confirms that
the invite flow has been designed around platform-native linking rather than
Firebase Dynamic Links. The likelihood of this risk materialising is reduced because
the design does not depend on the deprecated service.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/notifications.md` -- section 4 (deep-link map), section 4.2 (entity-not-found fallback), section 3.3 (cold-start deep-link resolution).
- `docs/design/07-technical/test-design.md` -- section 4.11 (CUJ-11: share-sheet invite test asserting universal/App Links).

---

### R-10: Riverpod 2.x breaking changes

**Has the design phase strengthened or weakened the mitigation?**
Unchanged. The design phase does not finalise the Riverpod version constraint or
resolve ADR-0004. The state management design (`07-technical/state-management.md`)
references Riverpod providers but does not introduce additional coupling beyond
what was anticipated.

**New information from the design that changes likelihood or impact?**
The test design document specifies widget tests for all 28 screens (section 1.1),
each of which will exercise Riverpod provider interactions. This indirectly
strengthens the mitigation by ensuring that a Riverpod upgrade would be caught by
the existing test suite. However, this is a consequence of general test coverage
rather than a targeted mitigation.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/state-management.md` -- Riverpod provider architecture.
- `docs/design/07-technical/test-design.md` -- section 1.1 (widget tests required for all screens).

---

### R-11: App Check enforcement blocking emulator traffic

**Has the design phase strengthened or weakened the mitigation?**
Unchanged. The design phase does not address App Check configuration. This remains
a DevOps concern to be resolved during CI pipeline setup.

**New information from the design that changes likelihood or impact?**
The security rules design (`07-technical/firestore-security-rules.md`) introduces
detailed per-collection, per-field access rules. If App Check is enabled at the
project level and debug tokens are misconfigured, all emulator-based security rules
tests (which the test design mandates at 100% coverage) would fail. This slightly
increases the impact of misconfiguration but does not change the likelihood.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/firestore-security-rules.md` -- comprehensive rule set that must be testable against emulators.
- `docs/design/07-technical/test-design.md` -- section 5 (security rules test matrix requiring 100% rule coverage).

---

### R-12: CI pipeline flakiness from emulator startup timing

**Has the design phase strengthened or weakened the mitigation?**
Unchanged. The design phase does not introduce new CI pipeline configuration. The
mitigation remains as specified in the sprint-zero register (readiness-check step,
startup timeout, binary caching, flake-rate tracking).

**New information from the design that changes likelihood or impact?**
The test design document specifies 12 integration tests, all requiring the Firebase
Emulator Suite with multiple services (Auth, Firestore, Functions). The breadth of
emulator-dependent tests increases the surface area for flakiness. CUJ-7 (offline
sync) additionally calls `disableNetwork()` and `enableNetwork()` on the Firestore
instance, which introduces timing-sensitive state transitions that may amplify flake
risk.

**Specific design artefacts that address the risk:**
- `docs/design/07-technical/test-design.md` -- sections 4.1 through 4.12 (all 12 CUJ integration tests specifying emulator service dependencies).
- `docs/design/07-technical/offline-and-sync.md` -- section 6 (emulator-based offline tests with network toggling).

---

## New Risks Identified During Design

### R-13: Complexity of the five split methods

**Description:** The Firestore schema supports five split methods: `equal`,
`unequal`, `percentage`, `shares`, and `exact`. The `percentage` and `shares`
methods require conversion to integer paise, which necessitates a rounding strategy
to ensure the sum of splits equals the expense total exactly. An off-by-one paise
remainder after rounding would violate Invariant 1 and would be rejected by the
Firestore security rules (which validate `sum(splits[*].sharePaise) == amountPaise`).

**Impact:** Medium. Incorrect rounding would prevent users from saving expenses with
percentage or shares splits. If the validation is bypassed, it would produce incorrect
balances.

**Likelihood:** Medium. Rounding logic is inherently error-prone with integer
arithmetic.

**Mitigation:** The split calculation engine is listed in the test design (section
1.3) as requiring unit tests. The CUJ-2 and CUJ-3 integration tests exercise equal
and unequal splits. However, no canonical test case currently exercises the
`percentage` or `shares` split methods end-to-end. A dedicated test case for each
of the five methods -- including edge cases with prime-number totals and indivisible
percentages -- should be added to the test matrix.

**Relevant artefacts:**
- `docs/design/07-technical/firestore-schema.md` -- `splitMethod` field and `splits` array definition.
- `docs/design/07-technical/firestore-security-rules.md` -- splits-sum validation.
- `docs/design/07-technical/test-design.md` -- section 1.3 (split calculation engine unit tests).

---

### R-14: Deep-link resolution complexity (cold start + auth guard + entity-not-found fallback)

**Description:** The notification and deep-link design (`07-technical/notifications.md`,
sections 3.3 and 4) describes a multi-step resolution flow for cold-start deep links:
the app launches, displays splash, restores auth session, evaluates the auth guard,
replays the stored deep-link intent, fetches the target entity from Firestore, and
falls back to a per-entity-type destination if the entity is not found. This flow
involves at least four asynchronous operations in sequence with branching at each
stage.

**Impact:** Medium. A bug in deep-link resolution would cause users tapping
notifications to land on the wrong screen or see an unhandled error, degrading trust
in notifications.

**Likelihood:** Medium. The number of asynchronous steps and branching paths creates
significant surface area for race conditions and state management errors.

**Mitigation:** CUJ-6 in the test design (section 4.6) covers push notification
deep-links including the cold-start path and the entity-not-found negative case.
The entity-not-found fallback table in the notifications design provides six
explicit fallback routes. However, the interaction between deep-link replay and the
GoRouter auth guard is a complex stateful sequence that warrants additional negative
test cases (e.g., deep-link with expired auth session, deep-link during active
sign-in flow, deep-link with malformed payload).

**Relevant artefacts:**
- `docs/design/07-technical/notifications.md` -- sections 3.3 (cold-start resolution), 4.1 (resolution logic), 4.2 (entity-not-found fallback).
- `docs/design/07-technical/test-design.md` -- section 4.6 (CUJ-6: push notification and deep-link integration test).

---

### R-15: Telemetry volume -- approximately 150 events may need throttling or sampling

**Description:** The telemetry plan (`07-technical/telemetry-plan.md`) defines
approximately 148 distinct analytics events across all screens and flows. Firebase
Analytics has a limit of 500 distinct event types per project (well within range)
but imposes a limit of 25 unique event parameters per event type and a maximum of
50 custom dimensions per project. At high user volumes, the raw event throughput
may also incur BigQuery export costs if all events are exported.

**Impact:** Low. Firebase Analytics handles high event volumes without client-side
performance degradation. The primary risk is cost and analytics noise rather than
functional failure.

**Likelihood:** Low in v1.0 (small initial user base), increasing post-launch.

**Mitigation:** The telemetry plan separates events by screen and flow, making it
straightforward to identify low-value events for removal or sampling. No throttling
or sampling mechanism is currently designed. A review of event utility should occur
after the first month of production data, with events that have fewer than 100
occurrences per month candidates for removal.

**Relevant artefacts:**
- `docs/design/07-technical/telemetry-plan.md` -- full event catalogue (approximately 148 events across 8 sections).

---

### R-16: Accessibility compliance gap -- five screen-reader walkthroughs identified but not yet tested on real devices

**Description:** The accessibility specification (`07-technical/accessibility-spec.md`)
defines five detailed screen-reader walkthroughs covering first-time sign-up,
add expense, settle up, notifications, and account deletion flows. Each walkthrough
specifies exact focus order, announcements, and live-region behaviour for both
VoiceOver (iOS) and TalkBack (Android). However, these walkthroughs are design
specifications only; they have not been validated on physical devices with actual
screen readers.

**Impact:** Medium. Screen-reader behaviour varies between platform versions and
device manufacturers. Focus-order bugs, missing semantics labels, and live-region
timing issues are common and are only reliably detected through manual testing on
real hardware.

**Likelihood:** High. Accessibility specifications rarely survive first contact with
real screen readers without adjustment.

**Mitigation:** CUJ-8 (dark mode legibility) in the test design includes WCAG
contrast verification but does not cover screen-reader interaction. No integration
test or manual smoke test currently validates screen-reader walkthroughs. A manual
accessibility testing pass on at least one iOS device (VoiceOver) and one Android
device (TalkBack) should be added to the release readiness checklist (SRS section
11). The five walkthroughs in the accessibility specification should serve as the
test script.

**Relevant artefacts:**
- `docs/design/07-technical/accessibility-spec.md` -- section 2 (five screen-reader walkthroughs with focus order and announcement tables).
- `docs/design/07-technical/test-design.md` -- section 4.8 (CUJ-8: dark mode test, covers contrast but not screen-reader flows).

---

## Mitigation Confidence Summary

| Risk ID | Risk (short) | Mitigation Confidence | Next Action |
|---------|-------------|----------------------|-------------|
| R-01 | Single-environment Firebase | Medium | Verify all 12 CUJ integration tests pass against the Emulator Suite before Sprint 1 closes. Confirm telemetry event pipeline is operational for post-release monitoring. |
| R-02 | SMS OTP cost / quota | Medium | Implement OTP telemetry events in Sprint 1. Set budget alerts in Google Cloud before launch. |
| R-03 | Floating-point money errors | High | Implement Firestore security rules validation for `splits` sum. Run SD-08 (float rejection) test case in Sprint 1. |
| R-04 | Hot documents on group balances | Medium | Monitor Firestore write contention metrics during CUJ-9 performance test. Document sharded-counter fallback plan. |
| R-05 | Account deletion / DPDP | Medium | Ensure `onUserDelete` function handles `activity/{userId}/items` cleanup. Schedule legal review before launch. |
| R-06 | Simplified-debts algorithm bug | High | Achieve 100% branch coverage of SD-01 through SD-10 in Sprint 1. Gate all PRs on canonical test matrix. |
| R-07 | No mail client on device | High | Implement and test fallback dialog in Sprint 1 (CUJ-12). No further action needed. |
| R-08 | Auth quota consumed in testing | Medium | DevOps to verify Auth Emulator reachability check is present in CI pipeline configuration. |
| R-09 | Dynamic Links sunset | Medium | Confirm CUJ-11 asserts universal/App Links (not Dynamic Links). Track Google deprecation timeline quarterly. |
| R-10 | Riverpod 2.x breaking changes | Medium | Finalise and approve ADR-0004 before writing provider code. Lock version in `pubspec.yaml`. |
| R-11 | App Check blocking emulator traffic | Medium | DevOps to configure debug tokens during CI pipeline setup. Test against security rules suite. |
| R-12 | CI pipeline flakiness | Medium | Implement emulator readiness-check step. Track flake rate from first CI run. |
| R-13 | Five split methods complexity | Low | Add dedicated unit tests for `percentage` and `shares` split methods with indivisible amounts. Add integration test case for each split method. |
| R-14 | Deep-link resolution complexity | Low | Add negative test cases to CUJ-6: expired auth, concurrent sign-in, malformed payload. |
| R-15 | Telemetry volume | Medium | Review event utility after first month of production data. Document BigQuery export cost baseline. |
| R-16 | Accessibility compliance gap | Low | Add manual screen-reader testing (VoiceOver + TalkBack) to the release readiness checklist. Execute walkthroughs before launch. |

---

## Summary

The design phase has materially strengthened the mitigations for 7 of the 12
original risks, with the most significant improvements in R-03 (floating-point
money errors) and R-06 (simplified-debts algorithm bug), both of which now have
detailed specifications, worked examples, canonical test matrices, and invariant
validation at the Cloud Function layer.

Four risks (R-08, R-10, R-11, R-12) remain unchanged because their mitigations are
primarily DevOps and tooling concerns that will be addressed during CI pipeline
implementation rather than during the design phase.

One risk (R-04, hot documents) has gained new information from the offline-and-sync
design that slightly increases its likelihood, warranting closer monitoring during
performance testing.

Four new risks (R-13 through R-16) have been identified. Of these, R-16
(accessibility compliance gap) has the highest likelihood and should be prioritised
for action before the v1.0 launch.