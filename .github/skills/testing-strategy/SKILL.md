---
name: testing-strategy
description: "Strategic testing guide — test pyramid, TDD workflow, regression testing, integration testing with Firebase emulators, and test-first bug fixing for the One By Two app."
---

# Testing Strategy — One By Two

> This skill covers **strategic testing decisions**: when to write which type of test, TDD workflows, regression testing, integration testing with Firebase emulators, and test-first bug fixing. For test **templates and conventions**, see the `flutter-testing` skill.

---

## 1. Test Pyramid for One By Two

```text
                    ┌─────────┐
                    │   E2E   │  ← Few: Critical user journeys (register → expense → settle)
                   ─┼─────────┼─
                  │ Integration │  ← Some: Multi-layer flows with Firebase Emulator
                 ─┼─────────────┼─
                │  Widget Tests   │  ← Many: Screen behavior, user interaction
               ─┼─────────────────┼─
              │    Unit Tests       │  ← Most: Entities, algorithms, repos, use cases
             └──────────────────────┘
```

### Unit Tests — 70% of all tests

Unit tests are the foundation. They run in milliseconds, have zero external dependencies, and catch the vast majority of bugs.

**What to unit test:**

| Category | Examples | Key Assertions |
|---|---|---|
| **Split algorithms** | `equalSplit`, `percentageSplit`, `sharesSplit`, `exactSplit`, `itemizedSplit` | `sum(splits) == total` (money invariant), remainder distributed correctly, edge cases (1 participant, 0 amount) |
| **AmountFormatter / num extensions** | `10000.toRupees()`, `formatPaise()` | Correct ₹ symbol, locale-aware formatting, paise→rupees and back |
| **Debt simplification** | `DebtSimplifier.simplify(balances)` | Fewer transactions, all balances zeroed, no money created/destroyed |
| **Validators** | Phone (`+91XXXXXXXXXX`), email, group name, amount | Valid inputs pass, invalid inputs return specific error messages |
| **Entities** | `Expense`, `Group`, `User`, `Settlement`, `Balance` | Equality (`==`), `copyWith` immutability, `hashCode` consistency, default values |
| **Value objects** | `Amount`, `PhoneNumber`, `EmailAddress`, `SplitConfig` | Construction validation, equality, conversion methods |
| **Use cases** | `AddExpenseUseCase`, `RecordSettlementUseCase`, `CalculateSplitsUseCase` | Correct delegation to repos, error propagation, Result wrapping |
| **Repository impls** | `ExpenseRepositoryImpl`, `BalanceRepositoryImpl` | Correct Firestore calls via mocked data sources, mapper invocation, error handling |
| **Mappers** | `ExpenseMapper.toModel()`, `.toEntity()` | Round-trip fidelity (`entity → model → entity == original`), null handling, default values |
| **PII sanitizer** | `PiiSanitizer.sanitize(logEntry)` | Phone numbers, emails, FCM tokens stripped from log output |

**Unit test ground rules:**

- Never import `dart:io` or any Flutter/Firebase package
- Every dependency is mocked (use `mocktail`)
- Tests run in < 1 second total for the entire unit suite
- Domain layer has **zero** mocking — it's pure Dart, test it directly

### Widget Tests — 20% of all tests

Widget tests verify UI behavior in isolation using Flutter's test framework. They are faster than integration tests but exercise real widget trees.

**What to widget test:**

| Category | Examples |
|---|---|
| **Screen rendering** | `AddExpenseScreen` shows amount input, category picker, split preview |
| **User interaction** | Tap "Add Expense" → navigates to form; fill form → tap save → shows loading → success |
| **Error states** | Network error → shows retry button; invalid amount → shows inline error |
| **Loading states** | `AsyncLoading` → shows shimmer/skeleton; `AsyncData` → shows content |
| **Empty states** | No expenses → shows "No expenses yet" illustration + CTA |
| **Navigation** | Back button works, deep link renders correct screen |
| **Form validation UI** | Amount = 0 → "Amount must be greater than 0"; empty description → "Required" |
| **Connectivity badge** | Offline → shows "Offline" badge; online → badge hidden |
| **Undo snackbar** | Delete expense → shows "Undo" snackbar for 30 seconds |

**Widget test ground rules:**

- Wrap every widget in `ProviderScope` with overridden providers
- Mock all use cases / repositories at the Riverpod provider level
- Use `pumpAndSettle()` for animations, with a `timeout` to prevent infinite waits
- Test accessibility: verify `Semantics` labels exist for screen readers

### Integration Tests — 8% of all tests

Integration tests verify multi-layer flows against real (emulated) Firebase services. They catch issues that unit and widget tests miss: serialization bugs, Firestore query correctness, security rules, and Cloud Function triggers.

**What to integration test:**

