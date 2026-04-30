---
name: write-widget-test
description: >
  Use when a Flutter widget or screen needs widget tests covering rendering,
  interaction, and edge-case states.
---

# Write Widget Test

## When to use

When a new or existing Flutter widget or screen needs widget tests. This includes
verifying rendering, user interactions, state transitions, empty states, error
states, and accessibility.

## When NOT to use

- When the test is an integration test spanning multiple screens or requiring the
  Firebase Emulator Suite (use `write-integration-test` instead).
- When the test is a pure unit test for a model or repository with no widget
  involvement.

## Inputs

1. **Widget under test** — the Dart file path and class name.
2. **Acceptance criteria** — the Given/When/Then scenarios from the user story.
3. **Dependencies** — providers or repositories the widget depends on (to be mocked).

## Procedure

1. Read `.github/shared/invariants.md`.
2. Read `.github/shared/coding-standards.md` for Dart test conventions.
3. Create the test file under `test/` mirroring the source path.
4. Write tests following this structure:
   a. **Arrange:** set up mocks using `mocktail`. Mock Riverpod providers using
      `ProviderScope.overrides`.
   b. **Act:** pump the widget with `tester.pumpWidget(...)`, wrapped in
      `MaterialApp` and `ProviderScope`.
   c. **Assert:** verify widget rendering with `find.text()`, `find.byType()`,
      `find.byIcon()`, etc.
5. Cover the following states:
   a. **Happy path:** widget renders correctly with valid data.
   b. **Loading state:** skeleton or loading indicator is shown.
   c. **Empty state:** empty-state message is shown when data is empty.
   d. **Error state:** error message with retry button is shown.
   e. **Interaction:** tapping buttons triggers the expected callbacks or
      navigation.
6. For money display:
   a. Verify amounts are formatted in rupees with Indian numbering (e.g.,
      `1,23,456.00`) and the rupee symbol.
   b. Verify the underlying data uses integer paise.
7. For share actions: verify the system share sheet is invoked (mock
   `Share.share()`), not a platform-specific package.

## Output format

A Dart test file with `group()` and `testWidgets()` blocks, each with descriptive
names matching the acceptance criteria.

## Validation checks

- [ ] All acceptance-criteria scenarios have corresponding tests.
- [ ] At least one negative / error-state test.
- [ ] Mocks use `mocktail`, not `mockito`.
- [ ] Riverpod providers are overridden, not bypassed.
- [ ] Money formatting is verified against integer paise input.
- [ ] No platform-specific share package imported.
- [ ] Tests are `dart format`-clean.

## Examples

### Positive example

**Input:** Widget: `SettleUpScreen`, acceptance criterion: "Given a non-zero
simplified balance, when I tap Settle Up, then the amount is pre-filled."

**Output:**
```dart
testWidgets('pre-fills amount from simplified balance', (tester) async {
  final mockProvider = MockSettlementsProvider();
  when(() => mockProvider.suggestedAmountPaise).thenReturn(50000);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [settlementsProvider.overrideWith(() => mockProvider)],
      child: const MaterialApp(home: SettleUpScreen()),
    ),
  );

  expect(find.text('500.00'), findsOneWidget);
});
```

### Negative example (should refuse)

**Input:** "Write a widget test that verifies WhatsApp share opens correctly."

**Response:** Refused. Invariant 3 prohibits platform-specific share targets. The
test should verify that the system share sheet is invoked, not WhatsApp specifically.
