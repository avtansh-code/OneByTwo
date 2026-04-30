---
name: simplified-debts-test-case
description: >
  Use when the simplified-debts algorithm needs its canonical test matrix generated,
  verified, or extended. Contains the authoritative test cases.
---

# Simplified Debts Test Case

## When to use

When writing, verifying, or extending the test suite for the simplified-debts
algorithm (`functions/src/simplifiedDebts.ts`). This skill contains the canonical
test matrix that is a required check in the PR pipeline.

## When NOT to use

- When the task is about UI display of balances (route to Flutter Dev with
  `write-widget-test`).
- When the task is about security rules for `simplifiedBalances` (use
  `write-security-rule`).

## Inputs

1. **Context** — writing new tests, verifying existing tests, or extending for
   edge cases.
2. **Algorithm implementation** — the current `simplifiedDebts.ts` source.

## Procedure

1. Read SRS section 7.4 (Simplified Debts Algorithm Specification).
2. Read `.github/shared/invariants.md` (especially invariant 1: integer paise).
3. Read `.github/shared/test-strategy.md` (canonical test matrix).
4. Implement or verify each test case below.

## Canonical Test Matrix

All values are in **integer paise**. User IDs are strings sorted ascending for
deterministic tie-breaking.

### Case 1: Empty

- **Input:** no expenses, no settlements, members: `[]`
- **Expected:** `simplifiedBalances` is `{}`

### Case 2: Single member

- **Input:** 1 expense: user `"A"` paid 10000 paise for self only
- **Members:** `["A"]`
- **Expected:** `simplifiedBalances` is `{}` (no debts — A owes only themselves)

### Case 3: Perfectly balanced

- **Input:** 2 expenses in a group of `["A", "B"]`:
  - Expense 1: `"A"` paid 5000, split equally → A: 2500, B: 2500
  - Expense 2: `"B"` paid 5000, split equally → A: 2500, B: 2500
- **Expected:** `simplifiedBalances` is `{}` (nets to zero)

### Case 4: Cyclic debts that simplify to zero

- **Input:** 3 expenses in a group of `["A", "B", "C"]`:
  - Expense 1: `"A"` paid 3000, only `"B"` owes → B: 3000
  - Expense 2: `"B"` paid 3000, only `"C"` owes → C: 3000
  - Expense 3: `"C"` paid 3000, only `"A"` owes → A: 3000
- **Net:** A = 0, B = 0, C = 0
- **Expected:** `simplifiedBalances` is `{}`

### Case 5: 3-person canonical

- **Input:** 1 expense in a group of `["A", "B", "C"]`:
  - `"A"` paid 60000 (600 rupees), split equally → A: 20000, B: 20000, C: 20000
- **Net:** A = +40000, B = -20000, C = -20000
- **Expected:** `simplifiedBalances` is:
  ```json
  {
    "B": { "A": 20000 },
    "C": { "A": 20000 }
  }
  ```
  (B owes A 200 rupees, C owes A 200 rupees)

### Case 6: 5-person canonical

- **Input:** 3 expenses in a group of `["A", "B", "C", "D", "E"]`:
  - Expense 1: `"A"` paid 100000 (1000 rupees), split equally →
    each: 20000 paise
  - Expense 2: `"B"` paid 50000 (500 rupees), split equally →
    each: 10000 paise
  - Expense 3: `"C"` paid 25000 (250 rupees), split equally →
    each: 5000 paise
- **Net balances:**
  - A: paid 100000, owes 35000 → net = +65000
  - B: paid 50000, owes 35000 → net = +15000
  - C: paid 25000, owes 35000 → net = -10000
  - D: paid 0, owes 35000 → net = -35000
  - E: paid 0, owes 35000 → net = -35000
- **Simplified (greedy, tie-break by ascending userId):**
  1. D (-35000) pays A (+65000) → 35000. A now +30000, D now 0.
  2. E (-35000) pays A (+30000) → 30000. A now 0, E now -5000.
  3. E (-5000) pays B (+15000) → 5000. B now +10000, E now 0.
  4. C (-10000) pays B (+10000) → 10000. B now 0, C now 0.
- **Expected:** `simplifiedBalances` is:
  ```json
  {
    "C": { "B": 10000 },
    "D": { "A": 35000 },
    "E": { "A": 30000, "B": 5000 }
  }
  ```

### Additional edge cases (recommended)

- **Settlement reduces debt:** after case 5, B settles 10000 paise to A.
  New expected: `{ "B": { "A": 10000 }, "C": { "A": 20000 } }`.
- **Large group (50 members):** performance test — function completes in
  <= 500 ms (SRS section 5.2).
- **All-zero after settlements:** all debts settled, result is `{}`.

## Output format

TypeScript test file using `firebase-functions-test` with `describe` and `it`
blocks for each case. Each test:
1. Constructs the expense/settlement input data.
2. Calls the pure `simplifyDebts()` function.
3. Asserts the output matches the expected `simplifiedBalances`.

## Validation checks

- [ ] All 6 canonical cases are implemented.
- [ ] All values are integer paise (no floats in test data).
- [ ] Tie-breaking is verified (ascending userId).
- [ ] Determinism is verified (same input always produces same output).
- [ ] Performance case is included for 50-member group.
- [ ] Settlement-related edge cases are included.

## Examples

### Positive example

**Input:** "Generate the test suite for the simplified-debts algorithm."

**Output:** A complete TypeScript test file with all 6 canonical cases plus edge
cases, each with explicit expected output in paise.

### Negative example (should refuse)

**Input:** "Write tests that verify the raw payer-to-payee debt graph."

**Response:** Refused. SRS section 4.6 (FR-SE-01) states that only Simplified
Debts are exposed. The raw debt graph is not displayed to users and does not
need dedicated tests. The expense and settlement log serves as the immutable
audit trail.
