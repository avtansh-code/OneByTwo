# Simplified Debts Algorithm — Design Specification

| Field            | Value                                              |
|------------------|----------------------------------------------------|
| Document Version | 1.0                                                |
| Status           | Draft                                              |
| Author           | Cloud Functions Developer Agent                    |
| SRS Baseline     | v1.1                                               |
| Source File      | `functions/src/simplifiedDebts.ts`                 |

---

## 1. Reference Algorithm

The canonical algorithm is defined in SRS section 7.4. It is implemented as a
**pure function** in `functions/src/simplifiedDebts.ts` and invoked within a
Firestore transaction by the `recomputeSimplifiedBalances` Cloud Function
(SRS section 7.3, FR-SE-03, FR-SE-04).

### Steps

1. **Compute net balances.** For each member in the context (group or friendship),
   compute:

   ```
   netPaise = sum(amounts paid by self for others)
            − sum(amounts paid by others for self)
            − sum(settlement amounts paid out)
            + sum(settlement amounts received in)
   ```

   All values are **integer paise** (Invariant 1; SRS section 7.3). The result is
   a `Map<userId, netPaise>`.

2. **Partition into creditors and debtors.** Members with `netPaise > 0` are
   creditors (they are owed money). Members with `netPaise < 0` are debtors (they
   owe money). Members with `netPaise === 0` are excluded from further processing.

3. **Greedy pairing.** Sort creditors in descending order of `netPaise` and debtors
   in descending order of `|netPaise|` (i.e., most negative first). Repeatedly:
   - Select the largest creditor and the largest debtor.
   - Compute the transfer amount: `transferPaise = Math.min(|debtorNet|, creditorNet)`.
   - Emit a transfer record `{ from: debtorId, to: creditorId, amountPaise: transferPaise }`.
   - Subtract `transferPaise` from the creditor's net; add `transferPaise` to the
     debtor's net (moving it towards zero).
   - Remove any participant whose net reaches zero.
   - Continue until both lists are empty.

4. **Emit result and project.** The output is a flat array of
   `Transfer { from: string; to: string; amountPaise: number }`. This array is
   then projected into the nested `simplifiedBalances` map on the relevant
   `friendship` or `group` document (SRS section 7.3, FR-SE-03).

5. **Determinism.** When multiple creditors or multiple debtors share the same
   absolute `netPaise`, ties are broken by **ascending `userId`**
   (lexicographic string comparison). This guarantees that all clients observing the
   same expense and settlement log will derive identical simplified balances
   (SRS section 7.4; FR-SE-02).

---

## 2. Worked Examples

All monetary values below are in **paise**. Member identifiers are short strings for
readability; in production they are Firebase Auth UIDs.

### Example 1: Empty — no expenses

**Scenario:** A group with members `[A, B, C]` has zero expenses and zero
settlements.

| Member | netPaise |
|--------|----------|
| A      | 0        |
| B      | 0        |
| C      | 0        |

**Step 2 — Partition:**

- Creditors: (none)
- Debtors: (none)

**Step 3 — Pairing:** No iterations required.

**Output:**

```
transfers = []
```

**simplifiedBalances projection:**

```json
{}
```

---

### Example 2: Single member — self-paid expense

**Scenario:** A group contains only member `A`. `A` pays 50000 paise (500 INR) for
an expense where `A` is the sole participant.

| Member | Paid  | Owes  | netPaise |
|--------|-------|-------|----------|
| A      | 50000 | 50000 | 0        |

**Step 2 — Partition:**

- Creditors: (none)
- Debtors: (none)

**Step 3 — Pairing:** No iterations required.

**Output:**

```
transfers = []
```

**simplifiedBalances projection:**

```json
{}
```

---

### Example 3: Perfectly balanced — all nets zero

**Scenario:** Three members `A`, `B`, `C`. Each pays one expense of 30000 paise
(300 INR), split equally among all three.

Per expense, each member's share is `30000 / 3 = 10000` paise.

| Member | Total paid | Total share owed | netPaise |
|--------|------------|------------------|----------|
| A      | 30000      | 30000            | 0        |
| B      | 30000      | 30000            | 0        |
| C      | 30000      | 30000            | 0        |

**Step 2 — Partition:**