| Flow | What It Verifies |
|---|---|
| **Create user → create group → add expense → verify balance** | Full write path through Firestore, mapper round-trip, balance calculation trigger |
| **Add expense offline → reconnect → verify synced** | Offline persistence, `hasPendingWrites` flag, sync completion |
| **Two users edit same expense concurrently** | Optimistic concurrency via `version` field, conflict detection |
| **Delete expense → undo within 30s → verify restored** | Soft delete, `isDeleted` flag, undo timer, balance recalculation |
| **Record settlement → verify balances updated** | Settlement creation, balance update, activity log entry |
| **Cloud Function: debt simplification trigger** | Firestore write triggers function, simplified debts written back |
| **Security rules: user can only read own data** | Authenticated reads succeed, cross-user reads rejected |
| **Security rules: only group members can write expenses** | Member writes succeed, non-member writes rejected |

### E2E Tests — 2% of all tests

E2E tests exercise the full app from the user's perspective. They are slow, expensive, and flaky — reserve them for critical journeys only.

**Critical user journeys to E2E test:**

1. **Registration flow:** Welcome → Enter phone → Receive OTP → Verify → Set up profile → Land on home screen
2. **Core expense loop:** Create group → Add members → Add expense (equal split) → Verify balances on group detail → Settle up → Verify zero balance
3. **Friend expense flow:** Add friend → Add 1:1 expense → Verify friend balance → Settle → Verify zero

**E2E test ground rules:**

- Run against Firebase Emulator Suite (never production)
- Maximum 5 E2E tests in the entire suite
- Each test must complete in under 60 seconds
- Use `integration_test` package with `IntegrationTestWidgetsFlutterBinding`

---

## 2. TDD Workflow (Test-Driven Development)

### The Red → Green → Refactor Cycle

```text
1. WRITE FAILING TEST for the domain entity / use case / algorithm
   → Run: flutter test → RED ✗

2. IMPLEMENT minimum code to pass
   → Run: flutter test → GREEN ✓

3. REFACTOR (extract, rename, optimize)
   → Run: flutter test → GREEN ✓ (still passing)

4. WRITE NEXT TEST (edge case, error path)
   → Repeat cycle
```

### When to Apply TDD

| Scenario | Use TDD? | Reason |
|---|---|---|
| New split algorithm | **Always** | Correctness is critical; money invariants must hold |
| New use case | **Always** | Defines the contract before implementation |
| Bug fix | **Always** | Write failing test first to prove bug exists (see §3) |
| New entity | **Usually** | `==`, `copyWith`, validation rules benefit from tests first |
| New widget | **Sometimes** | TDD works well for complex interaction flows; skip for simple displays |
| Firebase integration | **Rarely** | Integration tests are written after implementation, against emulators |

### TDD Example: New Split Algorithm (Shares Split)

#### Step 1 — RED: Write the failing test

```dart
// test/core/utils/amount_utils_test.dart
group('sharesSplit', () {
  test('should split ₹100 among 3 users with shares 1:2:3', () {
    final result = sharesSplit(
      totalPaise: 10000,
      shares: {'u1': 1, 'u2': 2, 'u3': 3},
    );

    // Money invariant: no paise created or destroyed
    expect(result.values.reduce((a, b) => a + b), 10000);

    // Proportional: u1 gets 1/6, u2 gets 2/6, u3 gets 3/6
    expect(result['u1'], 1667); // 1666.67 → rounded up (remainder goes to smallest share)
    expect(result['u2'], 3333);
    expect(result['u3'], 5000);
  });

  test('should handle single participant with all shares', () {
    final result = sharesSplit(
      totalPaise: 10000,
      shares: {'u1': 5},
    );
    expect(result, {'u1': 10000});
  });

  test('should throw when shares map is empty', () {
    expect(
      () => sharesSplit(totalPaise: 10000, shares: {}),
      throwsA(isA<InvalidSplitException>()),
    );
  });
});
```

#### Step 2 — GREEN: Implement the minimum

```dart
// lib/core/utils/amount_utils.dart
Map<String, int> sharesSplit({
  required int totalPaise,
  required Map<String, double> shares,
}) {
  if (shares.isEmpty) throw InvalidSplitException('Shares cannot be empty');
  if (shares.length == 1) return {shares.keys.first: totalPaise};

  final totalShares = shares.values.reduce((a, b) => a + b);
  final result = <String, int>{};
  int distributed = 0;

  for (final entry in shares.entries) {
    final amount = (totalPaise * entry.value / totalShares).floor();
    result[entry.key] = amount;
    distributed += amount;
  }

  // Distribute remainder to smallest shares first (fairness)
  int remainder = totalPaise - distributed;
  final sorted = result.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final entry in sorted) {
    if (remainder <= 0) break;
    result[entry.key] = entry.value + 1;
    remainder--;
  }

  return result;
}
```

