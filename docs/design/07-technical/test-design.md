# Test Design — Coverage Plan

**Document owner:** QA Engineer
**Status:** Draft
**SRS version:** 1.1
**Last updated:** 2026

---

## 1. Current Test Layout

This section reflects the repository as implemented.

| Surface | Location | Command | Framework and pattern | Current scale |
|---|---|---|---|---|
| Flutter unit/widget tests | `test/**`, mirroring `lib/**` | `flutter test` (FVM Flutter 3.44.2) and CI `flutter test --coverage` | `flutter_test`, `flutter_riverpod` `ProviderScope` overrides, hand-written fakes, `fake_async` for timers | Approximately 115 `*_test.dart` files and approximately 1,290 tests |
| Flutter flow stubs | `test/integration/<feature>/*_flow_test.dart` | CI runs `flutter test test/integration/ --timeout 300s` under emulators | Tagged with `@Tags(['integration'])` where present; concrete flows are currently skipped stubs | Not an executable CUJ suite yet |
| Functions unit/property tests | `functions/test/**` excluding `test/integration`, plus `functions/src/__tests__` | `cd functions && npm test` | Jest + `ts-jest`, dependency-injected mock Firestore/logger, `fast-check` property tests | 22 suites / 319 tests |
| Rules tests | `functions/test/firestore-rules/*.test.ts` and `functions/test/storage-rules/*.test.ts` | `cd functions && npm run test:rules` | `@firebase/rules-unit-testing`, `jest.rules.config.js`, `maxWorkers: 1` | 9 rules suites |
| Functions emulator integration | `functions/test/integration/*.integration.test.ts` | `cd functions && npm run test:integration` inside `firebase emulators:exec` | Firebase Admin SDK against the Firestore/Functions emulators with explicit seeding and `afterEach` cleanup | 4 emulator suites |
| Boundary contracts | `test/features/<name>/*_boundary_contract_test.dart`, `functions/test/boundary-contracts/no-double-on-money-fields.test.ts` | Included in Flutter and Functions test commands | Grep-style invariant checks for integer paise and no client writes to `simplifiedBalances` | Cross-cutting invariant coverage |

There is **no** top-level `integration_test/` package directory. Flutter flow
tests deliberately live under `test/integration/` until an executable on-device
harness is added.

The `test:canonical` script is referenced by `.github/workflows/pr.yml`,
`.github/workflows/release.yml`, and documentation, but is not defined in
`functions/package.json`. Treat that as a known gap; do not claim it is a
working command until the script exists.

Emulators:

- Local wrapper: `scripts/dev/start-emulators.sh`.
- CI wrapper: `firebase emulators:exec ... --project demo-onebytwo`.
- Ports: Auth 9099, Firestore 8181, Functions 5001, Storage 9199, UI 4000.

CI job map:

- `pr-title-lint`: Conventional Commits PR title check.
- `flutter-checks`: `.firebaserc` single-project guard, `dart format
  --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test
  --coverage`, and aggregate lcov >= 50%.
- `functions-checks`: `npm run lint`, `npm test`.
- `integration-tests`: rules tests in a rules-only emulator session, then
  Flutter `test/integration/` plus `npm run test:integration` in the full
  emulator suite.
- `coverage-gate`: per Flutter feature and per Functions module >= 70%, overall
  Flutter and Functions >= 50%; simplified-debts branch coverage is advisory.

---

## 2. Test Pyramid Mapping

### 2.1 Live client features

The built Flutter feature set is: activity, auth, expenses, friends,
notifications, profile, reminders, settlements, and shell.

`lib/features/groups/` is not a built client feature; it contains only
README/.gitkeep. Group schema and rules exist server-side, and the shell exposes
a placeholder under `lib/features/shell/`.

### 2.2 Cloud Functions

| Target | Unit/property tests | Integration tests | Notes |
|---|---|---|---|
| `recomputeSimplifiedBalances` | `functions/test/simplified-debts/{algorithm,function,algorithm.property}.test.ts` | `functions/test/integration/simplified-debts.integration.test.ts` | Writes `simplifiedBalances` through `recomputeAndWrite`. |
| `onExpenseWriteFriendship` | `functions/test/triggers/on-expense-write/*.test.ts` | `functions/test/integration/on-expense-write.integration.test.ts` | Server writer of friendship `simplifiedBalances`. |
| `onSettlementWrite` | `functions/test/triggers/on-settlement-write/*.test.ts` | `functions/test/integration/on-settlement-write.integration.test.ts` | Server writer after settlement create/update/delete. |
| `lookupUserByPhoneNumber` | `functions/test/lookup-user-by-phone-number/*.test.ts` | `functions/test/integration/lookup-user-by-phone-number.integration.test.ts` | Callable lookup path. |
| `sendReminderNotification` and notifications helpers | `functions/test/send-reminder-notification/*.test.ts`, `functions/test/notifications/*.test.ts` | Covered through callable/unit surfaces today | Reads `simplifiedBalances`; does not write it. |

---

## 3. Coverage Targets

Derived from SRS section 5.7 and `.github/shared/test-strategy.md`.

