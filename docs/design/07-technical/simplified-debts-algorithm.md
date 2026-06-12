# Simplified Debts Algorithm — Design Specification

| Field            | Value                                              |
|------------------|----------------------------------------------------|
| Document Version | 1.1                                                |
| Status           | Current (reconciled with deployed code)            |
| Author           | Cloud Functions Developer Agent                    |
| SRS Baseline     | v1.1                                               |
| Source Files     | `functions/src/simplified-debts/algorithm.ts` (pure algorithm), `functions/src/simplified-debts/function.ts` (`recomputeAndWrite` boundary) |

---

## 1. Reference Algorithm

The canonical algorithm is defined in SRS section 7.4. It is implemented as two
**pure functions** — `simplifyDebts` and `projectToBalancesMap` — in
`functions/src/simplified-debts/algorithm.ts`. They are invoked within a
Firestore transaction by the shared `recomputeAndWrite` core in
`functions/src/simplified-debts/function.ts`, which in turn is shared by the
`recomputeSimplifiedBalances` callable and the `onExpenseWriteFriendship` /
`onSettlementWrite` triggers (SRS section 7.3, FR-SE-03 through FR-SE-06; see
section 2 below).

### Steps

1. **Compute net balances.** `computeNetBalances` (exported from
   `function.ts`) folds the context's expenses and settlements into a
   `Map<userId, netPaise>`:

   - **Expense:** the payer is credited `+amountPaise`; each split member is
     debited `−sharePaise`.
   - **Settlement** `{ fromUserId, toUserId, amountPaise }` (cash paid by
     `fromUserId` to `toUserId`): the payer `fromUserId` is credited
     `+amountPaise` (their debt is reduced) and `toUserId` is debited
     `−amountPaise` (they are now owed less).

   Equivalently, for each member:

   ```
   netPaise = sum(expense amounts paid by self for others)
            − sum(expense shares paid by others for self)
            + sum(settlement amounts self paid out as fromUserId)
            − sum(settlement amounts self received as toUserId)
   ```

   All values are **integer paise** (Invariant 1; SRS section 7.3). Because every
   expense and every settlement is internally balanced, the resulting map always
   satisfies the zero-sum invariant by construction. The result is a
   `Map<userId, netPaise>`.

2. **Partition into creditors and debtors.** Members with `netPaise > 0` are
   creditors (they are owed money). Members with `netPaise < 0` are debtors (they
   owe money). Members with `netPaise === 0` are excluded from further processing.

3. **Greedy pairing.** Sort creditors in descending order of `netPaise` and debtors
   in descending order of `|netPaise|` (i.e., most negative first); ties on the
   absolute amount are broken by **ascending `userId`** in both lists (step 5).
   Then walk both sorted lists with a pointer into each, repeatedly:
   - Select the current largest creditor and the current largest debtor.
   - Compute the transfer amount: `transferPaise = Math.min(creditorNet, |debtorNet|)`.
   - Emit a transfer record `{ from: debtorId, to: creditorId, amountPaise: transferPaise }`.
   - Subtract `transferPaise` from the creditor's net; add `transferPaise` to the
     debtor's net (moving it towards zero).
   - Advance the pointer past any participant whose net reaches zero.
   - Continue until either list is exhausted. Because the inputs are zero-sum, both
     lists are consumed together.

4. **Emit result and project.** The output of `simplifyDebts` is a flat array of
   `Transfer { from: string; to: string; amountPaise: number }`. `projectToBalancesMap`
   then projects this array into the nested `simplifiedBalances` map on the relevant
   `friendship` or `group` document (SRS section 7.3, FR-SE-03). The projection is
   **debtor-keyed and positive-only**: only debtors appear as outer keys, the inner
   key is the creditor, and every value is the positive `amountPaise` of that
   transfer. There are **no** creditor outer keys and **no** negative or mirrored
   entries (see Appendix B and the worked examples below).

5. **Determinism.** When multiple creditors or multiple debtors share the same
   absolute `netPaise`, ties are broken by **ascending `userId`**
   (lexicographic string comparison). This guarantees that all clients observing the
   same expense and settlement log will derive identical simplified balances
   (SRS section 7.4; FR-SE-02).