#### Step 3 — REFACTOR: Extract remainder distribution

Extract the remainder distribution into a reusable `_distributeRemainder()` helper shared across `equalSplit`, `percentageSplit`, and `sharesSplit`.

#### Step 4 — Next test: zero shares, negative shares, very large amounts

### TDD Example: New Use Case

```dart
// Step 1 — RED: Define expected behavior
// test/domain/usecases/expense/add_expense_usecase_test.dart
group('AddExpenseUseCase', () {
  late AddExpenseUseCase useCase;
  late MockExpenseRepository mockExpenseRepo;
  late MockBalanceRepository mockBalanceRepo;

  setUp(() {
    mockExpenseRepo = MockExpenseRepository();
    mockBalanceRepo = MockBalanceRepository();
    useCase = AddExpenseUseCase(mockExpenseRepo, mockBalanceRepo);
  });

  test('should save expense and update balances', () async {
    final expense = TestFactory.expense();
    when(() => mockExpenseRepo.addExpense(expense))
        .thenAnswer((_) async => const Result.success(unit));
    when(() => mockBalanceRepo.recalculate(expense.groupId!))
        .thenAnswer((_) async => const Result.success(unit));

    final result = await useCase(expense);

    expect(result.isSuccess, isTrue);
    verify(() => mockExpenseRepo.addExpense(expense)).called(1);
    verify(() => mockBalanceRepo.recalculate(expense.groupId!)).called(1);
  });

  test('should return failure when repo fails', () async {
    final expense = TestFactory.expense();
    when(() => mockExpenseRepo.addExpense(expense))
        .thenAnswer((_) async => Result.failure(ServerFailure('write failed')));

    final result = await useCase(expense);

    expect(result.isFailure, isTrue);
    verifyNever(() => mockBalanceRepo.recalculate(any()));
  });
});
```

```dart
// Step 2 — GREEN: Implement
class AddExpenseUseCase {
  final ExpenseRepository _expenseRepo;
  final BalanceRepository _balanceRepo;

  AddExpenseUseCase(this._expenseRepo, this._balanceRepo);

  Future<Result<void>> call(Expense expense) async {
    final result = await _expenseRepo.addExpense(expense);
    if (result.isFailure) return result;
    return _balanceRepo.recalculate(expense.groupId!);
  }
}
```

### TDD Example: Widget with Complex Interaction

```dart
// Step 1 — RED: Test the rendering and interaction
// test/presentation/features/expense/screens/add_expense_screen_test.dart
testWidgets('should show split preview when amount entered', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupDetailProvider.overrideWith((_) => AsyncData(TestFactory.group())),
      ],
      child: const MaterialApp(home: AddExpenseScreen(groupId: 'g1')),
    ),
  );

  // Enter amount
  await tester.enterText(find.byKey(const Key('amount_input')), '300');
  await tester.pumpAndSettle();

  // Split preview should show ₹100 per person (3 members, equal split)
  expect(find.text('₹100.00'), findsOneWidget);
  expect(find.text('per person'), findsOneWidget);
});
```

---

## 3. Test-First Bug Fixing

Every bug fix **must** start with a failing test. No exceptions.

### Workflow

```text
1. REPRODUCE: Write a failing test that demonstrates the bug
   ──────────────────────────────────────────────────────────
   test('regression: BUG-123 — 3-way equal split of ₹100 loses 1 paisa', () {
     final result = equalSplit(totalPaise: 10000, participants: 3);
     // BUG: result is [3333, 3333, 3333] = 9999 (lost 1 paisa)
     expect(result.reduce((a, b) => a + b), 10000); // FAILS → proves bug exists
   });

2. FIX: Implement the smallest possible change
   ──────────────────────────────────────────────
   // Add remainder distribution: first participant gets the extra paisa
   // [3334, 3333, 3333] = 10000 ✓

3. VERIFY: Run the test → GREEN ✓
   ────────────────────────────────
   flutter test test/core/utils/amount_utils_test.dart

4. REGRESSION: Ensure no other tests broke
   ─────────────────────────────────────────
   flutter test
```

### Real-World Bug Fix Examples

#### BUG: Percentage split rounding creates money

```dart
test('regression: BUG-045 — percentage split of ₹99 among 33.33/33.33/33.34 creates extra paisa', () {
  final result = percentageSplit(
    totalPaise: 9900,
    percentages: {'u1': 33.33, 'u2': 33.33, 'u3': 33.34},
  );
  final total = result.values.reduce((a, b) => a + b);
  expect(total, 9900, reason: 'No money should be created or destroyed');
});
```

#### BUG: Offline delete doesn't trigger undo timer

