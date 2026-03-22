---
name: flutter-testing
description: "Comprehensive testing guide for the One By Two Flutter app. Includes test structure, templates, conventions, and key invariants for unit, widget, and integration tests."
---

# Flutter Testing Guide

## Test Structure

```text
test/
├── core/
│   ├── utils/
│   │   ├── amount_formatter_test.dart
│   │   ├── debt_simplifier_test.dart
│   │   └── validators_test.dart
│   └── extensions/
│       └── num_extensions_test.dart
├── domain/
│   ├── entities/          # Entity creation, equality, copyWith
│   └── usecases/          # Use case logic with mocked repos
├── data/
│   ├── models/            # JSON serialization / deserialization
│   ├── mappers/           # Entity ↔ Model mapping
│   └── repositories/      # Repository impl with mocked data sources
└── presentation/
    ├── providers/         # Riverpod provider state tests
    └── features/          # Widget tests per screen
```

Each test file mirrors the corresponding source file path under `lib/`.

---

## Unit Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockExpenseRepository extends Mock implements ExpenseRepository {}

void main() {
  late MockExpenseRepository mockRepo;

  setUp(() {
    mockRepo = MockExpenseRepository();
  });

  group('AddExpenseUseCase', () {
    test('should return Success when expense is valid', () async {
      // Arrange
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        description: 'Dinner',
        totalAmountPaise: 10000,
        paidBy: {'user1': 10000},
        splits: {'user1': 5000, 'user2': 5000},
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );
      when(() => mockRepo.addExpense(expense))
          .thenAnswer((_) async => const Result.success(unit));

      final useCase = AddExpenseUseCase(mockRepo);

      // Act
      final result = await useCase(expense);

      // Assert
      expect(result, isA<Success>());
      verify(() => mockRepo.addExpense(expense)).called(1);
    });

    test('should return Failure when repository fails', () async {
      // Arrange
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        description: 'Dinner',
        totalAmountPaise: 10000,
        paidBy: {'user1': 10000},
        splits: {'user1': 5000, 'user2': 5000},
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );
      when(() => mockRepo.addExpense(expense))
          .thenAnswer((_) async => const Result.failure(AppError.serverError()));

      final useCase = AddExpenseUseCase(mockRepo);

      // Act
      final result = await useCase(expense);

      // Assert
      expect(result, isA<Failure>());
    });
  });
}
```

---

## Split Algorithm Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('EqualSplit', () {
    test('should split evenly with no remainder', () {
      final result = equalSplit(totalPaise: 10000, participants: 2);
      expect(result, [5000, 5000]);
      expect(result.reduce((a, b) => a + b), 10000); // INVARIANT: sum == total
    });

    test('should distribute remainder to first participants', () {
      final result = equalSplit(totalPaise: 10000, participants: 3);
      expect(result, [3334, 3333, 3333]);
      expect(result.reduce((a, b) => a + b), 10000); // INVARIANT: sum == total
      expect(result.every((a) => a > 0), true);       // INVARIANT: all positive
    });

    test('should handle single participant', () {
      final result = equalSplit(totalPaise: 10000, participants: 1);
      expect(result, [10000]);
    });

    test('should handle 1 paise total', () {
      final result = equalSplit(totalPaise: 1, participants: 3);
      expect(result, [1, 0, 0]);
      expect(result.reduce((a, b) => a + b), 1);
    });

    test('should satisfy fairness invariant', () {
      final result = equalSplit(totalPaise: 10001, participants: 4);
      final positives = result.where((s) => s > 0).toList();
      final maxSplit = positives.reduce(max);
      final minSplit = positives.reduce(min);
      expect(maxSplit - minSplit, lessThanOrEqualTo(1),
        reason: 'Equal split difference must be ≤ 1 paisa');
    });
  });

  group('PercentageSplit', () {
    test('should handle clean percentages', () {
      final result = percentageSplit(
        totalPaise: 10000,
        percentages: [50, 30, 20],
      );
      expect(result, [5000, 3000, 2000]);
      expect(result.reduce((a, b) => a + b), 10000);
    });

    test('should use Largest Remainder Method for rounding', () {
      final result = percentageSplit(
        totalPaise: 10000,
        percentages: [33.33, 33.33, 33.34],
      );
      expect(result.reduce((a, b) => a + b), 10000);
    });
  });

  group('SharesSplit', () {
    test('should split by shares proportionally', () {
      final result = sharesSplit(
        totalPaise: 10000,
        shares: [2, 1, 1],
      );
      expect(result, [5000, 2500, 2500]);
      expect(result.reduce((a, b) => a + b), 10000);
    });

    test('should handle uneven shares with remainder', () {
      final result = sharesSplit(
        totalPaise: 10000,
        shares: [1, 1, 1],
      );
      expect(result.reduce((a, b) => a + b), 10000);
    });
  });
}
```