---

## 2. Function Boundary — `recomputeAndWrite` and the Cloud Function Wrappers

The pure `simplifyDebts` / `projectToBalancesMap` functions are wrapped by a
shared core, `recomputeAndWrite`, in `functions/src/simplified-debts/function.ts`.
This core is the **sole writer of `simplifiedBalances`** (Invariant 2) and is
shared by three deployed entry points:

- the `recomputeSimplifiedBalances` HTTPS Callable (`functions/src/simplified-debts/index.ts`);
- the `onExpenseWriteFriendship` Firestore trigger (`functions/src/triggers/on-expense-write/`);
- the `onSettlementWrite` Firestore trigger (`functions/src/triggers/on-settlement-write/`).

### 2.1 Transaction sequence

`recomputeAndWrite(deps, { contextType, contextId, alsoSet? })` runs entirely
inside a single `db.runTransaction(...)`:

1. Read the context document (`friendships/{id}` or `groups/{id}`). If it does
   not exist, return `{ ok: false, code: 'CONTEXT_NOT_FOUND' }` without writing.
2. Read the active expenses from the context subcollection with the server-side
   filter `where('deleted', '!=', true)`.
3. Read the settlements for the context from the **top-level** `settlements`
   collection with two equality filters, `where('contextType', '==', ...)` and
   `where('contextId', '==', ...)`. Soft-deleted settlements (`deleted === true`)
   are filtered **in code** inside `computeNetBalances` to avoid an unnecessary
   composite index.
4. Fold expenses and settlements into `Map<userId, netPaise>` via
   `computeNetBalances`, then run `simplifyDebts` and `projectToBalancesMap`.
5. Write `simplifiedBalances` (plus any caller-supplied `alsoSet` fields) back to
   the context document in the same `tx.update(...)`.

### 2.2 Typed result, not `HttpsError`

`recomputeAndWrite` never throws `HttpsError`. It returns a discriminated union:

```typescript
type RecomputeResult =
  | { ok: true; transfers: Transfer[]; simplifiedBalances: SimplifiedBalancesMap }
  | { ok: false; code: 'CONTEXT_NOT_FOUND' | 'BALANCE_INVARIANT_VIOLATED' };
```

A zero-sum violation surfaces because `simplifyDebts` throws a plain `Error`
whose message contains `Balance invariant violation`; the core catches that
specific error and converts it to `{ ok: false, code: 'BALANCE_INVARIANT_VIOLATED' }`.
Any other (unknown) error bubbles up unchanged so each caller can apply its own
policy:

- the **callable** wrapper (`createHandler`) maps `CONTEXT_NOT_FOUND` →
  `HttpsError('not-found', …, { errorCode: 'CONTEXT_NOT_FOUND' })`,
  `BALANCE_INVARIANT_VIOLATED` →
  `HttpsError('internal', …, { errorCode: 'BALANCE_INVARIANT_VIOLATED' })`, and
  any uncaught error → `HttpsError('internal', …, { errorCode: 'INTERNAL' })`.
  On success it returns `{ ok: true, transfers, simplifiedBalances, computedAt }`
  where `computedAt` is an ISO 8601 string.
- the **triggers** return successfully on `CONTEXT_NOT_FOUND` (the context is
  gone — retries cannot help) and **throw** a plain `Error` on
  `BALANCE_INVARIANT_VIOLATED` and on unknown errors so Cloud Functions retries.

See `docs/design/07-technical/cloud-functions-error-codes.md` for the full code
catalogue.

### 2.3 `alsoSet`, reserved keys, and the `lastActivityAt` monotonicity guard

Callers may pass an `alsoSet` map to atomically write extra fields alongside
`simplifiedBalances`. Both triggers use this to advance `lastActivityAt` on the
parent context document so the friends-list ordering moves on every event. The
core enforces two safety rules:

- **Reserved keys.** `alsoSet` must not contain `simplifiedBalances`; the core
  throws if it does, and additionally places its own computed `simplifiedBalances`
  last in the write spread so a malformed `alsoSet` cannot overwrite it
  (Invariant 2, defence-in-depth).