```dart
test('regression: BUG-078 — deleting expense while offline still shows undo snackbar', () async {
  // Simulate offline
  when(() => mockConnectivity.isOnline).thenReturn(false);

  await tester.pumpWidget(buildExpenseDetailScreen(expense: TestFactory.expense()));
  await tester.tap(find.byIcon(Icons.delete));
  await tester.pumpAndSettle();

  expect(find.text('Undo'), findsOneWidget);
  expect(find.text('Expense deleted'), findsOneWidget);
});
```

#### BUG: Balance not updated after settlement

```dart
test('regression: BUG-102 — recording settlement does not update pairwise balance', () async {
  final settlement = TestFactory.settlement(
    fromUserId: 'u1',
    toUserId: 'u2',
    amount: 5000, // ₹50
  );

  when(() => mockSettlementRepo.record(settlement))
      .thenAnswer((_) async => const Result.success(unit));
  when(() => mockBalanceRepo.recalculate(settlement.groupId!))
      .thenAnswer((_) async => const Result.success(unit));

  final result = await useCase(settlement);

  expect(result.isSuccess, isTrue);
  verify(() => mockBalanceRepo.recalculate(settlement.groupId!)).called(1);
});
```

---

## 4. Integration Testing with Firebase Emulator

### Emulator Setup

**Install and configure:**

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Initialize emulators in the project root
firebase init emulators
# Select: Firestore, Authentication, Cloud Functions, Storage

# Start emulators
firebase emulators:start --only firestore,auth,functions,storage
```

**Expected emulator ports (configure in `firebase.json`):**

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 },
    "storage": { "port": 9199 },
    "ui": { "port": 4000 }
  }
}
```

### Emulator Connection in Tests

```dart
// test/helpers/firebase_emulator_setup.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> configureEmulators() async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
}
```

### Running Integration Tests

```bash
# Start emulators in one terminal
firebase emulators:start --only firestore,auth,functions,storage

# Run integration tests in another terminal
flutter test integration_test/ --dart-define=USE_EMULATOR=true

# Run a specific integration test file
flutter test integration_test/expense_flow_test.dart --dart-define=USE_EMULATOR=true
```

### Integration Test Patterns

#### Pattern 1: Full expense lifecycle

```dart
// integration_test/expense_lifecycle_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Expense Lifecycle', () {
    late FirebaseFirestore firestore;

    setUp(() async {
      await configureEmulators();
      firestore = FirebaseFirestore.instance;
      // Clear all data before each test
      await clearFirestoreEmulator();
    });

    testWidgets('create user → create group → add expense → verify balance',
        (tester) async {
      // 1. Create authenticated user
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: 'alice@test.com',
            password: 'test1234',
          );
      final uid = userCred.user!.uid;

      // 2. Create user document
      await firestore.collection('users').doc(uid).set({
        'name': 'Alice',
        'email': 'alice@test.com',
        'phone': '+919876543210',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Create group with 2 members
      final groupRef = await firestore.collection('groups').add({
        'name': 'Trip',
        'createdBy': uid,
        'memberCount': 2,
      });
      await groupRef.collection('members').doc(uid).set({
        'userId': uid, 'name': 'Alice', 'role': 'owner',
      });
      await groupRef.collection('members').doc('u2').set({
        'userId': 'u2', 'name': 'Bob', 'role': 'member',
      });

      // 4. Add expense: Alice paid ₹100, split equally
      await groupRef.collection('expenses').add({
        'description': 'Lunch',
        'amount': 10000, // paise
        'splitType': 'equal',
        'payers': [{'userId': uid, 'amountPaid': 10000}],
        'splits': [
          {'userId': uid, 'amountOwed': 5000},
          {'userId': 'u2', 'amountOwed': 5000},
        ],
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'version': 1,
      });

      // 5. Verify balance: Bob owes Alice ₹50
      // (Wait for Cloud Function trigger if using server-side balance calc)
      await Future.delayed(const Duration(seconds: 2));

      final balanceKey = '${uid}_u2'; // canonical: lex-smaller first
      final balanceDoc = await groupRef
          .collection('balances')
          .doc(balanceKey)
          .get();

      expect(balanceDoc.exists, isTrue);
      expect(balanceDoc.data()!['amount'], -5000); // u2 owes Alice 5000
    });
  });
}
```

#### Pattern 2: Offline write → reconnect → verify sync

```dart
testWidgets('expense added offline syncs after reconnect', (tester) async {
  await configureEmulators();
  final firestore = FirebaseFirestore.instance;

  // 1. Add expense while "online" to verify baseline
  final groupRef = firestore.collection('groups').doc('g1');

  // 2. Disable network (simulates airplane mode)
  await firestore.disableNetwork();

  // 3. Write expense (should succeed locally)
  final docRef = await groupRef.collection('expenses').add({
    'description': 'Offline Dinner',
    'amount': 5000,
    'createdAt': FieldValue.serverTimestamp(),
    'isDeleted': false,
  });

  // 4. Verify local read returns the document
  final localDoc = await docRef.get();
  expect(localDoc.exists, isTrue);
  expect(localDoc.metadata.hasPendingWrites, isTrue);

  // 5. Re-enable network
  await firestore.enableNetwork();

  // 6. Wait for sync and verify
  await Future.delayed(const Duration(seconds: 3));
  final syncedDoc = await docRef.get();
  expect(syncedDoc.metadata.hasPendingWrites, isFalse);
  expect(syncedDoc.data()!['description'], 'Offline Dinner');
});
```

