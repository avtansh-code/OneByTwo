# Test Strategy

Distilled from the SRS (sections 5.7, 10). This file is the authoritative reference
for QA, developer, and DevOps agents when writing or reviewing tests.

---

## Test Pyramid

| Level | Tooling | Coverage target | Owner |
|---|---|---|---|
| Flutter unit/widget tests | `flutter test` via FVM Flutter 3.44.2, `flutter_test`, `flutter_riverpod` `ProviderScope` overrides, hand-written fakes, `fake_async` where timers are involved | Every feature/module >= 70%; overall Flutter >= 50% | Flutter Dev |
| Functions unit/property tests | `cd functions && npm test` (Jest + `ts-jest`, dependency-injected mock Firestore/logger, `fast-check` property tests) | Every Functions module >= 70%; overall Functions >= 50% | Functions Dev |
| Security rules tests | `cd functions && npm run test:rules` (`@firebase/rules-unit-testing`, `jest.rules.config.js`, `maxWorkers: 1`) | Positive and negative coverage for rule paths and invariants | Architect, QA |
| Emulator integration tests | `cd functions && npm run test:integration` under `firebase emulators:exec --project demo-onebytwo` | Executable critical server journeys | QA, Functions Dev |
| Flutter flow stubs | `test/integration/**` with `@Tags(['integration'])`; currently skipped stubs, not an `integration_test/` package directory | Tracked until an executable Flutter emulator harness lands | QA, Flutter Dev |
| Manual smoke tests | Real devices (Tier 1 matrix) | Pre-release sign-off | QA |

Repository conventions:

- Flutter tests live under `test/**` mirroring `lib/**`; there are roughly 115
  `*_test.dart` files and roughly 1,290 test cases. The style is
  `flutter_test` plus Riverpod overrides and hand-written fakes. Do not introduce
  `mocktail`, `mockito`, or `golden_toolkit`.
- There is no `@riverpod` code generation in `lib/**`.
- Functions unit tests currently pass as 22 suites / 319 tests. The unused
  `firebase-functions-test` dev dependency remains in `functions/package.json`
  but is not the test pattern.
- Boundary-contract grep tests enforce invariants 1 and 2 at
  `test/features/<name>/*_boundary_contract_test.dart` and
  `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`.
- Emulator ports: Auth 9099, Firestore 8181, Functions 5001, Storage 9199,
  Emulator UI 4000. Local wrapper: `scripts/dev/start-emulators.sh`.
- CI uses `firebase emulators:exec ... --project demo-onebytwo`.
- `test:canonical` (`jest --forceExit test/simplified-debts`) is defined in
  `functions/package.json` (added in PR #59) and runs the simplified-debts
  canonical matrix; it is referenced by workflows and docs.

---

## Coverage Thresholds (CI-enforced)

- Per Flutter feature and per Functions module: **>= 70%** line coverage.
- Overall Flutter and overall Functions coverage: **>= 50%**.
- `flutter-checks` fails if aggregate `coverage/lcov.info` is below 50%.
- `coverage-gate` enforces per-feature/module >= 70% and overall >= 50%.
- Lefthook pre-push runs the scoped >= 70% check on touched folders.
- Simplified-debts branch coverage is **advisory**. The canonical/property/
  integration matrix is the authoritative quality check, not a hard 100%
  Istanbul branch gate.

---

## Simplified Debts — Canonical Test Matrix

The real implementation lives in `functions/src/simplified-debts/{algorithm,function}.ts`
and exports `simplifyDebts`, `projectToBalancesMap`, `computeNetBalances`,
`recomputeAndWrite`, and `createHandler`. The algorithm throws on a non-zero
balance sum; it does not reject floats itself.

| Case | Description | Expected outcome |
|---|---|---|
| Empty | No expenses, no settlements. | `simplifiedBalances` is empty or all zeroes. |
| Single member | One member with a zero net balance. | No debts; balances are zero. |
| Perfectly balanced | All members paid equally. | No debts; balances are zero. |
| Cyclic to zero | A owes B, B owes C, C owes A — net zero. | `simplifiedBalances` is empty. |
| 3-person canonical | A is +40000 paise; B and C are -20000 each. | B owes A 20000; C owes A 20000. |
| 5-person canonical | A is the single creditor; B, C, D, and E are debtors. | B owes A 800000; C owes A 900000; D owes A 1100000; E owes A 1100000. |
| Balance invariant | Net balances do not sum to zero. | `simplifyDebts` throws a balance invariant violation. |
| Settlement folding | Expenses and top-level settlements are folded by `computeNetBalances`. | Settlements reduce debts while preserving zero sum. |
| `alsoSet` guard | Caller attempts to pass reserved `simplifiedBalances` through `alsoSet`. | `recomputeAndWrite` rejects the reserved key. |
| Property tests | Random valid balances and mixed expense/settlement sequences via `fast-check`. | Transfer count, determinism, positive integer amounts, and zero-sum properties hold. |
| Emulator integration | Admin SDK writes against the Firestore emulator. | Persisted `simplifiedBalances` matches the response. |

---

## Critical User Journeys (Must-Pass in Integration)

Executable emulator integration tests are Functions-side in
`functions/test/integration/*.integration.test.ts`. Flutter flow tests live under
`test/integration/<feature>/` and are skipped stubs tagged `@Tags(['integration'])`.
There is no `integration_test/` package directory.

Current client features are: activity, auth, expenses, friends, notifications,
profile, reminders, settlements, and shell. `lib/features/groups/` contains only
README/.gitkeep; group schema/rules exist server-side and the shell contains a
placeholder.

---

## Device and OS Coverage Matrix

| Tier | iOS | Android |
|---|---|---|
| Tier 1 (must pass) | iPhone 12, iPhone 14 (iOS 17) | Pixel 6 (Android 14), Samsung Galaxy A-series (Android 13) |
| Tier 2 (should pass) | iPhone SE 2nd gen (iOS 14) | Xiaomi Redmi (Android 11), low-end OEM (Android 8) |
| Tier 3 (best effort) | iPad portrait (post-v1.0) | Tablets (post-v1.0) |

---

## Non-Functional Testing

- **Performance:** cold-start, scroll FPS, memory — profiled with Flutter DevTools.
  Targets: cold start <= 3 s (P95), warm start <= 1 s, dashboard render <= 1.5 s.
- **Security:** Firestore rules tested with the rules-unit-testing emulator, including
  negative cases (client writing `simplifiedBalances` must be rejected).
- **Accessibility:** VoiceOver and TalkBack walkthroughs of all primary flows.
- **Localisation:** pseudolocalisation pass to catch hardcoded strings.

---

## Bug Severity Definitions

| Severity | Definition | SLA |
|---|---|---|
| S1 — Critical | Crash on launch, core flow blocked, data loss, wrong simplified balances. | Same-day hotfix. |
| S2 — Major | Feature broken, no workaround, affects many users. | Within 3 business days. |
| S3 — Minor | Feature broken with workaround; cosmetic but visible. | Next sprint. |
| S4 — Trivial | Polish, copy, edge-case visual. | Backlog. |