| Scope | Required threshold | Enforcement |
|---|---:|---|
| Each Flutter feature in `lib/features/<name>/` | >= 70% line coverage | `coverage-gate`; lefthook pre-push for touched folders |
| Overall Flutter | >= 50% line coverage | `flutter-checks` and `coverage-gate` |
| Each Functions module in `functions/src/<module>/` | >= 70% line coverage | `coverage-gate` |
| Overall Functions | >= 50% line coverage | `coverage-gate` |
| Simplified-debts branches | Advisory metric | Reported by `coverage-gate`; not a hard 100% branch gate |

---

## 4. Simplified-Debts Canonical Test Matrix

Implementation paths are `functions/src/simplified-debts/algorithm.ts` and
`functions/src/simplified-debts/function.ts`. Exports include `simplifyDebts`,
`projectToBalancesMap`, `computeNetBalances`, `recomputeAndWrite`, and
`createHandler`.

`simplifyDebts` expects integer paise net balances and throws when the sum of
all balances is non-zero. It does not perform a float-rejection pass; integer
money is enforced by type, validation, security rules, and boundary-contract
tests.

| ID | Case | Expected outcome |
|---|---|---|
| SD-01 | Empty map | No transfers; projected `simplifiedBalances` is `{}`. |
| SD-02 | Single member with zero net balance | No transfers. |
| SD-03 | Perfectly balanced members | No transfers. |
| SD-04 | Cyclic debts that net to zero | No transfers after netting. |
| SD-05 | Three-person canonical: A +40000, B -20000, C -20000 | `B -> A` 20000 and `C -> A` 20000. |
| SD-06 | Five-person single-creditor case: A +3900000, B -800000, C -900000, D -1100000, E -1100000 | B, C, D, and E all owe A with deterministic debtor ordering for tied amounts. |
| SD-07 | Tie-breaking | Equal debtor/creditor amounts sort by ascending user ID. |
| SD-08 | Balance invariant violation | Non-zero net sum throws a balance invariant violation. |
| SD-09 | Settlement folding | `computeNetBalances` folds top-level settlements so repayments reduce debts. |
| SD-10 | Reserved `alsoSet` key | `recomputeAndWrite` rejects caller-supplied `alsoSet.simplifiedBalances`. |
| SD-11 | Property tests | `fast-check` verifies transfer count, determinism, positive integer amounts, and mixed expense/settlement zero-sum properties. |
| SD-12 | Emulator persistence | Admin SDK integration tests seed Firestore and assert persisted `simplifiedBalances`. |

---

## 5. Integration Test Suite

Executable emulator integration tests are currently Functions-side:

- `functions/test/integration/simplified-debts.integration.test.ts`
- `functions/test/integration/on-expense-write.integration.test.ts`
- `functions/test/integration/on-settlement-write.integration.test.ts`
- `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`

These tests set `FIRESTORE_EMULATOR_HOST=127.0.0.1:8181`, seed real Firestore
documents through Firebase Admin SDK, poll trigger side effects where necessary,
and delete created documents in `afterEach`.

Flutter flow specifications are kept as skipped stubs under `test/integration/`
for auth, expenses, friends, and settlements. They document intended CUJ
coverage, but they are not a substitute for the executable Functions emulator
integration suite.

---

## 6. Security Rules Tests

Rules tests run against the emulator with `@firebase/rules-unit-testing`:

- Firestore rules: `functions/test/firestore-rules/*.test.ts`
- Storage rules: `functions/test/storage-rules/*.test.ts`
- Config: `functions/jest.rules.config.js`
- Command: `cd functions && npm run test:rules`

Critical invariant coverage includes:

| ID | Test case | Expected |
|---|---|---|
| SR-INV-01 | Client writes `simplifiedBalances` on a friendship | Deny |
| SR-INV-02 | Client writes `simplifiedBalances` on a group | Deny |
| SR-INV-03 | Expense splits do not sum to `amountPaise` | Deny |
| SR-INV-04 | Monetary values are non-integers | Deny |
| SR-INV-05 | Non-participant reads protected friendship/group/expense data | Deny |

---

## 7. Device Matrix

Source: SRS section 10.3, `.github/shared/test-strategy.md`.

| Tier | iOS Devices | Android Devices |
|---|---|---|
| Tier 1 (must pass) | iPhone 12 (iOS 17), iPhone 14 (iOS 17) | Pixel 6 (Android 14), Samsung Galaxy A-series (Android 13) |
| Tier 2 (should pass) | iPhone SE 2nd generation (iOS 14) | Xiaomi Redmi (Android 11), low-end OEM device (Android 8) |
| Tier 3 (best effort) | iPad in portrait orientation (post-v1.0) | Tablets (post-v1.0) |

Minimum OS versions: iOS 14.0 and Android API 26 / Android 8.0.

---

## 8. Non-Functional Targets

| Metric | Target | SRS Reference |
|---|---:|---|
| Cold-start launch time | <= 3 s P95 | NFR-PE-01 |
| Warm-start launch time | <= 1 s P95 | NFR-PE-02 |
| Dashboard render time | <= 1.5 s P95 | NFR-PE-03 |
| Add-expense save round-trip | <= 2.5 s P95 | NFR-PE-04 |
| Firestore read latency | <= 400 ms P95 | NFR-PE-05 |
| App install size (Android) | <= 60 MB | NFR-PE-06 |
| App install size (iOS) | <= 90 MB | NFR-PE-06 |
| Crash-free user rate | >= 99.5% | SRS 5.3 |

---

*-- End of Document --*