#### Pattern 3: Concurrent edit conflict detection

```dart
testWidgets('concurrent edits detected via version field', (tester) async {
  await configureEmulators();
  final firestore = FirebaseFirestore.instance;
  final expenseRef = firestore.doc('groups/g1/expenses/e1');

  // Setup: create expense at version 1
  await expenseRef.set({
    'description': 'Original',
    'amount': 10000,
    'version': 1,
  });

  // User A reads version 1
  final docA = await expenseRef.get();
  final versionA = docA.data()!['version'] as int;

  // User B also reads version 1, then writes first
  await expenseRef.update({
    'description': 'Updated by B',
    'version': FieldValue.increment(1),
  });

  // User A tries to write with stale version
  try {
    await firestore.runTransaction((tx) async {
      final current = await tx.get(expenseRef);
      final currentVersion = current.data()!['version'] as int;
      if (currentVersion != versionA) {
        throw Exception('Conflict: version changed from $versionA to $currentVersion');
      }
      tx.update(expenseRef, {
        'description': 'Updated by A',
        'version': currentVersion + 1,
      });
    });
    fail('Should have thrown conflict exception');
  } catch (e) {
    expect(e.toString(), contains('Conflict'));
  }
});
```

#### Pattern 4: Delete → undo → verify restore

```dart
testWidgets('delete expense → undo within 30s → expense restored', (tester) async {
  await configureEmulators();
  final firestore = FirebaseFirestore.instance;
  final expenseRef = firestore.doc('groups/g1/expenses/e1');

  // Setup
  await expenseRef.set({
    'description': 'Lunch',
    'amount': 10000,
    'isDeleted': false,
    'deletedAt': null,
  });

  // Soft delete
  await expenseRef.update({
    'isDeleted': true,
    'deletedAt': FieldValue.serverTimestamp(),
    'deletedBy': 'u1',
  });

  // Verify soft deleted
  final deleted = await expenseRef.get();
  expect(deleted.data()!['isDeleted'], isTrue);

  // Undo (within 30 seconds)
  await expenseRef.update({
    'isDeleted': false,
    'deletedAt': null,
    'deletedBy': null,
  });

  // Verify restored
  final restored = await expenseRef.get();
  expect(restored.data()!['isDeleted'], isFalse);
  expect(restored.data()!['description'], 'Lunch');
});
```

### Cleaning Up Between Tests

```dart
/// Clears all Firestore data via the emulator REST API.
/// Only works against the emulator — will fail against production.
Future<void> clearFirestoreEmulator() async {
  final projectId = 'one-by-two-test';
  final url = 'http://localhost:8080/emulator/v1/projects/$projectId/databases/(default)/documents';
  await http.delete(Uri.parse(url));
}
```

---

## 5. Regression Test Requirements

### When Regression Tests Are MANDATORY

| Change Type | Required Regression Tests |
|---|---|
| **Bug fix** (any) | At least one test reproducing the exact bug |
| **Split algorithm** change | Re-run ALL split invariant tests (`sum == total`, boundary, remainder) |
| **Security rule** change | Re-run ALL Firestore security rules tests |
| **Cloud Function** change | Re-run trigger tests + output validation tests |
| **Offline behavior** change | Re-run ALL sync / offline scenario tests |
| **Balance calculation** change | Re-run pairwise balance + debt simplification tests |
| **Mapper** change | Re-run round-trip fidelity tests (`entity → model → entity`) |
| **Entity field** addition | Add equality test, `copyWith` test, serialization test |

### Naming Convention

```dart
// Always prefix regression tests with 'regression:' and the bug ID
test('regression: BUG-123 — 3-way split of ₹100 loses 1 paisa', () { ... });
test('regression: BUG-045 — percentage split creates extra money', () { ... });
test('regression: BUG-078 — offline delete skips undo snackbar', () { ... });
test('regression: BUG-102 — settlement does not update balance', () { ... });
```

### Split Algorithm Invariant Tests (Always Re-Run)

These tests are non-negotiable after any split logic change:

```dart
group('Split Invariants (ALL split types)', () {
  for (final splitFn in [equalSplit, percentageSplit, sharesSplit]) {
    test('${splitFn.name}: sum of splits == total for ₹1', () {
      // Minimum amount edge case
    });

    test('${splitFn.name}: sum of splits == total for ₹99999.99', () {
      // Large amount edge case
    });

    test('${splitFn.name}: single participant gets full amount', () {
      // Degenerate case
    });

    test('${splitFn.name}: 100 participants', () {
      // Stress test
    });

    test('${splitFn.name}: remainder distributed fairly', () {
      // No single participant absorbs all rounding error
    });
  }
});
```

