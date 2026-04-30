---
name: write-integration-test
description: >
  Use when an end-to-end integration test needs to be specified for a critical
  user journey, typically running against the Firebase Emulator Suite.
---

# Write Integration Test

## When to use

When a critical user journey (see `.github/shared/test-strategy.md`) needs an
integration test that spans multiple screens, interacts with Firebase services, or
requires the Emulator Suite.

## When NOT to use

- When the test is for a single widget in isolation (use `write-widget-test`).
- When the test is a pure unit test for a model or algorithm.

## Inputs

1. **User journey** — which of the 12 critical user journeys from the test strategy.
2. **Acceptance criteria** — the Given/When/Then scenarios to cover.
3. **Emulator requirements** — which Firebase emulators are needed (Auth, Firestore,
   Functions, Storage).

## Procedure

1. Read `.github/shared/test-strategy.md` for the critical user journeys list.
2. Read `.github/shared/invariants.md`.
3. Determine which Firebase emulators are required.
4. Specify the test outline:
   a. **Setup:** emulator configuration, seed data, authenticated test user.
   b. **Steps:** sequential user actions (tap, enter text, scroll, wait) mapped to
      the acceptance criteria.
   c. **Assertions:** verify UI state, Firestore document state, and Cloud Function
      side effects after each significant action.
   d. **Teardown:** clean up seed data.
5. For journeys involving simplified balances:
   a. Verify that after an expense or settlement, the `simplifiedBalances` field
      on the relevant document is updated (read from Firestore via emulator).
   b. Verify the client displays the updated balance without a manual refresh.
6. For offline journeys:
   a. Simulate network disconnection.
   b. Perform the action.
   c. Reconnect and verify sync and balance recomputation.
7. Write the test using the `integration_test` package.

## Output format

A Dart integration test file under `integration_test/` with descriptive step
comments and assertions matching each acceptance criterion.

## Validation checks

- [ ] Journey maps to one of the 12 critical user journeys in the test strategy.
- [ ] Emulator requirements are specified.
- [ ] Seed data setup and teardown are included.
- [ ] Simplified balances are verified after mutation operations.
- [ ] Assertions cover both UI state and Firestore document state.
- [ ] No hardcoded delays — use `tester.pumpAndSettle()` or polling.
- [ ] Money assertions use integer paise.

## Examples

### Positive example

**Input:** Journey 3: "Create a group of 4, add an expense with unequal split,
settle one member using the simplified-debts suggestion."

**Output:**
```dart
testWidgets('journey 3: group expense and settlement', (tester) async {
  // Setup: create 4 test users in Auth emulator, seed a group in Firestore.
  // Step 1: Navigate to Groups, tap Create Group, add 4 members.
  // Step 2: Add expense: 1000 paise, unequal split [400, 300, 200, 100].
  // Assert: simplifiedBalances updated on group document.
  // Step 3: Tap Settle Up for member with highest debt.
  // Assert: settlement recorded, balances recomputed.
  // Teardown: delete test data.
});
```

### Negative example (should refuse)

**Input:** "Write an integration test for the web companion app."

**Response:** Refused. The web companion app is listed in SRS section 12.3 as out
of scope for v1.0.