- **Monotonicity guard.** When `alsoSet.lastActivityAt` is present it must be a
  Firestore `Timestamp`; the value actually written is
  `max(existing.lastActivityAt, alsoSet.lastActivityAt)`, so out-of-order Cloud
  Functions delivery can never regress the ordering.

### 2.4 Property tests

`functions/test/simplified-debts/algorithm.property.test.ts` (fast-check) asserts
the load-bearing properties on random valid inputs:

- transfer count ≤ N−1 for N non-zero-balance members;
- applying every emitted transfer settles all members to exactly zero;
- the algorithm is deterministic (identical input → identical output);
- every `amountPaise` is a positive integer;
- `computeNetBalances` preserves the zero-sum invariant under any mixed sequence of
  expenses and settlements, and soft-deleted settlements are excluded from the fold.

---

## 3. Worked Examples

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
  "B": { "A": 20000 },
  "C": { "A": 20000 }
}
```

Interpretation: `B` owes 20000 to `A`, and `C` owes 20000 to `A`. The map is
debtor-keyed and positive-only — creditor `A` does **not** appear as an outer key,
and there are no negative or mirrored entries.

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
  "B": { "A": 800000 },
  "C": { "A": 900000 },
  "D": { "A": 1100000 },
  "E": { "A": 1100000 }
}
```

Interpretation: each of `B`, `C`, `D`, `E` owes `A` the stated positive amount.
This is the exact shape asserted by the integration test
`functions/test/integration/simplified-debts.integration.test.ts` and the unit
test `functions/test/simplified-debts/algorithm.test.ts`.

---

## 4. Determinism Rule

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

## 5. Performance Budget

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

The `recomputeSimplifiedBalances` callable and the `onExpenseWriteFriendship` and
`onSettlementWrite` triggers — every entry point that runs `recomputeAndWrite` —
are deployed to **`asia-south1`** (Mumbai) to minimise latency for Indian users
(SRS section 5.2). Each module sets `{ region: "asia-south1" }` in its trigger
options; this must not be overridden.

---

## 6. Invariant Compliance

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
**exclusively** by `recomputeAndWrite` in
`functions/src/simplified-debts/function.ts` — the shared core invoked by the
`recomputeSimplifiedBalances` callable, the `onExpenseWriteFriendship` trigger, and
the `onSettlementWrite` trigger. Client SDKs read the field but never write to it.
This is enforced by Firestore Security Rules (SRS sections 7.3, 7.5). The write
happens inside the same Firestore transaction that reads the expenses and
settlements, guaranteeing atomicity with the triggering write (FR-SE-04, FR-SE-06).

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
Firestore document, produced by `projectToBalancesMap`. Its shape is:

```typescript
interface SimplifiedBalancesMap {
  [debtorUserId: string]: {
    [creditorUserId: string]: number  // integer paise, always > 0
  }
}
```

The map is **debtor-keyed and positive-only**: the outer key is the debtor, the
inner key is the creditor, and the value is the positive `amountPaise` the debtor
owes the creditor. Creditors do **not** appear as outer keys, and there are **no**
negative or mirrored entries. For example, when `B` owes `A` 20000 paise the map
contains `{ "B": { "A": 20000 } }` — there is no `"A"` entry and no `-20000`.

To answer "does `X` owe `Y`?", a reader checks `simplifiedBalances[X][Y]` and treats
it as the positive paise amount `X` owes `Y` (and a missing entry as zero). This is
exactly how the FR-SE-09 reminder callable reads the field: it requires
`simplifiedBalances[recipientUid][senderUid]` to be a positive integer.

## Appendix C: SRS Cross-References

| SRS Section | Topic                                | Relevance                              |
|-------------|--------------------------------------|----------------------------------------|
| 4.6         | Settlements and Simplified Debts     | Functional requirements FR-SE-01 to FR-SE-09 |
| 5.2         | Scalability                          | Region pinning, 500 ms P95, 50-member cap   |
| 7.3         | Key Architectural Decisions          | Paise integers, server-maintained projection |
| 7.4         | Simplified Debts Algorithm           | Reference algorithm (this document restates) |
| 7.5         | Security Rules Principles            | Client-read-only enforcement                 |
