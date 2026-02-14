---
name: flutter-testing
description: Guide for writing Flutter tests in the One By Two app. Use this when asked to write unit tests, widget tests, or integration tests for Dart code.
---

## Test Structure

Tests mirror the `lib/` directory structure under `test/`:
```
test/
├── core/utils/          # Amount utils, debt simplifier, validators
├── domain/
│   ├── entities/        # Entity construction, equality
│   ├── usecases/        # Use case logic with mocked repos
│   └── value_objects/   # Amount, PhoneNumber, SplitConfig
├── data/
│   ├── local/dao/       # DAO CRUD operations (use in-memory sqflite)
│   ├── mappers/         # Entity ↔ Model roundtrips
│   ├── repositories/    # Offline-first flow, sync behavior
│   └── sync/            # Sync engine, conflict resolution
├── presentation/
│   ├── providers/       # Provider state transitions
│   └── features/        # Widget tests per feature
└── integration_test/    # End-to-end with Firebase Emulator
```

## Unit Test Template (Domain)

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EqualSplit', () {
    test('divides evenly when no remainder', () {
      final result = equalSplit(1000, 5);
      expect(result, [200, 200, 200, 200, 200]);
      expect(result.reduce((a, b) => a + b), 1000);
    });

    test('distributes remainder to first N participants', () {
      final result = equalSplit(1000, 3);
      expect(result, [334, 333, 333]);
      expect(result.reduce((a, b) => a + b), 1000);
    });

    test('handles single participant', () {
      final result = equalSplit(1000, 1);
      expect(result, [1000]);
    });

    test('handles amount less than participants', () {
      final result = equalSplit(2, 5);
      expect(result, [1, 1, 0, 0, 0]);
      expect(result.reduce((a, b) => a + b), 2);
    });
  });
}
```

## Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('AmountDisplay shows formatted rupees', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AmountDisplay(amountPaise: 15050),
          ),
        ),
      ),
    );

    expect(find.text('₹150.50'), findsOneWidget);
  });
}
```

## Key Testing Rules

1. **Always verify the split sum invariant:** `sum(splits) == totalAmount`
2. **Test offline behavior:** Mock connectivity as offline, verify local save works
3. **Test sync queue:** Verify operations are enqueued when offline
4. **Mock repositories** in use case tests using `Mockito` or `Mocktail`
5. **Use in-memory sqflite** for DAO tests (`inMemoryDatabasePath`)
6. **Test error paths:** What happens when Firestore write fails? When validation fails?

## Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/domain/value_objects/amount_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration tests (requires Firebase Emulator)
firebase emulators:exec 'flutter test integration_test/'
```
