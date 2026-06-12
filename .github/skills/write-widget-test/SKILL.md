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
3. **Dependencies** — providers or repositories the widget depends on (to be
   replaced with hand-written fakes through Riverpod overrides).

## Procedure

1. Read `.github/shared/invariants.md`.
2. Read `.github/shared/coding-standards.md` for Dart test conventions.
3. Create the test file under `test/features/<feature>/...`, mirroring the
   source path under `lib/features/<feature>/...` where practical.
4. Write tests following this structure:
   a. **Arrange:** define small hand-written fakes in the test file. Override
      Riverpod providers with `ProviderScope(overrides: [...])`.
   b. **Act:** pump the widget with `tester.pumpWidget(...)`, wrapped in
      `MaterialApp` and `ProviderScope`. Prefer a local `buildSubject()` or
      `_buildSubject()` helper that accepts fakes and state inputs.
   c. **Assert:** verify widget rendering with `find.text()`, `find.byType()`,
      `find.byIcon()`, etc.
5. Cover at least these four states, plus interactions:
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
7. For share actions: verify the system share sheet path is invoked through the
   existing abstraction. Do not target WhatsApp, Telegram, or any other
   platform-specific app.
8. Use `tester.pump()` for first-frame assertions and `tester.pumpAndSettle()`
   for completed async UI/navigation/snackbar assertions.

## Output format

A Dart test file with `group()` and `testWidgets()` blocks, each with descriptive
names matching the acceptance criteria. The file should use `flutter_test`,
`flutter_riverpod`, hand-written fakes, and a subject builder helper. Do not add
`mocktail`, `mockito`, or `golden_toolkit`.

## Validation checks

- [ ] All acceptance-criteria scenarios have corresponding tests.
- [ ] At least one negative / error-state test.
- [ ] Dependencies use hand-written fakes, not `mocktail` or `mockito`.
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
  final repo = FakeSettlementRepository();
  final analytics = FakeAnalyticsService();

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        settlementRepositoryProvider.overrideWithValue(repo),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: const MaterialApp(
        home: SettleUpBottomSheet(
          friendshipId: 'fid',
          currentUserUid: 'u1',
          otherUserUid: 'u2',
          otherDisplayName: 'Bina',
          suggestedAmountPaise: 50000,
        ),
      ),
    );
  }

  await tester.pumpWidget(buildSubject());
  await tester.pumpAndSettle();

  expect(find.text('500.00'), findsOneWidget);
});
```

Real examples to follow:

- `test/features/friends/friends_list_screen_widget_test.dart` — `buildSubject()`,
  `StreamController`, hand-written analytics/contact fakes, four-state coverage.
- `test/features/settlements/settle_up_bottom_sheet_widget_test.dart` —
  `_buildSubject()`, fake settlement repository, ProviderScope overrides,
  validation, success, and error states.

### Negative example (should refuse)

**Input:** "Write a widget test that verifies WhatsApp share opens correctly."

**Response:** Refused. Invariant 3 prohibits platform-specific share targets. The
test should verify that the system share sheet is invoked, not WhatsApp specifically.
