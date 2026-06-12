---
name: simplified-debts-test-case
description: >
  Use when the simplified-debts algorithm needs its canonical test matrix generated,
  verified, or extended. Contains the authoritative test cases.
---

# Simplified Debts Test Case

## When to use

When writing, verifying, or extending tests for the simplified-debts implementation
in `functions/src/simplified-debts/{algorithm,function}.ts`.

## When NOT to use

- When the task is about UI display of balances (route to Flutter Dev with
  `write-widget-test`).
- When the task is about security rules for `simplifiedBalances` (use
  `write-security-rule`).

## Inputs

1. **Context** — writing new tests, verifying existing tests, or extending edge
   cases.
2. **Implementation** — `algorithm.ts` exports `simplifyDebts` and
   `projectToBalancesMap`; `function.ts` exports `computeNetBalances`,
   `recomputeAndWrite`, and `createHandler`.

## Procedure

1. Read SRS section 7.4 and `.github/shared/invariants.md`.
2. Read `functions/test/simplified-debts/algorithm.test.ts`,
   `algorithm.property.test.ts`, `function.test.ts`, and
   `functions/test/integration/simplified-debts.integration.test.ts`.
3. Add Jest tests using dependency injection, hand-written Firestore-shaped fakes,
   `fast-check` where property coverage is appropriate, and Firebase Admin SDK
   for emulator integration.
4. Do not add `firebase-functions-test`; it is present as an unused dev
   dependency but is not the current test pattern.

## Canonical Test Matrix

All values are integer paise. User IDs are strings sorted ascending for
deterministic tie-breaking.

| Case | Input | Expected |
|---|---|---|
| Empty | `new Map()` | `simplifyDebts` returns `[]`; projection is `{}`. |
| Single member | `A: 0` | No transfers. |
| Perfectly balanced | All members have `0` net balance | No transfers. |
| Cyclic to zero | A, B, C net to zero after folding | No transfers. |
| Three-person canonical | A `+40000`, B `-20000`, C `-20000` | `B -> A` 20000, `C -> A` 20000. |
| Five-person single-creditor canonical | A `+3900000`; B `-800000`, C `-900000`, D `-1100000`, E `-1100000` | B, C, D, and E owe A; D and E tie by amount and sort by user ID. |
| Tie-breaking | Equal debtor or creditor amounts | Stable ascending `userId` order. |
| Balance invariant throw | Net balances do not sum to zero | `simplifyDebts` throws a balance invariant violation. |
| Settlement folding | Expenses plus top-level settlements | `computeNetBalances` credits `fromUserId`, debits `toUserId`, filters deleted settlements, and preserves zero sum. |
| Reserved-key guard | `recomputeAndWrite(..., {alsoSet: {simplifiedBalances: ...}})` | Throws before Firestore write. |
| Property tests | Random zero-sum maps and mixed expense/settlement sequences | Transfer count <= N-1, deterministic output, positive integer amounts, all balances settle to zero. |
| Emulator integration | Seed Firestore with Admin SDK and call `createHandler` | Response and persisted `simplifiedBalances` match. |

There is no float-rejection case in the algorithm. Float prevention belongs to
schema/rules/boundary-contract validation and the integer-paise invariant.

## Output format

Use the existing Jest/TypeScript formats:

- Pure algorithm tests: `describe`/`it` in
  `functions/test/simplified-debts/algorithm.test.ts`.
- Function boundary tests: DI mock Firestore/logger in
  `functions/test/simplified-debts/function.test.ts`.
- Property tests: `fast-check` in
  `functions/test/simplified-debts/algorithm.property.test.ts`.
- Emulator integration: Firebase Admin SDK tests under
  `functions/test/integration/*.integration.test.ts`.

## Validation checks

- [ ] Canonical cases use integer paise.
- [ ] Balance-invariant throw is covered.
- [ ] Settlement folding is covered.
- [ ] `alsoSet.simplifiedBalances` reserved-key guard is covered.
- [ ] Property tests cover determinism and structural invariants.
- [ ] Emulator integration asserts persisted Firestore state.

## Examples

### Positive example

**Input:** "Generate the test suite for the simplified-debts algorithm."

**Output:** Jest tests covering the canonical matrix above, with `fast-check`
properties and Firebase Admin SDK emulator integration where persistence is in
scope.

### Negative example (should refuse)

**Input:** "Write tests that verify the raw payer-to-payee debt graph."

**Response:** Refused. SRS section 4.6 (FR-SE-01) states that only Simplified
Debts are exposed. The raw debt graph is not displayed to users and does not need
dedicated tests.