- Creditors: (none)
- Debtors: (none)

**Step 3 — Pairing:** No iterations required.

**Output:**

```
transfers = []
```

**simplifiedBalances projection:**

```json
{}
```

---

### Example 4: Cyclic to zero

**Scenario:** Three members `A`, `B`, `C`. Three separate expenses, each 10000
paise:

- Expense 1: `A` pays 10000, split is 100% on `B` (i.e., `B` owes `A` 10000).
- Expense 2: `B` pays 10000, split is 100% on `C` (i.e., `C` owes `B` 10000).
- Expense 3: `C` pays 10000, split is 100% on `A` (i.e., `A` owes `C` 10000).

| Member | Total paid | Total share owed | netPaise             |
|--------|------------|------------------|----------------------|
| A      | 10000      | 10000            | 10000 − 10000 = 0    |
| B      | 10000      | 10000            | 10000 − 10000 = 0    |
| C      | 10000      | 10000            | 10000 − 10000 = 0    |

**Step 2 — Partition:**

- Creditors: (none)
- Debtors: (none)

**Step 3 — Pairing:** No iterations required. The cycle cancels entirely.

**Output:**

```
transfers = []
```

**simplifiedBalances projection:**

```json
{}
```

---

### Example 5: Three-person trip

**Scenario:** Members `A`, `B`, `C`. A single expense: `A` pays 60000 paise
(600 INR), split equally among all three.

Each member's share: `60000 / 3 = 20000` paise.

| Member | Paid  | Share | netPaise            |
|--------|-------|-------|---------------------|
| A      | 60000 | 20000 | 60000 − 20000 = +40000 |
| B      | 0     | 20000 | 0 − 20000 = −20000     |
| C      | 0     | 20000 | 0 − 20000 = −20000     |

**Step 2 — Partition:**

- Creditors: `[A: +40000]`
- Debtors: `[B: −20000, C: −20000]` (tied; broken by ascending userId: `B` before `C`)

**Step 3 — Pairing:**

| Iteration | Largest creditor | Largest debtor | Transfer                  | Creditor after | Debtor after |
|-----------|------------------|----------------|---------------------------|----------------|--------------|
| 1         | A (+40000)       | B (−20000)     | `{ from: B, to: A, amountPaise: 20000 }` | A: +20000 | B: 0 (removed) |
| 2         | A (+20000)       | C (−20000)     | `{ from: C, to: A, amountPaise: 20000 }` | A: 0 (removed) | C: 0 (removed) |

Both lists empty. Algorithm terminates.

**Output:**

```
transfers = [
  { from: "B", to: "A", amountPaise: 20000 },
  { from: "C", to: "A", amountPaise: 20000 }
]
```

**simplifiedBalances projection:**

```json
{
  "A": { "B": 20000, "C": 20000 },
  "B": { "A": -20000 },
  "C": { "A": -20000 }
}
```

Interpretation: `A` is owed 20000 by `B` and 20000 by `C`. `B` owes 20000 to `A`.
`C` owes 20000 to `A`.

---

### Example 6: Five-person flat-share

**Scenario:** A shared flat with members `A`, `B`, `C`, `D`, `E`. Three expenses
over the month:

| Expense | Payer | Amount (paise) | Split among    | Per-head share (paise) |
|---------|-------|----------------|----------------|------------------------|
| Rent    | A     | 5000000        | A, B, C, D, E  | 1000000                |
| Groceries | B  | 300000         | A, B, C, D, E  | 60000                  |
| Electricity | C | 200000        | A, B, C, D, E  | 40000                  |

**Step 1 — Compute netPaise:**

| Member | Total paid | Total share owed                          | netPaise    |
|--------|------------|-------------------------------------------|-------------|
| A      | 5000000    | 1000000 + 60000 + 40000 = 1100000         | +3900000    |
| B      | 300000     | 1000000 + 60000 + 40000 = 1100000         | −800000     |
| C      | 200000     | 1000000 + 60000 + 40000 = 1100000         | −900000     |
| D      | 0          | 1000000 + 60000 + 40000 = 1100000         | −1100000    |
| E      | 0          | 1000000 + 60000 + 40000 = 1100000         | −1100000    |

