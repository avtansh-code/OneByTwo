---
name: expense-split-validation
description: Guide for validating expense split calculations in the One By Two app. Use this when implementing or debugging any split calculation (equal, percentage, shares, itemized) to ensure correctness.
---

## Core Invariants

Every split calculation MUST satisfy these invariants. If any invariant is violated, the calculation is **wrong**.

### Invariant 1: Total Preservation
```
sum(all_split_amounts) == expense_total_in_paise
```
No paise may be lost or gained. This must hold for ALL split types.

### Invariant 2: Non-negativity
```
∀ split: split.amount_owed >= 0
```
No participant can owe a negative amount.

### Invariant 3: Fairness (Equal Split Only)
```
max(splits) - min(splits) <= 1 paise
```
In an equal split, no two participants should differ by more than 1 paisa.

### Invariant 4: Percentage Sum
```
sum(percentages) == 100.0 (within ±0.01 tolerance)
```

### Invariant 5: Itemized Total
```
sum(item_amounts) + tax + tip == expense_total
```
All items plus tax and tip must equal the total.

## Validation Checklist

When implementing or reviewing split code, verify:

- [ ] All amounts are integers (paise), no `double` used for money
- [ ] Remainder distributed using Largest Remainder Method (not truncated/lost)
- [ ] `equalSplit(total, n)` returns exactly `n` elements summing to `total`
- [ ] Percentage split handles 33.33 / 33.33 / 33.34 without losing a paisa
- [ ] Shares split converts to percentages before applying percentage algorithm
- [ ] Itemized split distributes tax/tip proportionally to each person's subtotal
- [ ] Final rounding correction applied to first user (deterministic)
- [ ] Edge case: 1 participant → gets full amount
- [ ] Edge case: amount < participants → some get 0
- [ ] Edge case: amount = 0 → all get 0

## Testing Template

```dart
void verifySplitInvariants(List<int> splits, int expectedTotal) {
  // Invariant 1: Total preservation
  expect(splits.reduce((a, b) => a + b), expectedTotal,
    reason: 'Split sum must equal total');

  // Invariant 2: Non-negativity
  for (final s in splits) {
    expect(s, greaterThanOrEqualTo(0),
      reason: 'Split amount must be non-negative');
  }
}

void verifyEqualSplitFairness(List<int> splits) {
  final maxSplit = splits.reduce(max);
  final minSplit = splits.reduce(min);
  expect(maxSplit - minSplit, lessThanOrEqualTo(1),
    reason: 'Equal split difference must be ≤ 1 paisa');
}
```

## Reference

See `docs/architecture/10_ALGORITHMS.md` for full algorithm specifications with worked examples.
