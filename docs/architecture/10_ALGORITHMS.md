# One By Two — Key Algorithms Reference

> **Version:** 1.0  
> **Last Updated:** 2026-02-14

This document is a consolidated, detailed reference of **every non-trivial algorithm** used in the One By Two app. Each algorithm includes its purpose, formal specification, pseudocode, complexity analysis, edge cases, and worked examples.

---

## Table of Contents

1. [Equal Split](#1-equal-split)
2. [Exact Amount Split](#2-exact-amount-split)
3. [Percentage Split](#3-percentage-split)
4. [Shares (Fraction) Split](#4-shares-fraction-split)
5. [Itemized Bill Split](#5-itemized-bill-split)
6. [Balance Calculation (Pairwise)](#6-balance-calculation-pairwise)
7. [Debt Simplification (Minimum Transactions)](#7-debt-simplification-minimum-transactions)
8. [Settle-All Plan Generation](#8-settle-all-plan-generation)
9. [Sync Queue Processing & Retry](#9-sync-queue-processing--retry)
10. [Conflict Resolution](#10-conflict-resolution)
11. [Recurring Expense Scheduling](#11-recurring-expense-scheduling)
12. [Guest-to-User Data Migration](#12-guest-to-user-data-migration)
13. [Invite Code Generation & Validation](#13-invite-code-generation--validation)
14. [Local Search Ranking](#14-local-search-ranking)
15. [Balance Pair Canonical Key](#15-balance-pair-canonical-key)
16. [Remainder Distribution (Largest Remainder Method)](#16-remainder-distribution-largest-remainder-method)
17. [Group Balance Aggregation (My Balance)](#17-group-balance-aggregation-my-balance)
18. [Notification Fan-Out](#18-notification-fan-out)

---

## 1. Equal Split

### Purpose
Divide an expense equally among N participants using integer arithmetic, ensuring the total is preserved exactly (no floating-point drift).

### Formal Specification

```
FUNCTION equalSplit(totalPaise: int, n: int) → List<int>

PRE-CONDITIONS:
  totalPaise > 0
  n > 0

POST-CONDITIONS:
  result.length == n
  sum(result) == totalPaise
  max(result) - min(result) <= 1   (fairness: differ by at most 1 paisa)

ALGORITHM:
  base ← totalPaise DIV n          // integer floor division
  remainder ← totalPaise MOD n     // leftover paise (0 ≤ remainder < n)

  result ← array of n elements, each = base

  // Distribute remainder: first `remainder` participants get 1 extra paisa
  FOR i FROM 0 TO remainder - 1:
    result[i] ← result[i] + 1

  RETURN result
```

### Complexity
- **Time:** O(n)
- **Space:** O(n)

### Worked Example

```
Input:  totalPaise = 10000 (₹100.00), n = 3
  base      = 10000 ÷ 3 = 3333
  remainder = 10000 % 3 = 1

Output: [3334, 3333, 3333] → [₹33.34, ₹33.33, ₹33.33]
Sum:    3334 + 3333 + 3333 = 10000 ✓

Input:  totalPaise = 1000 (₹10.00), n = 7
  base      = 1000 ÷ 7 = 142
  remainder = 1000 % 7 = 6

Output: [143, 143, 143, 143, 143, 143, 142]
Sum:    143×6 + 142 = 858 + 142 = 1000 ✓
```

### Edge Cases
| Case | Handling |
|------|----------|
| n = 1 | Result = [totalPaise] |
| totalPaise < n | Some people get 0 paise (e.g., 2 paise ÷ 5 = [1, 1, 0, 0, 0]) |
| totalPaise = 0 | Result = [0, 0, ..., 0] |

### Fairness Note
The remainder is distributed to participants in **insertion order** (which corresponds to the order members were added to the group). For repeated splits, this means the same person may consistently receive the extra paisa. An enhancement (Phase 2+) could rotate the starting index based on a hash of the expense ID to randomize fairness.

---

## 2. Exact Amount Split

### Purpose
Each participant's share is explicitly specified. Validate that all shares sum to the expense total.

### Formal Specification

```
FUNCTION exactSplit(totalPaise: int, amounts: Map<userId, int>) → Result<Map<userId, int>>

PRE-CONDITIONS:
  totalPaise > 0
  amounts.values.every(v => v >= 0)

VALIDATION:
  assignedTotal ← sum(amounts.values)

  IF assignedTotal != totalPaise:
    RETURN Error("Assigned total (₹{assignedTotal/100}) does not match 
                  expense total (₹{totalPaise/100}). 
                  Difference: ₹{abs(assignedTotal - totalPaise)/100}")

POST-CONDITIONS:
  sum(result.values) == totalPaise

ALGORITHM:
  // No computation needed — amounts are user-provided
  RETURN Ok(amounts)
```

### Complexity
- **Time:** O(n) for validation
- **Space:** O(1) (input is output)

### Edge Cases
| Case | Handling |
|------|----------|
| One participant gets 0 | Valid — they're included but owe nothing |
| Sum exceeds total | Error returned with difference amount |
| Sum less than total | Error returned with difference amount |

---

## 3. Percentage Split

### Purpose
Divide an expense according to percentages. Handle rounding so the total in paise is preserved exactly.

### Formal Specification

```
FUNCTION percentageSplit(totalPaise: int, pcts: Map<userId, double>) → Result<Map<userId, int>>

PRE-CONDITIONS:
  totalPaise > 0
  abs(sum(pcts.values) - 100.0) < 0.01   // must sum to ~100%
  pcts.values.every(v => v >= 0)

ALGORITHM:
  // Step 1: Compute raw (fractional) amounts
  rawAmounts ← {}
  FOR (userId, pct) IN pcts:
    rawAmounts[userId] ← totalPaise × pct / 100.0

  // Step 2: Apply Largest Remainder Method (see Algorithm #16)
  result ← largestRemainderDistribution(totalPaise, rawAmounts)

  RETURN Ok(result)

POST-CONDITIONS:
  sum(result.values) == totalPaise       // exact total preserved
  ∀ userId: abs(result[userId] - rawAmounts[userId]) < 1  // at most 1 paisa off
```

### Complexity
- **Time:** O(n log n) — dominated by sort in largest remainder
- **Space:** O(n)

### Worked Example

```
Input:  totalPaise = 10000 (₹100.00)
        pcts = {A: 33.33%, B: 33.33%, C: 33.34%}

Raw:    A = 10000 × 0.3333 = 3333.0
        B = 10000 × 0.3333 = 3333.0
        C = 10000 × 0.3334 = 3334.0

Floor:  A = 3333, B = 3333, C = 3334
Sum:    9999 + 1 remaining → distributed to A (highest fractional part, tied)

Result: {A: 3334, B: 3333, C: 3334}
Sum:    10001? NO — let me redo:

Correct raw: A = 3333.0 (frac 0.0), B = 3333.0 (frac 0.0), C = 3334.0 (frac 0.0)
Floor sum:   3333 + 3333 + 3334 = 10000 ✓ (no remainder needed)

Better example:
Input:  totalPaise = 10000, pcts = {A: 33.3%, B: 33.3%, C: 33.4%}
Raw:    A = 3330.0, B = 3330.0, C = 3340.0
Floor:  3330 + 3330 + 3340 = 10000 ✓

Even better:
Input:  totalPaise = 1000, pcts = {A: 33.33%, B: 33.33%, C: 33.34%}
Raw:    A = 333.3, B = 333.3, C = 333.4
Floor:  333 + 333 + 333 = 999
Remainder: 1
Fractional parts: A=0.3, B=0.3, C=0.4
Sort desc: C(0.4), A(0.3), B(0.3)
Give 1 to C → C = 334

Result: {A: 333, B: 333, C: 334}
Sum:    1000 ✓
```

### Edge Cases
| Case | Handling |
|------|----------|
| Percentages sum to 99.99% | Round to 100%, redistribute 0.01% |
| One person at 100% | They get the full amount |
| Very small percentages (0.01%) on large amounts | Might round to 0; minimum 0 paise is valid |

---

## 4. Shares (Fraction) Split

### Purpose
Divide an expense proportionally according to share counts (e.g., 2 shares, 1 share, 1 share).

### Formal Specification

```
FUNCTION sharesSplit(totalPaise: int, shares: Map<userId, double>) → Result<Map<userId, int>>

PRE-CONDITIONS:
  totalPaise > 0
  shares.values.every(v => v > 0)
  sum(shares.values) > 0

ALGORITHM:
  totalShares ← sum(shares.values)

  // Convert shares to percentages
  pcts ← {}
  FOR (userId, s) IN shares:
    pcts[userId] ← (s / totalShares) × 100.0

  // Delegate to percentage split
  RETURN percentageSplit(totalPaise, pcts)
```

### Complexity
- **Time:** O(n log n) — same as percentage split
- **Space:** O(n)

### Worked Example

```
Input:  totalPaise = 12000 (₹120.00)
        shares = {A: 2, B: 1, C: 1}
        totalShares = 4

Percentages: A = 50%, B = 25%, C = 25%

Raw amounts: A = 6000, B = 3000, C = 3000
Result:      {A: 6000, B: 3000, C: 3000}
Sum:         12000 ✓

Harder:
Input:  totalPaise = 10000, shares = {A: 1, B: 1, C: 1}
        totalShares = 3
        Each = 33.33̄%
        Raw: 3333.33̄ each
        Floor: 3333 × 3 = 9999, remainder = 1
        Result: {A: 3334, B: 3333, C: 3333}
```

---

## 5. Itemized Bill Split

### Purpose
Split a bill where individual items are assigned to specific people, with tax and tip distributed proportionally based on each person's item subtotal.

### Formal Specification

```
FUNCTION itemizedSplit(
  items: List<{name: String, amountPaise: int, assignedTo: List<userId>}>,
  taxPaise: int,
  tipPaise: int
) → Map<userId, int>

PRE-CONDITIONS:
  items.isNotEmpty
  items.every(i => i.amountPaise >= 0 && i.assignedTo.isNotEmpty)
  taxPaise >= 0
  tipPaise >= 0

ALGORITHM:
  userItemTotals ← Map<String, int>{}
  subtotalPaise ← 0

  // STEP 1: Distribute item costs using equal split per item
  FOR item IN items:
    perPerson ← equalSplit(item.amountPaise, item.assignedTo.length)
    FOR (i, userId) IN item.assignedTo.enumerate():
      userItemTotals[userId] ← (userItemTotals[userId] ?? 0) + perPerson[i]
    subtotalPaise ← subtotalPaise + item.amountPaise

  // STEP 2: Distribute tax proportionally to item subtotals
  IF taxPaise > 0 AND subtotalPaise > 0:
    taxShares ← {}
    FOR (userId, itemTotal) IN userItemTotals:
      taxShares[userId] ← itemTotal  // proportion = itemTotal / subtotal
    taxDistribution ← proportionalDistribute(taxPaise, taxShares)
    FOR (userId, taxAmount) IN taxDistribution:
      userItemTotals[userId] ← userItemTotals[userId] + taxAmount

  // STEP 3: Distribute tip proportionally (same method)
  IF tipPaise > 0 AND subtotalPaise > 0:
    tipShares ← {}
    FOR (userId, itemTotal) IN userItemTotals:
      tipShares[userId] ← itemTotal
    tipDistribution ← proportionalDistribute(tipPaise, tipShares)
    FOR (userId, tipAmount) IN tipDistribution:
      userItemTotals[userId] ← userItemTotals[userId] + tipAmount

  // STEP 4: Final correction — ensure exact total
  expectedTotal ← subtotalPaise + taxPaise + tipPaise
  actualTotal ← sum(userItemTotals.values)
  IF actualTotal != expectedTotal:
    diff ← expectedTotal - actualTotal
    // Adjust first user (deterministic)
    firstUser ← userItemTotals.keys.sorted().first
    userItemTotals[firstUser] ← userItemTotals[firstUser] + diff

  RETURN userItemTotals

POST-CONDITIONS:
  sum(result.values) == sum(items.amountPaise) + taxPaise + tipPaise
```

### Helper: Proportional Distribution

```
FUNCTION proportionalDistribute(totalPaise: int, weights: Map<userId, int>) → Map<userId, int>
  // Distributes totalPaise proportionally to weights using largest remainder method
  totalWeight ← sum(weights.values)
  rawAmounts ← {}
  FOR (userId, w) IN weights:
    rawAmounts[userId] ← totalPaise × w / totalWeight  // fractional
  RETURN largestRemainderDistribution(totalPaise, rawAmounts)
```

### Complexity
- **Time:** O(I × P + N log N) where I = items, P = avg participants per item, N = unique users
- **Space:** O(N)

### Worked Example

```
Bill at a restaurant:
  Items:
    Pizza       ₹450 (4500 paise)  → A, B
    Pasta       ₹380 (3800 paise)  → C
    Garlic Bread ₹200 (2000 paise) → A, B, C
    Coke ×3     ₹180 (1800 paise)  → A, B, C

  Tax: ₹60 (6000 paise — 5% of subtotal)
  Tip: ₹130 (13000 paise)
  Subtotal: ₹1210 (121000 paise... wait, let me use consistent smaller numbers)

Let me use simpler numbers:
  Items:
    Pizza       450 paise → A, B         (225, 225)
    Pasta       380 paise → C            (380)
    Bread       200 paise → A, B, C      (67, 67, 66)
    Coke        180 paise → A, B, C      (60, 60, 60)

  Step 1: Item totals:
    A: 225 + 67 + 60 = 352
    B: 225 + 67 + 60 = 352
    C: 380 + 66 + 60 = 506
    Subtotal check: 352 + 352 + 506 = 1210 ✓

  Step 2: Tax = 60 paise, distribute proportionally:
    A: 60 × 352/1210 = 17.45 → floor 17
    B: 60 × 352/1210 = 17.45 → floor 17
    C: 60 × 506/1210 = 25.09 → floor 25
    Floor sum: 59, remainder 1 → give to A (highest fractional 0.45)
    Tax: A=18, B=17, C=25
    Running: A=370, B=369, C=531

  Step 3: Tip = 130 paise, distribute proportionally:
    A: 130 × 370/1270 = 37.87 → floor 37
    B: 130 × 369/1270 = 37.77 → floor 37
    C: 130 × 531/1270 = 54.35 → floor 54
    Floor sum: 128, remainder 2 → give to A(0.87), C(0.35) — A, B in order of frac
    Tip: A=38, B=38, C=54
    Running: A=408, B=407, C=585

  Step 4: Total check:
    408 + 407 + 585 = 1400
    Expected: 1210 + 60 + 130 = 1400 ✓
```

---

## 6. Balance Calculation (Pairwise)

### Purpose
Compute the net pairwise balance between every pair of users in a group, accounting for all expenses and settlements. This drives the "who owes whom" display.

### Formal Specification

```
FUNCTION calculateGroupBalances(
  expenses: List<Expense>,      // active (non-deleted) expenses in group
  settlements: List<Settlement>  // active settlements in group
) → Map<BalancePairKey, int>    // positive = userA owes userB

TYPE BalancePairKey = (userA: String, userB: String)
  WHERE userA < userB (lexicographic — canonical ordering)

ALGORITHM:
  balances ← Map<BalancePairKey, int>{}

  // STEP 1: Process each expense
  FOR expense IN expenses:
    FOR payer IN expense.payers:
      FOR split IN expense.splits:
        IF payer.userId != split.userId:
          // payer paid on behalf of split.userId
          // so split.userId owes payer split.amountOwed
          key ← canonicalPair(split.userId, payer.userId)

          // Calculate this payer's contribution to this split
          // (handles multiple payers: each payer covers proportional share)
          payerRatio ← payer.amountPaid / expense.amount
          oweAmount ← (split.amountOwed × payerRatio).round()

          IF split.userId < payer.userId:
            // split.userId is userA, owes payer (userB) → positive
            balances[key] ← (balances[key] ?? 0) + oweAmount
          ELSE:
            // payer is userA, is owed by split.userId (userB) → negative
            balances[key] ← (balances[key] ?? 0) - oweAmount

  // STEP 2: Process each settlement
  FOR settlement IN settlements:
    key ← canonicalPair(settlement.fromUserId, settlement.toUserId)
    IF settlement.fromUserId < settlement.toUserId:
      // fromUser is userA, paid toUser → reduce what A owes B
      balances[key] ← (balances[key] ?? 0) - settlement.amount
    ELSE:
      // toUser is userA → fromUser(B) paid toUser(A) → A is now owed less
      balances[key] ← (balances[key] ?? 0) + settlement.amount

  RETURN balances

INTERPRETATION:
  balance[A, B] > 0 → A owes B that amount
  balance[A, B] < 0 → B owes A abs(amount)
  balance[A, B] = 0 → settled
```

### Complexity
- **Time:** O(E × P × S) where E = expenses, P = payers per expense, S = splits per expense. Typically O(E × N) for single-payer expenses where N = members.
- **Space:** O(N²) for pairwise balance map (N = members)

### Edge Cases
| Case | Handling |
|------|----------|
| Multiple payers | Each payer's contribution weighted by `amountPaid / totalAmount` |
| Self-payment (payer = participant) | Skipped — no balance entry for self |
| Deleted expense | Excluded from calculation (is_deleted = true filtered out) |
| Empty group | Returns empty map |

---

## 7. Debt Simplification (Minimum Transactions)

### Purpose
Given pairwise balances in a group, compute the **minimum number of transactions** needed to settle all debts. This reduces, e.g., 10 pairwise debts among 5 people to at most 4 transactions.

### Formal Specification

```
FUNCTION simplifyDebts(
  balances: Map<BalancePairKey, int>,
  memberNames: Map<userId, String>
) → List<SuggestedSettlement>

TYPE SuggestedSettlement = {
  fromUserId: String,   // person who pays
  fromName: String,
  toUserId: String,     // person who receives
  toName: String,
  amount: int           // paise
}

ALGORITHM:
  // STEP 1: Compute net balance per person
  //   net > 0 → person is owed (creditor)
  //   net < 0 → person owes (debtor)
  nets ← Map<String, int>{}

  FOR ((userA, userB), amount) IN balances:
    IF amount > 0:
      // A owes B
      nets[userA] ← (nets[userA] ?? 0) - amount  // A's net decreases
      nets[userB] ← (nets[userB] ?? 0) + amount  // B's net increases
    ELSE IF amount < 0:
      // B owes A
      nets[userB] ← (nets[userB] ?? 0) + amount  // B's net decreases (amount is negative)
      nets[userA] ← (nets[userA] ?? 0) - amount  // A's net increases

  // Invariant: sum(nets.values) == 0 (conservation of money)

  // STEP 2: Remove zero-balance members
  nets.removeWhere((_, v) => v == 0)

  // STEP 3: Separate into sorted lists
  debtors ← []   // (userId, absAmount) sorted descending by amount
  creditors ← [] // (userId, amount) sorted descending by amount

  FOR (userId, net) IN nets:
    IF net < 0:
      debtors.add((userId, -net))   // store as positive
    ELSE:
      creditors.add((userId, net))

  debtors.sortByDescending(amount)
  creditors.sortByDescending(amount)

  // STEP 4: Greedy matching (two-pointer)
  settlements ← []
  i ← 0   // debtor index
  j ← 0   // creditor index

  WHILE i < debtors.length AND j < creditors.length:
    debtor ← debtors[i]
    creditor ← creditors[j]
    settleAmount ← min(debtor.amount, creditor.amount)

    settlements.add({
      fromUserId: debtor.userId,
      fromName: memberNames[debtor.userId],
      toUserId: creditor.userId,
      toName: memberNames[creditor.userId],
      amount: settleAmount
    })

    debtors[i].amount ← debtors[i].amount - settleAmount
    creditors[j].amount ← creditors[j].amount - settleAmount

    IF debtors[i].amount == 0: i ← i + 1
    IF creditors[j].amount == 0: j ← j + 1

  RETURN settlements

POST-CONDITIONS:
  sum(settlements where from=X .amount) == abs(nets[X]) for all debtors X
  sum(settlements where to=Y .amount) == nets[Y] for all creditors Y
  settlements.length <= max(debtors.length, creditors.length)
  settlements.length <= N - 1 where N = members with non-zero balance
```

### Complexity
- **Time:** O(N log N) dominated by sorting, where N = members with non-zero balance
- **Space:** O(N)

### Worked Example

```
Group: 5 members (A, B, C, D, E)

Pairwise balances after expenses:
  A owes B: ₹500
  A owes C: ₹300
  B owes D: ₹200
  C owes E: ₹400
  D owes E: ₹100
  (5 pairwise debts)

Step 1: Net balances
  A: -500 - 300 = -800 (owes ₹800)
  B: +500 - 200 = +300 (owed ₹300)
  C: +300 - 400 = -100 (owes ₹100)
  D: +200 - 100 = +100 (owed ₹100)
  E: +400 + 100 = +500 (owed ₹500)
  Check: -800 + 300 - 100 + 100 + 500 = 0 ✓

Step 2: Separate
  Debtors:   [(A, 800), (C, 100)]  sorted desc
  Creditors: [(E, 500), (B, 300), (D, 100)]  sorted desc

Step 3: Greedy matching
  i=0 (A,800) vs j=0 (E,500): settle min(800,500)=500
    → A pays E ₹500.  A remaining: 300, E remaining: 0
    j++

  i=0 (A,300) vs j=1 (B,300): settle min(300,300)=300
    → A pays B ₹300.  A remaining: 0, B remaining: 0
    i++, j++

  i=1 (C,100) vs j=2 (D,100): settle min(100,100)=100
    → C pays D ₹100.  C remaining: 0, D remaining: 0
    i++, j++

Result: 3 settlements (down from 5 original debts)
  1. A → E: ₹500
  2. A → B: ₹300
  3. C → D: ₹100

Verification:
  A: paid 500 + 300 = 800 ✓ (net was -800)
  E: received 500 ✓ (net was +500)
  B: received 300 ✓ (net was +300)
  C: paid 100 ✓ (net was -100)
  D: received 100 ✓ (net was +100)
```

### Optimality Note
The greedy algorithm produces **at most N-1** transactions, which is optimal for the general case. However, it doesn't always produce the absolute minimum — for certain configurations, subset-sum matching can reduce further (e.g., if two people's debts exactly cancel, they can settle directly). The greedy approach is chosen for simplicity and O(n log n) performance; the NP-hard optimal solution is unnecessary for groups of ≤100 members.

---

## 8. Settle-All Plan Generation

### Purpose
Generate a complete settlement plan for an entire group and record all settlements atomically.

### Formal Specification

```
FUNCTION settleAll(groupId: String) → List<Settlement>

ALGORITHM:
  // Step 1: Fetch current balances
  balances ← getGroupBalances(groupId)

  // Step 2: Run debt simplification
  plan ← simplifyDebts(balances, getMembers(groupId))

  // Step 3: Record each settlement in a Firestore batch
  batch ← firestore.batch()
  settlements ← []

  FOR suggested IN plan:
    settlement ← Settlement(
      id: generateUUID(),
      groupId: groupId,
      fromUserId: suggested.fromUserId,
      toUserId: suggested.toUserId,
      amount: suggested.amount,
      date: now(),
      createdBy: currentUserId,
      version: 1
    )
    batch.set(
      groups/{groupId}/settlements/{settlement.id},
      settlement.toMap()
    )
    settlements.add(settlement)

  // Step 4: Commit atomically (all or nothing)
  batch.commit()

  // Step 5: Firestore trigger recalculates all balances → should be zero

  RETURN settlements
```

### Atomicity
- Uses Firestore batch write (max 500 operations)
- If any write fails, none are committed
- Balance recalculation triggered by `onSettlementCreated` after commit

---

## 9. Sync Queue Processing & Retry

### Purpose
Process pending local changes and push them to Firestore, with exponential backoff retry on failure.

### Formal Specification

```
FUNCTION processSyncQueue()

CONSTANTS:
  MAX_RETRIES = 5
  BASE_DELAY_MS = 2000
  MAX_DELAY_MS = 32000
  BATCH_SIZE = 10

ALGORITHM:
  WHILE true:
    // Fetch pending operations (oldest first)
    ops ← SELECT * FROM sync_queue
           WHERE status = 'pending'
           ORDER BY created_at ASC
           LIMIT BATCH_SIZE

    IF ops.isEmpty: BREAK

    FOR op IN ops:
      // Mark as in-progress
      UPDATE sync_queue SET status = 'in_progress' WHERE id = op.id

      TRY:
        SWITCH op.operation:
          CASE 'create':
            firestoreRef.set(deserialize(op.payload_json))
          CASE 'update':
            firestoreRef.update(deserialize(op.payload_json))
          CASE 'delete':
            firestoreRef.update({isDeleted: true, ...})

        // Success
        DELETE FROM sync_queue WHERE id = op.id
        UPDATE {entity_table} SET sync_status = 'synced'
          WHERE id = op.entity_id

      CATCH error:
        newRetryCount ← op.retry_count + 1

        IF newRetryCount >= MAX_RETRIES:
          UPDATE sync_queue SET
            status = 'failed',
            retry_count = newRetryCount,
            error_message = error.toString()
          WHERE id = op.id

          UPDATE {entity_table} SET sync_status = 'conflict'
            WHERE id = op.entity_id

        ELSE:
          // Exponential backoff
          delayMs ← min(BASE_DELAY_MS × 2^(newRetryCount - 1), MAX_DELAY_MS)
          SLEEP(delayMs)

          UPDATE sync_queue SET
            status = 'pending',
            retry_count = newRetryCount,
            last_attempted_at = now()
          WHERE id = op.id

BACKOFF SCHEDULE:
  Retry 1: 2s
  Retry 2: 4s
  Retry 3: 8s
  Retry 4: 16s
  Retry 5: 32s → FAIL (mark as conflict)
```

### Complexity
- **Time:** O(Q) per cycle where Q = pending queue items
- **Retry total wait:** Max 62 seconds across all retries before failure

---

## 10. Conflict Resolution

### Purpose
Resolve conflicts when the same entity is modified by different users (or the same user on different devices) while offline.

### Formal Specification

```
FUNCTION resolveConflict(
  localVersion: Entity,
  serverVersion: Entity
) → ConflictResolution

TYPE ConflictResolution =
  | AutoResolved(winner: Entity)
  | UserPromptRequired(local: Entity, server: Entity, conflictFields: List<String>)

ALGORITHM:
  // RULE 1: Delete always wins
  IF localVersion.isDeleted OR serverVersion.isDeleted:
    RETURN AutoResolved(winner: whichever has isDeleted = true)

  // RULE 2: Version comparison
  IF localVersion.version == serverVersion.version:
    // Both edited from the same base — true conflict
    GOTO field_comparison
  ELSE IF localVersion.version < serverVersion.version:
    // Server has newer version — server wins (we're behind)
    RETURN AutoResolved(winner: serverVersion)
  ELSE:
    // Local has newer version — shouldn't happen normally
    // Treat as true conflict
    GOTO field_comparison

  field_comparison:
    criticalFields ← ['amount', 'payers', 'splits']
    nonCriticalFields ← ['description', 'notes', 'category', 'date']

    changedCritical ← criticalFields.where(f =>
      localVersion[f] != serverVersion[f]
    )

    IF changedCritical.isEmpty:
      // Only non-critical fields differ → last-write-wins (by timestamp)
      winner ← localVersion.updatedAt > serverVersion.updatedAt
        ? localVersion : serverVersion
      RETURN AutoResolved(winner: winner)
    ELSE:
      // Critical fields differ → user must decide
      RETURN UserPromptRequired(
        local: localVersion,
        server: serverVersion,
        conflictFields: changedCritical
      )
```

### Resolution Strategies
| Scenario | Strategy |
|----------|----------|
| Both delete | Auto-resolve (delete wins) |
| One delete, one edit | Delete wins (auto) |
| Only non-critical fields differ | Last-write-wins by timestamp (auto) |
| Amount changed by both | User prompt (show both versions) |
| Splits changed by both | User prompt |
| New entity (create) | Always succeeds (unique UUIDs) |
| New settlement | Always succeeds |

---

## 11. Recurring Expense Scheduling

### Purpose
Automatically create expense instances from recurring templates on their scheduled dates.

### Formal Specification

```
FUNCTION processRecurringExpenses()
// Runs as scheduled Cloud Function, daily at 00:00 IST

ALGORITHM:
  today ← currentDate()  // IST timezone

  // Query all due recurring expenses
  dueExpenses ← SELECT FROM groups/*/expenses
    WHERE is_recurring = true
      AND is_deleted = false
      AND recurring_next_date <= today
      AND (recurring_end_date IS NULL OR recurring_end_date > today)

  batch ← firestore.batch()  // max 500 ops per batch
  opsCount ← 0

  FOR template IN dueExpenses:
    // Create new expense instance
    instance ← Expense(
      id: generateUUID(),
      groupId: template.groupId,
      description: template.description,
      amount: template.amount,
      date: template.recurring_next_date,
      category: template.category,
      splitType: template.splitType,
      payers: template.payers,     // same payer(s)
      splits: template.splits,      // same split config
      notes: "Auto-generated from recurring expense",
      createdBy: template.createdBy,
      isRecurring: false,            // instance, not template
      version: 1
    )

    batch.set(groups/{template.groupId}/expenses/{instance.id}, instance)
    opsCount++

    // Calculate next occurrence
    nextDate ← calculateNextDate(
      template.recurring_next_date,
      template.recurring_frequency,
      template.recurring_interval
    )

    batch.update(
      groups/{template.groupId}/expenses/{template.id},
      { recurring_next_date: nextDate }
    )
    opsCount++

    // Flush batch if approaching limit
    IF opsCount >= 498:
      batch.commit()
      batch ← firestore.batch()
      opsCount ← 0

  IF opsCount > 0:
    batch.commit()


FUNCTION calculateNextDate(
  currentDate: Date,
  frequency: String,
  interval: int
) → Date

  SWITCH frequency:
    CASE 'daily':
      RETURN currentDate + (interval days)

    CASE 'weekly':
      RETURN currentDate + (interval × 7 days)

    CASE 'monthly':
      targetMonth ← currentDate.month + interval
      targetYear ← currentDate.year + (targetMonth - 1) / 12
      targetMonth ← ((targetMonth - 1) % 12) + 1
      targetDay ← min(currentDate.day, daysInMonth(targetYear, targetMonth))
      RETURN Date(targetYear, targetMonth, targetDay)

    CASE 'yearly':
      targetYear ← currentDate.year + interval
      // Handle Feb 29 → Feb 28 in non-leap years
      targetDay ← min(currentDate.day, daysInMonth(targetYear, currentDate.month))
      RETURN Date(targetYear, currentDate.month, targetDay)
```

### Edge Cases
| Case | Handling |
|------|----------|
| Monthly on 31st → month with 30 days | Clamped to 30th |
| Monthly on 29th Feb → non-leap year | Clamped to Feb 28th |
| Missed days (function didn't run) | Catches up — processes all overdue dates |
| End date reached | Skip; template remains but no new instances |
| Template deleted | is_deleted = true → filtered out of query |

---

## 12. Guest-to-User Data Migration

### Purpose
When a guest user (invited via link, no account) later creates a full account, atomically merge their guest data into the new user identity.

### Formal Specification

```
FUNCTION migrateGuestToUser(guestId: String, newUserId: String)
// Runs as HTTPS Callable Cloud Function, inside Firestore transaction

ALGORITHM:
  runTransaction(async (txn) => {

    // STEP 1: Find all groups where guest is a member
    guestMemberships ← txn.getAll(
      collectionGroup('members').where('userId', '==', guestId)
    )

    FOR membership IN guestMemberships:
      groupId ← membership.ref.parent.parent.id

      // STEP 2: Update member document
      txn.update(membership.ref, {
        userId: newUserId,
        isGuest: false,
        name: newUser.name  // use registered name
      })

      // STEP 3: Update all expense splits in this group
      splits ← txn.getAll(
        collectionGroup('splits')
          .where('userId', '==', guestId)
          // scoped to this group's expenses
      )
      FOR split IN splits:
        txn.update(split.ref, { userId: newUserId })

      // STEP 4: Update all expense payers
      payers ← txn.getAll(
        collectionGroup('payers')
          .where('userId', '==', guestId)
      )
      FOR payer IN payers:
        txn.update(payer.ref, { userId: newUserId })

      // STEP 5: Update all settlements
      settlementsFrom ← getAll where fromUserId == guestId
      FOR s IN settlementsFrom:
        txn.update(s.ref, { fromUserId: newUserId })

      settlementsTo ← getAll where toUserId == guestId
      FOR s IN settlementsTo:
        txn.update(s.ref, { toUserId: newUserId })

      // STEP 6: Recalculate balances (new userId in canonical pairs)
      txn.delete(all balance docs containing guestId)
      // Balance recalculation will be triggered by onMemberUpdate

      // STEP 7: Create userGroups entry
      txn.set(userGroups/{newUserId}/groups/{groupId}, {
        groupId, groupName, role: membership.role, ...
      })

  })  // end transaction — all or nothing
```

### Constraints
- Firestore transactions have a max of 500 reads and 500 writes
- For guests in many groups with many expenses, may need batched transactions
- Migration is idempotent — safe to retry on failure

---

## 13. Invite Code Generation & Validation

### Purpose
Generate unique, hard-to-guess invite codes for group invitations, and validate them during join.

### Formal Specification

```
FUNCTION generateInviteCode() → String
  // 8-character base36 uppercase alphanumeric
  // Entropy: 36^8 ≈ 2.8 trillion combinations

  CHARACTERS ← 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  code ← ''
  FOR i FROM 1 TO 8:
    code ← code + CHARACTERS[secureRandom(0, 35)]

  // Verify uniqueness
  IF exists(invites/{code}):
    RETURN generateInviteCode()  // retry (collision probability ≈ 0)

  RETURN code


FUNCTION validateAndJoinInvite(code: String, userId: String, guestName: String?) → Result

  invite ← GET invites/{code}

  // Validation checks
  IF invite == null:
    RETURN Error("Invalid invite code")

  IF invite.isActive == false:
    RETURN Error("This invite link has been deactivated")

  IF invite.expiresAt != null AND invite.expiresAt < now():
    RETURN Error("This invite link has expired")

  IF invite.maxUses != null AND invite.useCount >= invite.maxUses:
    RETURN Error("This invite link has reached its usage limit")

  // Check if user already in group
  IF exists(groups/{invite.groupId}/members/{userId}):
    RETURN Error("You are already a member of this group")

  // Add member
  memberData ← {
    userId: userId ?? generateGuestId(),
    name: guestName ?? currentUser.name,
    role: 'member',
    isGuest: userId == null,
    guestName: guestName,
    joinedAt: now(),
    isActive: true,
    invitedBy: invite.createdBy
  }

  batch ← firestore.batch()
  batch.set(groups/{invite.groupId}/members/{memberData.userId}, memberData)
  batch.update(invites/{code}, { useCount: increment(1) })
  batch.update(groups/{invite.groupId}, { memberCount: increment(1) })
  batch.commit()

  RETURN Ok({ groupId: invite.groupId })
```

---

## 14. Local Search Ranking

### Purpose
Rank search results by relevance when searching across expenses, groups, and people locally.

### Formal Specification

```
FUNCTION searchAndRank(query: String) → List<SearchResult>

TYPE SearchResult = {
  type: 'expense' | 'group' | 'person',
  id: String,
  title: String,
  subtitle: String,
  relevanceScore: double,
  date: DateTime?
}

ALGORITHM:
  queryLower ← query.toLowerCase()
  results ← []

  // Search expenses
  expenses ← SELECT * FROM expenses
    WHERE is_deleted = 0
      AND (LOWER(description) LIKE '%{queryLower}%'
           OR LOWER(notes) LIKE '%{queryLower}%'
           OR LOWER(category) LIKE '%{queryLower}%')
    ORDER BY date DESC
    LIMIT 50

  FOR e IN expenses:
    score ← 0.0
    // Exact match in description → highest relevance
    IF e.description.toLowerCase() == queryLower:
      score ← 100
    ELSE IF e.description.toLowerCase().startsWith(queryLower):
      score ← 80
    ELSE IF e.description.toLowerCase().contains(queryLower):
      score ← 60
    // Match in notes → lower relevance
    ELSE IF e.notes?.toLowerCase().contains(queryLower):
      score ← 40
    // Match in category → lowest
    ELSE:
      score ← 20

    // Recency boost: newer expenses rank higher (decay over 30 days)
    daysSinceExpense ← (now() - e.date).inDays
    recencyBoost ← max(0, 10 - (daysSinceExpense / 3))
    score ← score + recencyBoost

    results.add(SearchResult(type: 'expense', ...score))

  // Search groups
  groups ← SELECT * FROM groups
    WHERE LOWER(name) LIKE '%{queryLower}%'
    ORDER BY last_activity_at DESC

  FOR g IN groups:
    score ← g.name.toLowerCase() == queryLower ? 100 :
            g.name.toLowerCase().startsWith(queryLower) ? 85 : 65
    results.add(SearchResult(type: 'group', ...score))

  // Search people
  users ← SELECT * FROM users
    WHERE LOWER(name) LIKE '%{queryLower}%'

  FOR u IN users:
    score ← u.name.toLowerCase() == queryLower ? 100 :
            u.name.toLowerCase().startsWith(queryLower) ? 85 : 65
    results.add(SearchResult(type: 'person', ...score))

  // Sort by relevance score descending, then by date
  results.sortBy(r => (-r.relevanceScore, -r.date))

  RETURN results
```

---

## 15. Balance Pair Canonical Key

### Purpose
Generate a deterministic, unique key for any pair of users, regardless of order. This ensures that A→B and B→A reference the same balance entry.

### Formal Specification

```
FUNCTION canonicalPair(userId1: String, userId2: String) → BalancePairKey

  IF userId1 < userId2:        // lexicographic comparison
    RETURN BalancePairKey(
      userA: userId1,
      userB: userId2,
      id: "${userId1}_${userId2}"
    )
  ELSE:
    RETURN BalancePairKey(
      userA: userId2,
      userB: userId1,
      id: "${userId2}_${userId1}"
    )

PROPERTIES:
  canonicalPair("abc", "xyz") == canonicalPair("xyz", "abc")  // symmetric
  canonicalPair(x, y).id is unique for each unordered pair    // deterministic
  canonicalPair(x, y).userA < canonicalPair(x, y).userB      // ordered

USAGE:
  Firestore document ID: balances/{canonicalPair.id}
  sqflite UNIQUE constraint: (group_id, user_a_id, user_b_id)

INTERPRETATION OF AMOUNT:
  For balancePair(A, B) with A < B:
    amount > 0  →  A owes B
    amount < 0  →  B owes A
    amount == 0 →  settled
```

---

## 16. Remainder Distribution (Largest Remainder Method)

### Purpose
Distribute an integer total among N parties according to fractional weights, ensuring the sum is exactly preserved. Used by percentage split, shares split, and proportional tax/tip distribution.

### Formal Specification

```
FUNCTION largestRemainderDistribution(
  totalPaise: int,
  rawAmounts: Map<userId, double>  // fractional amounts
) → Map<userId, int>

ALGORITHM:
  // Step 1: Floor each amount
  floored ← {}
  fractionalParts ← []

  FOR (userId, raw) IN rawAmounts:
    floorVal ← raw.floor()
    floored[userId] ← floorVal
    fractionalParts.add((userId, raw - floorVal))

  // Step 2: Calculate remainder
  floorSum ← sum(floored.values)
  remainder ← totalPaise - floorSum  // always 0 ≤ remainder < n

  // Step 3: Sort by fractional part descending
  fractionalParts.sortByDescending(value)

  // Step 4: Give 1 extra paisa to top `remainder` entries
  FOR i FROM 0 TO remainder - 1:
    floored[fractionalParts[i].key] ← floored[fractionalParts[i].key] + 1

  RETURN floored

POST-CONDITIONS:
  sum(result.values) == totalPaise  // always exact
  ∀ userId: abs(result[userId] - rawAmounts[userId]) < 1  // max 1 paisa deviation

PROPERTIES:
  • Deterministic for same inputs
  • Minimizes maximum individual rounding error
  • Used in: percentageSplit, sharesSplit, proportionalDistribute
```

### Why This Method?
The Largest Remainder Method (also called Hamilton's method) is the standard algorithm for apportionment problems. It guarantees:
1. **Exact total** — no missing or extra paise
2. **Fairness** — each person's amount differs from their "true" share by at most 1 paisa
3. **No bias** — the person with the largest fractional part gets the extra paisa (mathematically fairest)

---

## 17. Group Balance Aggregation (My Balance)

### Purpose
Compute a single "my balance" number for the current user across a group (or across all groups), for display on home dashboard and group cards.

### Formal Specification

```
FUNCTION calculateMyBalance(
  userId: String,
  groupBalances: Map<BalancePairKey, int>
) → int  // positive = I am owed, negative = I owe

ALGORITHM:
  myBalance ← 0

  FOR ((userA, userB), amount) IN groupBalances:
    IF userA == userId:
      // I am userA
      // amount > 0 means I owe userB → my balance decreases
      myBalance ← myBalance - amount
    ELSE IF userB == userId:
      // I am userB
      // amount > 0 means userA owes me → my balance increases
      myBalance ← myBalance + amount

  RETURN myBalance

DISPLAY:
  myBalance > 0 → "You are owed ₹{myBalance/100}" (green)
  myBalance < 0 → "You owe ₹{abs(myBalance)/100}" (red)
  myBalance == 0 → "Settled up ✓" (neutral)

OVERALL BALANCE (across all groups):
  overallBalance ← sum(
    FOR group IN userGroups:
      group.myBalance
  )
```

---

## 18. Notification Fan-Out

### Purpose
When an event occurs (expense added, settlement recorded), send push notifications to all relevant group members except the actor, respecting notification preferences.

### Formal Specification

```
FUNCTION fanOutNotification(
  event: {
    type: String,          // 'expense_added' | 'settlement' | 'nudge' | ...
    actorId: String,       // user who triggered the event
    groupId: String,
    payload: NotificationPayload
  }
)

ALGORITHM:
  // Step 1: Get all active group members (excluding actor)
  members ← SELECT * FROM groups/{event.groupId}/members
    WHERE isActive = true
      AND userId != event.actorId

  // Step 2: Filter by notification preferences
  recipients ← []
  FOR member IN members:
    user ← GET users/{member.userId}
    prefs ← user.notificationPrefs

    // Check type-level preference
    IF event.type == 'expense_added' AND prefs.expenses != true: CONTINUE
    IF event.type == 'settlement' AND prefs.settlements != true: CONTINUE
    IF event.type == 'nudge' AND prefs.reminders != true: CONTINUE

    // Check group-level muting (future feature)
    // IF user.mutedGroups.contains(event.groupId): CONTINUE

    recipients.add(user)

  // Step 3: Collect FCM tokens
  tokens ← []
  FOR user IN recipients:
    tokens.addAll(user.fcmTokens)

  IF tokens.isEmpty: RETURN

  // Step 4: Build notification
  notification ← {
    title: formatTitle(event),
    body: formatBody(event),
    data: {
      type: event.type,
      groupId: event.groupId,
      entityId: event.payload.entityId,
      route: buildDeepLink(event)
    }
  }

  // Step 5: Send via FCM (multicast, max 500 tokens per call)
  FOR tokenBatch IN tokens.chunked(500):
    response ← admin.messaging().sendEachForMulticast({
      tokens: tokenBatch,
      notification: notification.title + body,
      data: notification.data
    })

    // Step 6: Clean up stale tokens
    FOR (i, sendResult) IN response.responses.enumerate():
      IF sendResult.error?.code IN ['messaging/registration-token-not-registered',
                                     'messaging/invalid-registration-token']:
        DELETE tokenBatch[i] FROM user's fcmTokens array

  // Step 7: Write to in-app notification center
  FOR user IN recipients:
    SET users/{user.id}/notifications/{generateUUID()} = {
      id: generateUUID(),
      type: event.type,
      title: notification.title,
      body: notification.body,
      groupId: event.groupId,
      entityId: event.payload.entityId,
      isRead: false,
      createdAt: now()
    }

COMPLEXITY:
  Time: O(M) where M = group members
  FCM calls: ceil(tokens / 500)
  Firestore writes: M (one notification doc per recipient)
```

---

## Algorithm Complexity Summary

| Algorithm | Time Complexity | Space Complexity | Critical Path? |
|-----------|----------------|-----------------|----------------|
| Equal Split | O(n) | O(n) | Yes — every expense |
| Exact Split | O(n) validation | O(1) | Yes |
| Percentage Split | O(n log n) | O(n) | Yes |
| Shares Split | O(n log n) | O(n) | Yes |
| Itemized Split | O(I×P + N log N) | O(N) | Yes |
| Balance Calculation | O(E × N) | O(N²) | Yes — every balance view |
| Debt Simplification | O(N log N) | O(N) | Settle-up only |
| Largest Remainder | O(n log n) | O(n) | Sub-algorithm |
| Sync Queue Processing | O(Q) | O(Q) | Background |
| Conflict Resolution | O(F) fields | O(1) | On conflict only |
| Recurring Processing | O(R) | O(R) | Scheduled daily |
| Guest Migration | O(G × E) | O(1) | One-time per guest |
| Invite Validation | O(1) | O(1) | On join |
| Search Ranking | O(R log R) | O(R) | On search |
| Notification Fan-Out | O(M) | O(M) | Every event |
| Canonical Pair | O(1) | O(1) | Every balance op |
| My Balance Aggregation | O(B) | O(1) | Every balance view |

Where: n=participants, N=group members, E=expenses, Q=queue size, R=results, M=members, I=items, P=people per item, F=fields, G=groups, B=balance pairs

---

## Testing Requirements for Algorithms

Each algorithm must have comprehensive unit tests covering:

| Algorithm | Required Test Cases |
|-----------|-------------------|
| Equal Split | n=1, n=2, n=3 (with remainder), totalPaise < n, totalPaise = 0, large n (100) |
| Percentage Split | 50/50, 33.33/33.33/33.34, one person 100%, many small percentages, sum ≠ 100 (error) |
| Shares Split | Equal shares (2:2:2), unequal (3:1), single share, fractional shares (1.5:2.5) |
| Itemized Split | Single item, multiple items, shared items, tax only, tip only, tax+tip, single person per item |
| Balance Calculation | No expenses, single expense, multiple expenses, with settlements, self-payment, multiple payers |
| Debt Simplification | 2 people, 3 people chain, circular debts, all owe one person, already settled, single debtor multiple creditors |
| Largest Remainder | No remainder, remainder = 1, remainder = n-1, all equal weights, one zero weight |
| Conflict Resolution | Delete vs edit, both edit non-critical, both edit amount, version mismatch, identical edits |
| Recurring Schedule | Daily/weekly/monthly/yearly, month-end (31st), Feb 29 leap year, past due dates, end date reached |
