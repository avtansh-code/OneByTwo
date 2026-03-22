---
applyTo: "test/**/*_test.dart"
---

# Dart Test Code Instructions

## Structure

- Test file mirrors source file: `lib/domain/entities/expense.dart` → `test/domain/entities/expense_test.dart`
- Use `group()` to organize related tests.
- Use `setUp()` and `tearDown()` for shared setup/cleanup.

## Naming

- Test names must be descriptive: `test('should return error when split amounts do not sum to total')`
- Group names describe the unit under test: `group('EqualSplit', () { ... })`

## Pattern: AAA (Arrange → Act → Assert)

```dart
test('description', () {
  // Arrange
  final input = ...;

  // Act
  final result = function(input);

  // Assert
  expect(result, expected);
});
```

## Money Invariants (REQUIRED for all split/balance tests)

```dart
// Always verify:
expect(splits.reduce((a, b) => a + b), totalPaise); // Sum == total
expect(splits.every((s) => s >= 0), true);           // Non-negative
expect(splits.every((s) => s is int), true);          // Integer
```

## Mocking

- Use `mocktail` package for mocking.
- Create mocks: `class MockExpenseRepository extends Mock implements ExpenseRepository {}`
- Register fallback values for complex types.

## Widget Testing

- Wrap widgets with `ProviderScope` and override providers with mock data.
- Use `tester.pumpAndSettle()` for animations.
- Test user interactions with `tester.tap()`, `tester.enterText()`.

## What to Test

- **Happy path:** Normal operation succeeds
- **Error paths:** Network failure, invalid input, auth expired
- **Edge cases:** Zero amounts, single participant, empty lists, max group size
- **Boundary:** 1 paisa, max int, 0 participants
- **Offline:** Behavior when connectivity is lost

## Rules

- Never use `skip:` to skip tests. Fix or remove.
- Never use `print()` in tests. Use `expect()` assertions.
- Tests must be deterministic (no random, no `DateTime.now()` without mocking).
- Run: `flutter test` or `flutter test test/specific_file_test.dart`