Verification: sum of all nets = 3900000 − 800000 − 900000 − 1100000 − 1100000 = 0.
Correct.

**Step 2 — Partition:**

- Creditors (descending netPaise): `[A: +3900000]`
- Debtors (descending |netPaise|): `[D: −1100000, E: −1100000, C: −900000, B: −800000]`
  - `D` and `E` are tied at |1100000|; tie broken by ascending userId: `D` before `E`.

**Step 3 — Pairing:**

| Iter | Largest creditor | Largest debtor   | Transfer amount | Transfer record                           | Creditor after | Debtor after      |
|------|------------------|------------------|-----------------|-------------------------------------------|----------------|-------------------|
| 1    | A (+3900000)     | D (−1100000)     | 1100000         | `{ from: D, to: A, amountPaise: 1100000 }` | A: +2800000    | D: 0 (removed)    |
| 2    | A (+2800000)     | E (−1100000)     | 1100000         | `{ from: E, to: A, amountPaise: 1100000 }` | A: +1700000    | E: 0 (removed)    |
| 3    | A (+1700000)     | C (−900000)      | 900000          | `{ from: C, to: A, amountPaise: 900000 }`  | A: +800000     | C: 0 (removed)    |
| 4    | A (+800000)      | B (−800000)      | 800000          | `{ from: B, to: A, amountPaise: 800000 }`  | A: 0 (removed) | B: 0 (removed)    |

Both lists empty. Algorithm terminates. Total transfers: 4 (the minimum for this
configuration).

**Output:**

```
transfers = [
  { from: "D", to: "A", amountPaise: 1100000 },
  { from: "E", to: "A", amountPaise: 1100000 },
  { from: "C", to: "A", amountPaise: 900000 },
  { from: "B", to: "A", amountPaise: 800000 }
]
```

**simplifiedBalances projection:**

```json
{
  "A": { "B": 800000, "C": 900000, "D": 1100000, "E": 1100000 },
  "B": { "A": -800000 },
  "C": { "A": -900000 },
  "D": { "A": -1100000 },
  "E": { "A": -1100000 }
}
```

---

## 3. Determinism Rule

### Specification

When two or more creditors share the same `netPaise`, or two or more debtors share
the same absolute `netPaise`, ties are broken by **ascending `userId`**
(lexicographic string comparison). The member with the lower `userId` is selected
first in the pairing step (SRS section 7.4).

This rule ensures that every execution of the algorithm against the same input
produces an identical output, regardless of the order in which members are stored
in memory or returned by Firestore queries (FR-SE-02).

### Concrete example

Consider three members with the following nets:

| Member   | userId (Firebase UID) | netPaise |
|----------|-----------------------|----------|
| Priya    | `uid_abc`             | −15000   |
| Rahul    | `uid_def`             | −15000   |
| Sneha    | `uid_ghi`             | +30000   |

Both `uid_abc` (Priya) and `uid_def` (Rahul) are debtors with identical absolute
net of 15000 paise. The creditor is `uid_ghi` (Sneha) at +30000.

**Without the tie-breaking rule**, the algorithm could pair either debtor first,
yielding two valid but different orderings of transfers. Different clients could
display different settlement suggestions, causing confusion.

**With the tie-breaking rule**, `uid_abc` sorts before `uid_def` lexicographically
and is therefore paired first:

| Iteration | Creditor          | Debtor            | Transfer                                        |
|-----------|-------------------|-------------------|-------------------------------------------------|
| 1         | uid_ghi (+30000)  | uid_abc (−15000)  | `{ from: "uid_abc", to: "uid_ghi", amountPaise: 15000 }` |
| 2         | uid_ghi (+15000)  | uid_def (−15000)  | `{ from: "uid_def", to: "uid_ghi", amountPaise: 15000 }` |

The output is always:

```
transfers = [
  { from: "uid_abc", to: "uid_ghi", amountPaise: 15000 },
  { from: "uid_def", to: "uid_ghi", amountPaise: 15000 }
]
```

Every client, every execution, every retry produces this exact result.

---

## 4. Performance Budget

| Metric                  | Target               | Source                |
|-------------------------|----------------------|-----------------------|
| P95 latency             | less than or equal to 500 ms | SRS section 5.2       |
| Maximum group size (v1.0) | 50 members          | SRS section 5.2       |
| Algorithm complexity    | O(n log n)           | Dominated by the initial sort; the pairing loop is O(n) |

