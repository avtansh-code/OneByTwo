---
name: expense-split-validation
description: "Core invariants for expense splitting, validation checklist, and testing templates. Ensures all split calculations are mathematically correct and preserve money integrity."
---

# Expense Split Validation

## 5 Core Invariants

**EVERY split calculation must satisfy ALL 5 invariants. No exceptions.**

| # | Invariant | Check |
|---|-----------|-------|
| 1 | **Sum Integrity** | `sum(all_split_amounts) == expense.totalAmount` — exact equality, not approximate |
| 2 | **Integer Amounts** | Every split amount is an `int` (paise). No `double` anywhere in money calculations. |
| 3 | **Non-Negative** | Every split amount ≥ 0 (zero is valid for "not participating") |
| 4 | **Fairness** | For equal splits: `max(splits) - min(splits) ≤ 1` (at most 1 paisa difference) |
| 5 | **Participant Coverage** | Every selected participant has exactly one split entry |

---

## Validation Checklist

Use this checklist when implementing or reviewing any expense creation/edit logic:

### Expense-Level

- [ ] Total amount is a positive integer (> 0 paise)
- [ ] At least 1 participant selected
- [ ] At least 1 payer
- [ ] Sum of payer amounts == total amount
- [ ] Sum of split amounts == total amount
- [ ] No duplicate participant IDs
- [ ] Description is non-empty (trimmed)
- [ ] `createdBy` is a valid member of the group

### Split-Type Specific

- [ ] **Equal:** Number of participants > 0, remainder distributed correctly
- [ ] **Exact:** Sum of user-entered amounts == total amount
- [ ] **Percentage:** Sum of percentages == 100 (or 10000 basis points for precision)
- [ ] **Shares:** All shares are positive integers, at least 1 participant
- [ ] **Itemized:** Sum of item amounts == total amount
- [ ] **Itemized:** Every item assigned to ≥ 1 person
- [ ] Remainder is distributed using the Largest Remainder Method

---

## Split Type Algorithms

### Equal Split

```text
base = total ÷ n           (integer division)
remainder = total % n       (modulo)
First `remainder` participants get `base + 1`
Remaining participants get `base`
```

Example: 10000 paise ÷ 3 = base 3333, remainder 1 → [3334, 3333, 3333]

```dart
List<int> equalSplit({required int totalPaise, required int participants}) {
  assert(participants > 0);
  assert(totalPaise >= 0);

  final base = totalPaise ~/ participants;
  final remainder = totalPaise % participants;

  return List.generate(participants, (i) => i < remainder ? base + 1 : base);
}
```

### Exact Split

User specifies exact amounts. Only validation needed:

```dart
bool validateExactSplit(List<int> amounts, int totalPaise) {
  return amounts.every((a) => a >= 0) &&
         amounts.reduce((a, b) => a + b) == totalPaise;
}
```

### Percentage Split

```text
raw_amount[i] = total × percentage[i] / 100
floor_amount[i] = floor(raw_amount[i])
remainder_fraction[i] = raw_amount[i] - floor_amount[i]
shortfall = total - sum(floor_amounts)
Assign +1 to the `shortfall` entries with largest remainder_fraction
```

```dart
List<int> percentageSplit({
  required int totalPaise,
  required List<double> percentages,
}) {
  assert((percentages.reduce((a, b) => a + b) - 100.0).abs() < 0.01);

  final rawAmounts = percentages.map((p) => totalPaise * p / 100).toList();
  final floorAmounts = rawAmounts.map((a) => a.floor()).toList();
  final remainders = List.generate(
    rawAmounts.length,
    (i) => MapEntry(i, rawAmounts[i] - floorAmounts[i]),
  );

  int shortfall = totalPaise - floorAmounts.reduce((a, b) => a + b);

  // Largest Remainder Method: sort by fractional part descending
  remainders.sort((a, b) => b.value.compareTo(a.value));
  for (int i = 0; i < shortfall; i++) {
    floorAmounts[remainders[i].key] += 1;
  }

  return floorAmounts;
}
```

### Shares Split

```text
total_shares = sum(all shares)
raw_amount[i] = total × shares[i] / total_shares
Apply Largest Remainder Method (same as percentage)
```

```dart
List<int> sharesSplit({
  required int totalPaise,
  required List<int> shares,
}) {
  final totalShares = shares.reduce((a, b) => a + b);
  assert(totalShares > 0);

  final rawAmounts = shares.map((s) => totalPaise * s / totalShares).toList();
  final floorAmounts = rawAmounts.map((a) => a.floor()).toList();
  final remainders = List.generate(
    rawAmounts.length,
    (i) => MapEntry(i, rawAmounts[i] - floorAmounts[i]),
  );

  int shortfall = totalPaise - floorAmounts.reduce((a, b) => a + b);
  remainders.sort((a, b) => b.value.compareTo(a.value));
  for (int i = 0; i < shortfall; i++) {
    floorAmounts[remainders[i].key] += 1;
  }

  return floorAmounts;
}
```

### Itemized Split

