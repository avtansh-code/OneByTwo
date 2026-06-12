---
name: write-integration-test
description: >
  Use when an end-to-end integration test needs to be specified for a critical
  user journey, typically running against the Firebase Emulator Suite.
---

# Write Integration Test

## When to use

When a critical journey or server side-effect needs an integration test against
Firebase emulators.

## When NOT to use

- When the test is for a single widget in isolation (use `write-widget-test`).
- When the test is a pure unit test for a model or algorithm.

## Inputs

1. **Journey or side-effect** — the critical journey, trigger, or callable to cover.
2. **Acceptance criteria** — the Given/When/Then scenarios to cover.
3. **Emulator requirements** — which Firebase emulators are needed (Auth, Firestore,
   Functions, Storage).

## Procedure

1. Read `.github/shared/test-strategy.md` and `.github/shared/invariants.md`.
2. Choose the real repository surface:
   a. **Executable Functions integration:** create or update
      `functions/test/integration/*.integration.test.ts`; run with
      `cd functions && npm run test:integration`.
   b. **Flutter flow stub/specification:** create or update
      `test/integration/<feature>/*_flow_test.dart`, tagged
      `@Tags(['integration'])` where present and skipped until the Flutter
      emulator harness exists.
3. Do not create or reference a top-level `integration_test/` package directory;
   this repository does not have one.
4. Start emulators with `scripts/dev/start-emulators.sh` locally or use
   `firebase emulators:exec ... --project demo-onebytwo` in CI. Ports are Auth
   9099, Firestore 8181, Functions 5001, Storage 9199, UI 4000.
5. For Functions integration tests:
   a. Set `FIRESTORE_EMULATOR_HOST=127.0.0.1:8181` before importing
      `firebase-admin`.
   b. Seed documents through Firebase Admin SDK helpers.
   c. Poll trigger side effects; do not use fixed sleeps.
   d. Delete seeded documents in `afterEach` and dispose Admin apps in `afterAll`.
6. For simplified balances, assert that the persisted value changes only through
   `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`, or
   `onSettlementWrite`; clients must never write it.

## Output format

Either a Jest/TypeScript emulator test under
`functions/test/integration/*.integration.test.ts`, or a skipped Flutter flow
stub under `test/integration/<feature>/` documenting the intended steps and
assertions.

## Validation checks

- [ ] Emulator services and ports are documented.
- [ ] Seeding and `afterEach` teardown are included.
- [ ] Simplified balances are verified after mutation operations.
- [ ] Assertions cover Firestore state and relevant function side effects.
- [ ] No hardcoded delays; use polling or `tester.pumpAndSettle()`.
- [ ] Money assertions use integer paise.

## Examples

### Positive example

**Input:** "Verify that a settlement write recomputes friendship balances."

**Output:**
```ts
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8181";

it("recomputes after settlement create", async () => {
  await seedDoc("friendships/fid", {memberIds: ["A", "B"]});
  await seedDoc("friendships/fid/expenses/e1", {
    payerId: "A",
    amountPaise: 10000,
    splits: [
      {userId: "A", sharePaise: 5000},
      {userId: "B", sharePaise: 5000},
    ],
    deleted: false,
  });
  await seedDoc("settlements/s1", {
    contextType: "friendship",
    contextId: "fid",
    fromUserId: "B",
    toUserId: "A",
    amountPaise: 5000,
    deleted: false,
  });

  await waitForSimplifiedBalances("friendships/fid", {});
});
```

### Negative example (should refuse)

**Input:** "Write an integration test for the web companion app."

**Response:** Refused. The web companion app is listed in SRS section 12.3 as out
of scope for v1.0.