---

## Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('AddExpenseScreen shows amount input', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailProvider.overrideWith((_) => AsyncValue.data(mockGroup)),
        ],
        child: const MaterialApp(home: AddExpenseScreen(groupId: 'g1')),
      ),
    );

    expect(find.byType(TextField), findsWidgets);
    expect(find.text('₹'), findsOneWidget);
  });

  testWidgets('AddExpenseScreen validates empty amount', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailProvider.overrideWith((_) => AsyncValue.data(mockGroup)),
        ],
        child: const MaterialApp(home: AddExpenseScreen(groupId: 'g1')),
      ),
    );

    // Tap save without entering amount
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('ExpenseListTile displays formatted amount', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseListTile(
            expense: Expense(
              id: 'e1',
              description: 'Dinner',
              totalAmountPaise: 150050, // ₹1,500.50
              // ...
            ),
          ),
        ),
      ),
    );

    expect(find.text('₹1,500.50'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
  });
}
```

---

## Provider Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('expenseListProvider', () {
    test('should emit loading then data', () async {
      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      when(() => mockRepo.watchExpenses('g1'))
          .thenAnswer((_) => Stream.value([mockExpense]));

      final sub = container.listen(
        expenseListProvider('g1'),
        (_, __) {},
      );

      // Initial state is loading
      expect(sub.read(), const AsyncValue<List<Expense>>.loading());

      // After stream emits, state is data
      await Future.microtask(() {});
      expect(sub.read().value, [mockExpense]);
    });
  });
}
```

---

## Key Testing Rules

1. **ALWAYS verify the money invariant:** `sum(splits) == totalAmount` in every split test.
2. **Test remainder cases:** Use amounts that produce remainders (e.g., 10000 ÷ 3 = 3333 + 3333 + 3334).
3. **Test boundary values:** 0 paise, 1 paise, `2^31 - 1` (max 32-bit int ≈ ₹2.1 crore).
4. **Mock Firestore** with in-memory implementations for data source tests.
5. **Use `FakeFirebaseFirestore`** from the `fake_cloud_firestore` package for integration-level tests.
6. **Never use `skip:`** to skip tests — fix or remove them.
7. **All money is in paise (int).** Never use `double` for money calculations.
8. **Run tests with coverage:**

   ```bash
   flutter test --coverage
   ```

   Then inspect `coverage/lcov.info`.

---

## Coverage Targets

| Layer | Target |
|-------|--------|
| Domain entities & value objects | 95%+ |
| Split algorithms (`core/utils/`) | 95%+ |
| Use cases | 90%+ |
| Data layer (repos, models, mappers) | 80%+ |
| Widgets / screens | 70%+ |
| **Overall** | **80%+** |

---

## Test Naming Convention

Use descriptive names following this pattern:

```text
<unit under test> should <expected behavior> when <condition>
```

Examples:

- `equalSplit should distribute remainder to first participants when total is not evenly divisible`
- `AddExpenseUseCase should return Failure when repository throws`
- `AmountFormatter should display ₹0.01 when amount is 1 paise`