### CI Enforcement

```yaml
# .github/workflows/test.yml (conceptual)
on:
  pull_request:
    paths:
      - 'lib/core/utils/amount_utils.dart'
      - 'lib/core/utils/debt_simplifier.dart'
jobs:
  split-invariants:
    runs-on: ubuntu-latest
    steps:
      - run: flutter test test/core/utils/ --reporter=expanded
```

---

## 6. Test Data Factories

Use factories for consistent, readable test data. Each factory provides sensible defaults that can be overridden per-test.

```dart
// test/helpers/test_factory.dart

import 'package:one_by_two/domain/entities/expense.dart';
import 'package:one_by_two/domain/entities/expense_payer.dart';
import 'package:one_by_two/domain/entities/expense_split.dart';
import 'package:one_by_two/domain/entities/group.dart';
import 'package:one_by_two/domain/entities/group_member.dart';
import 'package:one_by_two/domain/entities/user.dart';
import 'package:one_by_two/domain/entities/settlement.dart';
import 'package:one_by_two/domain/entities/balance.dart';

class TestFactory {
  // ──────────────────────────────────────
  // User
  // ──────────────────────────────────────
  static User user({
    String uid = 'u1',
    String name = 'Alice',
    String email = 'alice@test.com',
    String phone = '+919876543210',
  }) =>
      User(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  static List<User> users({int count = 3}) => List.generate(
        count,
        (i) => user(
          uid: 'u${i + 1}',
          name: 'User ${i + 1}',
          email: 'user${i + 1}@test.com',
          phone: '+9198765432${10 + i}',
        ),
      );

  // ──────────────────────────────────────
  // Group
  // ──────────────────────────────────────
  static Group group({
    String id = 'g1',
    String name = 'Test Group',
    GroupCategory category = GroupCategory.trip,
    String createdBy = 'u1',
    int memberCount = 3,
    bool simplifiedDebts = true,
  }) =>
      Group(
        id: id,
        name: name,
        category: category,
        createdBy: createdBy,
        createdAt: DateTime(2024, 1, 1),
        memberCount: memberCount,
        simplifiedDebts: simplifiedDebts,
      );

  static GroupMember groupMember({
    String userId = 'u1',
    String name = 'Alice',
    MemberRole role = MemberRole.member,
  }) =>
      GroupMember(
        userId: userId,
        name: name,
        role: role,
        joinedAt: DateTime(2024, 1, 1),
      );

  // ──────────────────────────────────────
  // Expense
  // ──────────────────────────────────────
  static Expense expense({
    String id = 'e1',
    String? groupId = 'g1',
    String description = 'Test Expense',
    int amount = 10000, // ₹100.00
    SplitType splitType = SplitType.equal,
    int participantCount = 3,
    String createdBy = 'u1',
    bool isDeleted = false,
    int version = 1,
  }) {
    final participants = List.generate(participantCount, (i) => 'u${i + 1}');
    final splitAmount = amount ~/ participantCount;

    return Expense(
      id: id,
      groupId: groupId,
      contextType: ExpenseContext.group,
      description: description,
      amount: amount,
      date: DateTime(2024, 1, 15),
      category: ExpenseCategory.food,
      splitType: splitType,
      payers: [ExpensePayer(userId: createdBy, amountPaid: amount)],
      splits: participants
          .map((uid) => ExpenseSplit(userId: uid, amountOwed: splitAmount))
          .toList(),
      createdBy: createdBy,
      createdAt: DateTime(2024, 1, 15),
      updatedAt: DateTime(2024, 1, 15),
      updatedBy: createdBy,
      isDeleted: isDeleted,
      version: version,
    );
  }

  // ──────────────────────────────────────
  // Settlement
  // ──────────────────────────────────────
  static Settlement settlement({
    String id = 's1',
    String? groupId = 'g1',
    String fromUserId = 'u2',
    String toUserId = 'u1',
    int amount = 5000, // ₹50.00
    String createdBy = 'u2',
  }) =>
      Settlement(
        id: id,
        groupId: groupId,
        contextType: ExpenseContext.group,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        date: DateTime(2024, 1, 20),
        createdBy: createdBy,
        createdAt: DateTime(2024, 1, 20),
        isDeleted: false,
        version: 1,
      );

  // ──────────────────────────────────────
  // Balance
  // ──────────────────────────────────────
  static Balance balance({
    String groupId = 'g1',
    String userAId = 'u1',
    String userBId = 'u2',
    int amount = 5000, // positive = A owes B
  }) =>
      Balance(
        groupId: groupId,
        userAId: userAId,
        userBId: userBId,
        amount: amount,
        lastUpdated: DateTime(2024, 1, 15),
      );
}
```