### Rationale

- **Sorting** the creditor and debtor lists is O(n log n) where `n` is the number of
  members with non-zero net balances.
- **Greedy pairing** performs at most `n − 1` iterations (each iteration zeroes out at
  least one participant), making the loop O(n).
- **Net balance computation** is O(e) where `e` is the number of expenses plus
  settlements. For v1.0 groups (up to 50 members), `e` is bounded by practical usage
  patterns and is not a concern for the 500 ms budget.
- Groups with more than 50 members are **out of scope for v1.0** (SRS section 5.2).
  If future versions raise this limit, the algorithm itself remains efficient; the
  bottleneck would shift to Firestore reads within the transaction.

### Region pinning

The `recomputeSimplifiedBalances` Cloud Function is deployed to **`asia-south1`**
(Mumbai) to minimise latency for Indian users (SRS section 5.2). This is configured
in the function's region annotation and must not be overridden.

---

## 5. Invariant Compliance

This section maps the algorithm and its Cloud Function wrapper to the project's
non-negotiable invariants (`.github/shared/invariants.md`).

### Invariant 1 — Money is integer paise

All `amountPaise` values in `Transfer` records, `netPaise` intermediate computations,
and the `simplifiedBalances` map are **integers**. The algorithm uses only integer
addition, subtraction, and `Math.min` — no division, no floating-point arithmetic.
Conversion to rupees for display is the sole responsibility of the Flutter UI layer
(SRS section 7.3).

The implementation must enforce this at the type level (`number` in TypeScript, but
validated with `Number.isInteger()` assertions in debug/test builds) and at the
Firestore schema level (integer fields).

### Invariant 2 — simplifiedBalances is server-maintained

The `simplifiedBalances` field on `friendships` and `groups` documents is written
**exclusively** by the `recomputeSimplifiedBalances` Cloud Function. Client SDKs
read the field but never write to it. This is enforced by Firestore Security Rules
(SRS sections 7.3, 7.5). The Cloud Function runs inside a Firestore transaction to
guarantee atomicity with the triggering expense or settlement write (FR-SE-04).

### Invariant 3 — System share sheet only

Not applicable to this algorithm. Included for completeness: the simplified balances
data may be surfaced in a share action, but sharing itself uses the platform system
share sheet (SRS sections 3.4, 4.11).

### Invariant 4 — Single Firebase project

The Cloud Function is deployed to the single production Firebase project. All
pre-merge testing runs against the Firebase Emulator Suite (SRS section 9.1). No
staging project exists.

---

## Appendix A: Transfer Type Definition

```typescript
/**
 * A single directed debt transfer emitted by the simplified-debts algorithm.
 * All amounts are in integer paise (1 INR = 100 paise).
 */
interface Transfer {
  /** The userId of the member who owes money (debtor). */
  from: string;
  /** The userId of the member who is owed money (creditor). */
  to: string;
  /** The amount to be transferred, in integer paise. Always > 0. */
  amountPaise: number;
}
```

## Appendix B: simplifiedBalances Map Structure

The `simplifiedBalances` field is a nested map stored on the `friendship` or `group`
Firestore document. Its shape is:

```
simplifiedBalances: {
  [userId: string]: {
    [otherUserId: string]: number  // positive = owed to you; negative = you owe
  }
}
```

Each entry is mirrored: if `simplifiedBalances.A.B = 20000`, then
`simplifiedBalances.B.A = -20000`. The Cloud Function writes both sides atomically.

## Appendix C: SRS Cross-References

| SRS Section | Topic                                | Relevance                              |
|-------------|--------------------------------------|----------------------------------------|
| 4.6         | Settlements and Simplified Debts     | Functional requirements FR-SE-01 to FR-SE-09 |
| 5.2         | Scalability                          | Region pinning, 500 ms P95, 50-member cap   |
| 7.3         | Key Architectural Decisions          | Paise integers, server-maintained projection |
| 7.4         | Simplified Debts Algorithm           | Reference algorithm (this document restates) |
| 7.5         | Security Rules Principles            | Client-read-only enforcement                 |
