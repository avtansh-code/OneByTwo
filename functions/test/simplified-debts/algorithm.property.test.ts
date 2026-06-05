import fc from "fast-check";
import { simplifyDebts } from "../../src/simplified-debts/algorithm";
import { computeNetBalances } from "../../src/simplified-debts/function";

/**
 * Property-based tests for the simplified-debts algorithm.
 *
 * Uses fast-check to generate random valid inputs and verify structural
 * properties that must hold for any input.
 *
 * PR #37 (FR-SE-05/06) extends the test surface to cover
 * `computeNetBalances` over MIXED expense + settlement sequences. The
 * load-bearing property: for any random mix of expenses (which credit
 * the payer and debit the split members) AND settlements (which credit
 * the fromUserId and debit the toUserId), the resulting net-balance
 * map preserves the zero-sum invariant — the canonical pre-condition
 * for `simplifyDebts` not throwing `BALANCE_INVARIANT_VIOLATED`.
 */

/**
 * Arbitrary that generates a valid netBalances Map where the sum is exactly 0.
 * Strategy: generate N-1 random integer balances, compute the Nth as the
 * negative sum of the rest.
 */
const validNetBalancesArb: fc.Arbitrary<Map<string, number>> = fc
  .record({
    // Generate 1..8 unique userIds with integer balances
    entries: fc.array(
      fc.record({
        userId: fc.stringMatching(/^[a-z]{1,8}$/),
        amount: fc.integer({ min: -10_000_000, max: 10_000_000 }),
      }),
      { minLength: 1, maxLength: 8 },
    ),
  })
  .map(({ entries }) => {
    // Deduplicate by userId
    const seen = new Map<string, number>();
    for (const e of entries) {
      if (!seen.has(e.userId)) {
        seen.set(e.userId, e.amount);
      }
    }

    // Ensure sum = 0 by adjusting an extra member or the last member
    const userIds = Array.from(seen.keys());
    const amounts = Array.from(seen.values());

    let sum = 0;
    for (const a of amounts) {
      sum += a;
    }

    if (sum === 0) {
      return seen;
    }

    // Add a balancing member with a guaranteed-unique key
    const balancingId = `_bal_${userIds.length}`;
    seen.set(balancingId, -sum);

    return seen;
  });

describe("simplifyDebts property-based tests", () => {
  // Property 1: Transfer count <= N-1
  it("transfer count is at most N-1 where N is non-zero-balance members", () => {
    fc.assert(
      fc.property(validNetBalancesArb, (netBalances) => {
        const transfers = simplifyDebts(netBalances);

        const nonZeroCount = Array.from(netBalances.values()).filter(
          (v) => v !== 0,
        ).length;

        // N-1 bound, with minimum of 0
        const maxTransfers = Math.max(0, nonZeroCount - 1);
        expect(transfers.length).toBeLessThanOrEqual(maxTransfers);
      }),
      { numRuns: 200 },
    );
  });

  // Property 2: Applying transfers zeroes all balances
  it("applying all transfers settles every member to zero", () => {
    fc.assert(
      fc.property(validNetBalancesArb, (netBalances) => {
        const transfers = simplifyDebts(netBalances);

        // Start with original balances
        const settled = new Map<string, number>();
        for (const [uid, amount] of netBalances) {
          settled.set(uid, amount);
        }

        // Apply each transfer
        for (const t of transfers) {
          settled.set(t.from, (settled.get(t.from) ?? 0) + t.amountPaise);
          settled.set(t.to, (settled.get(t.to) ?? 0) - t.amountPaise);
        }

        // All should be zero
        for (const [uid, amount] of settled) {
          expect(amount).toBe(0);
        }
      }),
      { numRuns: 200 },
    );
  });

  // Property 3: Deterministic — same input produces identical output
  it("is deterministic: same input always produces same output", () => {
    fc.assert(
      fc.property(validNetBalancesArb, (netBalances) => {
        const result1 = simplifyDebts(netBalances);
        const result2 = simplifyDebts(netBalances);
        expect(result1).toEqual(result2);
      }),
      { numRuns: 200 },
    );
  });

  // Property 4: All amounts are positive integers
  it("every transfer amount is a positive integer (paise integrity)", () => {
    fc.assert(
      fc.property(validNetBalancesArb, (netBalances) => {
        const transfers = simplifyDebts(netBalances);
        for (const t of transfers) {
          expect(t.amountPaise).toBeGreaterThan(0);
          expect(Number.isInteger(t.amountPaise)).toBe(true);
        }
      }),
      { numRuns: 200 },
    );
  });
});

// ---------------------------------------------------------------------------
// PR #37 — Mixed expense + settlement property tests for computeNetBalances
// ---------------------------------------------------------------------------

/**
 * Builds a QueryDocumentSnapshot-shaped fake from a data record. Only the
 * `data()` method is consumed by `computeNetBalances`; the rest of the
 * Firestore snapshot surface is not exercised.
 */
function fakeSnap(
  data: Record<string, unknown>,
): FirebaseFirestore.QueryDocumentSnapshot {
  return {
    data: () => data,
  } as unknown as FirebaseFirestore.QueryDocumentSnapshot;
}

/**
 * Arbitrary that picks a member from a small fixed roster. Using a fixed
 * roster (rather than randomised UIDs) ensures expense splits and settlement
 * counterparties refer to the same identifier set so credits and debits net
 * meaningfully.
 */
const memberArb = fc.constantFrom("alice", "bob", "carol", "dave");