### Usage in Tests

```dart
// Simple — use defaults
final expense = TestFactory.expense();

// Override only what matters for this test
final bigExpense = TestFactory.expense(amount: 9999999, participantCount: 50);
final deletedExpense = TestFactory.expense(isDeleted: true);
final friendExpense = TestFactory.expense(groupId: null);

// Generate a batch
final threeUsers = TestFactory.users(count: 3);
```

### Builder Pattern (For Complex Scenarios)

When factory methods aren't flexible enough, use a builder:

```dart
// test/helpers/expense_builder.dart
class ExpenseBuilder {
  String _id = 'e1';
  int _amount = 10000;
  SplitType _splitType = SplitType.equal;
  List<ExpensePayer> _payers = [];
  List<ExpenseSplit> _splits = [];
  bool _isDeleted = false;

  ExpenseBuilder withId(String id) { _id = id; return this; }
  ExpenseBuilder withAmount(int paise) { _amount = paise; return this; }
  ExpenseBuilder withSplitType(SplitType type) { _splitType = type; return this; }
  ExpenseBuilder withPayers(List<ExpensePayer> p) { _payers = p; return this; }
  ExpenseBuilder withSplits(List<ExpenseSplit> s) { _splits = s; return this; }
  ExpenseBuilder deleted() { _isDeleted = true; return this; }

  Expense build() => Expense(
        id: _id,
        amount: _amount,
        splitType: _splitType,
        payers: _payers,
        splits: _splits,
        isDeleted: _isDeleted,
        // ... other required fields with sensible defaults
      );
}

// Usage:
final expense = ExpenseBuilder()
    .withAmount(50000)
    .withSplitType(SplitType.percentage)
    .withPayers([ExpensePayer(userId: 'u1', amountPaid: 50000)])
    .withSplits([
      ExpenseSplit(userId: 'u1', amountOwed: 25000, percentage: 50),
      ExpenseSplit(userId: 'u2', amountOwed: 25000, percentage: 50),
    ])
    .build();
```

---

## 7. Testing Offline Scenarios

### Offline Testing Checklist

- [ ] **Write works offline** — Firestore write returns immediately, `hasPendingWrites == true`
- [ ] **Read shows cached data** — Previously fetched documents available offline
- [ ] **UI shows sync pending indicator** — `ConnectivityBadge` displays "Offline" / sync icon
- [ ] **Reconnection triggers sync** — `hasPendingWrites` transitions from `true` → `false`
- [ ] **Concurrent offline edits detected** — Version conflict raised when two users edit same document offline
- [ ] **Offline delete shows undo** — Soft delete + undo snackbar works without network
- [ ] **Offline undo syncs on reconnect** — If user undoes offline, the undo is what syncs (not the delete)
- [ ] **Queue ordering preserved** — Multiple offline writes sync in the order they were made
- [ ] **Large offline queue** — 50+ pending writes don't cause timeouts or data loss on reconnect
- [ ] **Server timestamp resolution** — `FieldValue.serverTimestamp()` resolves to server time after sync, not local time

### Testing Offline in Unit Tests (Mock Connectivity)

```dart
// Mock the ConnectivityService
class MockConnectivityService extends Mock implements ConnectivityService {}

group('Offline behavior', () {
  late MockConnectivityService mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivityService();
  });

  test('should queue expense when offline', () {
    when(() => mockConnectivity.isOnline).thenReturn(false);

    // Expense should be accepted locally
    // UI should show pending indicator
  });

  test('should sync queued expenses when back online', () {
    when(() => mockConnectivity.isOnline).thenReturn(true);
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => Stream.value(true));

    // Previously queued expenses should sync
    // Pending indicator should disappear
  });
});
```

### Testing Offline in Widget Tests

```dart
testWidgets('shows offline banner when disconnected', (tester) async {
  final connectivityNotifier = ValueNotifier<bool>(true); // online

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityProvider.overrideWithValue(
          AsyncData(connectivityNotifier.value),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );

  // Initially online — no banner
  expect(find.text('Offline'), findsNothing);

  // Go offline
  connectivityNotifier.value = false;
  await tester.pumpAndSettle();

  // Banner should appear
  expect(find.byType(ConnectivityBadge), findsOneWidget);
});
```

### Testing Offline in Integration Tests (Firestore Network Toggle)

