import fc from "fast-check";
import { simplifyDebts } from "../../src/simplified-debts/algorithm";

/**
 * Property-based tests for the simplified-debts algorithm.
 *
 * Uses fast-check to generate random valid inputs and verify structural
 * properties that must hold for any input.
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