/**
 * Generates a valid two-member expense over the fixed roster:
 *   - `payerId` is a random member.
 *   - `amountPaise` is a positive integer in [1, 1_000_000].
 *   - `splits` always sums to `amountPaise` exactly (Invariant 1).
 *
 * Splits between two distinct roster members. The first share is in
 * [0, amountPaise]; the second is the residual. This mirrors the real
 * security-rules cap (friendship splits.size() <= 2).
 */
const expenseArb = fc
  .record({
    payer: memberArb,
    other: memberArb,
    amountPaise: fc.integer({ min: 1, max: 1_000_000 }),
    payerShareFraction: fc.integer({ min: 0, max: 1000 }),
    deleted: fc.boolean(),
  })
  .filter((e) => e.payer !== e.other)
  .map((e) => {
    const payerShare = Math.floor((e.amountPaise * e.payerShareFraction) / 1000);
    const otherShare = e.amountPaise - payerShare;
    return {
      payerId: e.payer,
      amountPaise: e.amountPaise,
      splits: [
        { userId: e.payer, sharePaise: payerShare },
        { userId: e.other, sharePaise: otherShare },
      ],
      deleted: e.deleted,
    };
  });

/**
 * Generates a valid settlement between two distinct roster members. The
 * `deleted` flag is also randomised so the in-code soft-delete filter is
 * exercised on every run.
 */
const settlementArb = fc
  .record({
    from: memberArb,
    to: memberArb,
    amountPaise: fc.integer({ min: 1, max: 1_000_000 }),
    deleted: fc.boolean(),
    contextType: fc.constant("friendship"),
    contextId: fc.constant("fid"),
  })
  .filter((s) => s.from !== s.to)
  .map((s) => ({
    fromUserId: s.from,
    toUserId: s.to,
    amountPaise: s.amountPaise,
    deleted: s.deleted,
    contextType: s.contextType,
    contextId: s.contextId,
  }));

describe("computeNetBalances property-based tests — mixed expense + settlement", () => {
  it("preserves zero-sum invariant under any mixed sequence", () => {
    fc.assert(
      fc.property(
        fc.array(expenseArb, { minLength: 0, maxLength: 10 }),
        fc.array(settlementArb, { minLength: 0, maxLength: 10 }),
        (expenses, settlements) => {
          const expenseSnaps = expenses.map(fakeSnap);
          const settlementSnaps = settlements.map(fakeSnap);

          const net = computeNetBalances(expenseSnaps, settlementSnaps);

          let sum = 0;
          for (const v of net.values()) {
            sum += v;
          }
          expect(sum).toBe(0);
        },
      ),
      { numRuns: 200 },
    );
  });

  it("simplifyDebts never throws BALANCE_INVARIANT_VIOLATED on the output of computeNetBalances", () => {
    fc.assert(
      fc.property(
        fc.array(expenseArb, { minLength: 0, maxLength: 10 }),
        fc.array(settlementArb, { minLength: 0, maxLength: 10 }),
        (expenses, settlements) => {
          const expenseSnaps = expenses.map(fakeSnap);
          const settlementSnaps = settlements.map(fakeSnap);

          const net = computeNetBalances(expenseSnaps, settlementSnaps);

          // simplifyDebts must succeed without throwing the zero-sum
          // violation. Any other throw is a test failure.
          expect(() => simplifyDebts(net)).not.toThrow();
        },
      ),
      { numRuns: 200 },
    );
  });

  it("excludes soft-deleted settlements from the fold (expenses are query-filtered upstream)", () => {
    // `computeNetBalances` is the unit under test. Soft-deleted expenses
    // are filtered at the Firestore QUERY level
    // (`where('deleted', '!=', true)`) so the snapshot list never
    // contains them by the time it reaches this function.
    // Soft-deleted SETTLEMENTS are filtered IN CODE because the
    // settlements query carries two equality filters and a third
    // inequality would require an unnecessarily over-specified
    // composite index (see Architect Notes §2). So this property test
    // exercises only the in-code settlement filter.
    fc.assert(
      fc.property(
        fc.array(expenseArb, { minLength: 0, maxLength: 5 }),
        fc.array(settlementArb, { minLength: 1, maxLength: 5 }),
        (expenses, settlements) => {
          // All expenses non-deleted (mirror real query behaviour);
          // all settlements force-deleted (must be filtered in code).
          const expensesActive = expenses.map((e) => ({ ...e, deleted: false }));
          const settlementsDeleted = settlements.map((s) => ({
            ...s,
            deleted: true,
          }));

          const netWithDeleted = computeNetBalances(
            expensesActive.map(fakeSnap),
            settlementsDeleted.map(fakeSnap),
          );

          // Same net balances must result from passing no settlements at
          // all — the deleted ones contribute nothing.
          const netWithoutSettlements = computeNetBalances(
            expensesActive.map(fakeSnap),
            [],
          );

          // Compare maps key-by-key.
          const allKeys = new Set([
            ...netWithDeleted.keys(),
            ...netWithoutSettlements.keys(),
          ]);
          for (const k of allKeys) {
            expect(netWithDeleted.get(k) ?? 0).toBe(
              netWithoutSettlements.get(k) ?? 0,
            );
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it("settlement-only sequence produces the credit-fromUserId / debit-toUserId net map", () => {
    fc.assert(
      fc.property(settlementArb, (s) => {
        // Force non-deleted so the settlement is included in the fold.
        const settlement = { ...s, deleted: false };
        const net = computeNetBalances([], [fakeSnap(settlement)]);

        expect(net.get(settlement.fromUserId)).toBe(settlement.amountPaise);
        expect(net.get(settlement.toUserId)).toBe(-settlement.amountPaise);
      }),
      { numRuns: 200 },
    );
  });
});