```dart
testWidgets('offline writes sync after reconnect', (tester) async {
  final firestore = FirebaseFirestore.instance;

  // Go offline
  await firestore.disableNetwork();

  // Write while offline
  final ref = firestore.collection('groups/g1/expenses').doc('offline-e1');
  await ref.set({'description': 'Offline expense', 'amount': 3000});

  // Verify local-only
  final localSnap = await ref.get();
  expect(localSnap.metadata.hasPendingWrites, isTrue);

  // Go online
  await firestore.enableNetwork();
  await Future.delayed(const Duration(seconds: 3));

  // Verify synced
  final syncedSnap = await ref.get();
  expect(syncedSnap.metadata.hasPendingWrites, isFalse);
  expect(syncedSnap.data()!['description'], 'Offline expense');
});
```

---

## 8. Flaky Test Prevention

Flaky tests erode trust in the test suite. Follow these rules strictly.

### Rules

| Rule | Why | How |
|---|---|---|
| **Never depend on real time** | Wall-clock time varies between runs | Use `clock` package or `withClock()` for controllable time; use `fakeAsync` for timer-dependent code |
| **Never depend on test execution order** | Tests run in arbitrary order in CI | Each test must set up its own state in `setUp()` and clean up in `tearDown()` |
| **Always clean up state** | Leaked state causes phantom failures | Call `tearDown()` to dispose controllers, close streams, clear mocks |
| **Use deterministic IDs** | Random UUIDs make assertions impossible | In tests, inject a `FakeIdGenerator` that returns predictable IDs (`e1`, `e2`, ...) |
| **Never hit real Firebase** | Network calls are slow and unreliable | Unit/widget tests use mocks; integration tests use emulators |
| **Set `pumpAndSettle()` timeout** | Infinite animations cause test hangs | `await tester.pumpAndSettle(timeout: const Duration(seconds: 5))` |
| **Avoid `Future.delayed()` in tests** | Real delays slow down tests and cause races | Use `fakeAsync` + `elapse()` or `pumpAndSettle()` |
| **Don't assert on exact timestamps** | Timestamps differ by microseconds between runs | Assert within a tolerance: `expect(timestamp.difference(expected).inSeconds, lessThan(2))` |
| **Isolate Riverpod state** | Shared `ProviderContainer` leaks between tests | Create a new `ProviderScope` / `ProviderContainer` in each test's `setUp()` |

### Fake Clock Example

```dart
import 'package:clock/clock.dart';

test('expense created with current time', () {
  withClock(Clock.fixed(DateTime(2024, 6, 15, 12, 0)), () {
    final expense = createExpense(description: 'Lunch', amount: 10000);
    expect(expense.createdAt, DateTime(2024, 6, 15, 12, 0));
  });
});
```

### Fake ID Generator

```dart
// lib/core/utils/id_generator.dart
abstract class IdGenerator {
  String generate();
}

class UuidIdGenerator implements IdGenerator {
  @override
  String generate() => const Uuid().v4();
}

// test/helpers/fake_id_generator.dart
class FakeIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String generate() => 'fake-id-${++_counter}';
}
```

### Preventing `pumpAndSettle()` Hangs

```dart
// BAD — hangs if there's an infinite animation (e.g., CircularProgressIndicator)
await tester.pumpAndSettle();

// GOOD — times out after 5 seconds
await tester.pumpAndSettle(timeout: const Duration(seconds: 5));

// BEST — pump specific frames when you know the animation duration
await tester.pump(const Duration(milliseconds: 300)); // one animation frame
```

### CI-Specific Flakiness

```yaml
# In CI, run tests with --reporter=expanded to see which test is slow/flaky
flutter test --reporter=expanded --timeout=60s

# Run flaky tests 3 times to confirm failure
flutter test --reporter=expanded --repeat=3 test/path/to/flaky_test.dart
```

---

## Quick Reference: Which Test for Which Change?

| I'm changing... | Write this test type | Run this command |
|---|---|---|
| Split algorithm | Unit test | `flutter test test/core/utils/` |
| Domain entity | Unit test (equality, copyWith) | `flutter test test/domain/entities/` |
| Use case | Unit test (mocked repos) | `flutter test test/domain/usecases/` |
| Repository impl | Unit test (mocked data sources) | `flutter test test/data/repositories/` |
| Mapper | Unit test (round-trip) | `flutter test test/data/mappers/` |
| Screen UI | Widget test | `flutter test test/presentation/features/` |
| Riverpod provider | Unit test (ProviderContainer) | `flutter test test/presentation/providers/` |
| Firestore query | Integration test (emulator) | `flutter test integration_test/ --dart-define=USE_EMULATOR=true` |
| Security rules | Integration test (emulator) | `firebase emulators:exec 'npm test'` |
| Cloud Function | Integration test (emulator) | `firebase emulators:exec 'npm test'` |
| Offline sync | Integration test (network toggle) | `flutter test integration_test/ --dart-define=USE_EMULATOR=true` |
| Critical user flow | E2E test | `flutter test integration_test/e2e/` |
| Bug fix | Unit test first (reproduce) | `flutter test` → fix → `flutter test` |