Each item is assigned to one or more users. Each item's cost is split among its assignees.

```text
For each item:
  item_split = equalSplit(item.amountPaise, item.assignees.length)
  Add each participant's share to their running total
Validate: sum(all participant totals) == expense.totalAmount
```

---

## Dart Testing Template

### Invariant Validation Helpers

```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void validateSplitInvariants(List<int> splits, int totalPaise) {
  // Invariant 1: Sum integrity
  expect(splits.reduce((a, b) => a + b), totalPaise,
    reason: 'Split sum must equal total');

  // Invariant 2: Integer amounts (enforced by Dart's type system for int)

  // Invariant 3: Non-negative
  expect(splits.every((s) => s >= 0), true,
    reason: 'All splits must be non-negative');
}

void validateEqualSplitFairness(List<int> splits) {
  final positiveSplits = splits.where((s) => s > 0).toList();
  if (positiveSplits.isEmpty) return;

  // Invariant 4: Fairness
  final maxSplit = positiveSplits.reduce(max);
  final minSplit = positiveSplits.reduce(min);
  expect(maxSplit - minSplit, lessThanOrEqualTo(1),
    reason: 'Equal split difference must be ≤ 1 paisa');
}

void validateParticipantCoverage(
  Map<String, int> splits,
  List<String> expectedParticipants,
) {
  // Invariant 5: Participant coverage
  expect(splits.keys.toSet(), expectedParticipants.toSet(),
    reason: 'Every participant must have exactly one split entry');
}
```

### Comprehensive Test Cases

```dart
void main() {
  group('Equal Split Invariants', () {
    final testCases = [
      (total: 10000, n: 2, expected: [5000, 5000]),
      (total: 10000, n: 3, expected: [3334, 3333, 3333]),
      (total: 10000, n: 1, expected: [10000]),
      (total: 1, n: 3, expected: [1, 0, 0]),
      (total: 0, n: 5, expected: [0, 0, 0, 0, 0]),
      (total: 7, n: 3, expected: [3, 2, 2]),
      (total: 100, n: 7, expected: [15, 15, 14, 14, 14, 14, 14]),
      (total: 2147483647, n: 2, expected: [1073741824, 1073741823]), // max int
    ];

    for (final tc in testCases) {
      test('split ${tc.total} among ${tc.n}', () {
        final result = equalSplit(totalPaise: tc.total, participants: tc.n);
        expect(result, tc.expected);
        validateSplitInvariants(result, tc.total);
        validateEqualSplitFairness(result);
      });
    }
  });

  group('Percentage Split Invariants', () {
    test('three-way 33.33/33.33/33.34', () {
      final result = percentageSplit(
        totalPaise: 10000,
        percentages: [33.33, 33.33, 33.34],
      );
      validateSplitInvariants(result, 10000);
    });

    test('two-way 50/50', () {
      final result = percentageSplit(
        totalPaise: 9999,
        percentages: [50, 50],
      );
      validateSplitInvariants(result, 9999);
    });

    test('uneven percentages', () {
      final result = percentageSplit(
        totalPaise: 10000,
        percentages: [10, 20, 30, 40],
      );
      expect(result, [1000, 2000, 3000, 4000]);
      validateSplitInvariants(result, 10000);
    });
  });

  group('Shares Split Invariants', () {
    test('unequal shares', () {
      final result = sharesSplit(totalPaise: 10000, shares: [2, 1, 1]);
      expect(result, [5000, 2500, 2500]);
      validateSplitInvariants(result, 10000);
    });

    test('prime number shares', () {
      final result = sharesSplit(totalPaise: 10000, shares: [3, 5, 7]);
      validateSplitInvariants(result, 10000);
    });
  });
}
```

---

## Common Bugs to Watch

| Bug | Why It Happens | Fix |
|-----|---------------|-----|
| Floating-point splits | Using `total / n` (returns `double` in Dart) | Use `total ~/ n` for integer division |
| Lost paise | Integer division truncation without remainder handling | Always distribute remainder via Largest Remainder Method |
| Off-by-one in percentage | Percentages sum to 99.99% or 100.01% | Validate percentage sum, use basis points (10000 = 100%) |
| Itemized sum mismatch | Items added/removed without revalidating total | Re-validate `sum(items) == total` on every item change |
| Negative split | Subtracting adjustments can go below 0 | Clamp to 0, redistribute the deficit |
| Duplicate participants | Same user ID added twice to split | Use `Set<String>` for participant IDs |

---

## Code Review Checklist for Splits

When reviewing any PR that touches split logic:

- [ ] Are all 5 invariants enforced in the code?
- [ ] Is the Largest Remainder Method used for rounding?
- [ ] Are all amounts `int` (paise), never `double`?
- [ ] Are there tests for: 0 paise, 1 paise, max int, prime divisors?
- [ ] Does the UI prevent submission if validation fails?
- [ ] Are error messages clear (e.g., "Amounts don't add up: ₹99.99 of ₹100.00")?
- [ ] Is the split recalculated when participants are added/removed?
