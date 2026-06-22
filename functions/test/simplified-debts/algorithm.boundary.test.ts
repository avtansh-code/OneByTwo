/**
 * Simplified-debts algorithm — boundary and scalability tests.
 *
 * Closes the two remaining `algorithm.ts` spot-check gaps recorded in
 * docs/audits/sprint-1/02-test-suite-health.md §2.5 (Spot Check 3):
 *
 *   - SC3 — large numbers near `Number.MAX_SAFE_INTEGER`. The property
 *     suite (algorithm.property.test.ts) caps balances at 10,000,000 paise
 *     (₹1 lakh); real expenses can exceed that, so the safe-integer ceiling
 *     must be exercised explicitly.
 *   - SC4 — scalability for large groups (100+ members). The property
 *     suite maxes at 8 members. The simplified-debts core operates on a
 *     net-balance set and is friendship/group agnostic, so a 100+ member
 *     test is written here at the algorithm layer (NOT against the
 *     not-yet-built Sprint-3 Groups feature).
 *
 * Invariant 1 (money is integer paise): every balance and every transfer
 * amount is a whole `number` of paise. No floating-point arithmetic is
 * introduced — the ceiling exercised here is JS integer precision, not
 * rupee decimals.
 *
 * @module test/simplified-debts/algorithm.boundary.test.ts
 */

import {
  simplifyDebts,
  projectToBalancesMap,
  Transfer,
} from "../../src/simplified-debts/algorithm";

/**
 * Folds a transfer list back onto an opening net-balance map and returns
 * the residual position of every member. A correct, zero-sum settlement
 * leaves every member at exactly zero with no precision drift.
 */
function residualAfterSettling(
  openingNet: ReadonlyMap<string, number>,
  transfers: readonly Transfer[],
): Map<string, number> {
  const settled = new Map<string, number>(openingNet);
  for (const t of transfers) {
    // A debtor (from) pays down its negative balance; a creditor (to)
    // has its positive balance reduced by the same integer amount.
    settled.set(t.from, (settled.get(t.from) ?? 0) + t.amountPaise);
    settled.set(t.to, (settled.get(t.to) ?? 0) - t.amountPaise);
  }
  return settled;
}

/**
 * Asserts every transfer carries a strictly positive, safe-integer amount.
 */
function assertAllAmountsArePositiveSafeIntegers(
  transfers: readonly Transfer[],
): void {
  for (const t of transfers) {
    expect(Number.isInteger(t.amountPaise)).toBe(true);
    expect(Number.isSafeInteger(t.amountPaise)).toBe(true);
    expect(t.amountPaise).toBeGreaterThan(0);
  }
}

describe("SC3: MAX_SAFE_INTEGER overflow boundary", () => {
  // The largest paise value JS can represent exactly as an integer.
  const MAX = Number.MAX_SAFE_INTEGER; // 9_007_199_254_740_991 paise

  it("settles a single creditor at the safe-integer boundary exactly", () => {
    const result = simplifyDebts(
      new Map([
        ["A", MAX],
        ["B", -MAX],
      ]),
    );

    expect(result).toEqual([{ from: "B", to: "A", amountPaise: MAX }]);
    // The settled amount is the exact boundary value — no rounding.
    expect(result[0].amountPaise).toBe(MAX);
    assertAllAmountsArePositiveSafeIntegers(result);
  });

  it("splits a boundary debt across debtors with no precision drift", () => {
    // A is owed exactly MAX, supplied by two debtors summing to -MAX.
    const openingNet = new Map([
      ["A", MAX],
      ["B", -(MAX - 1)],
      ["C", -1],
    ]);

    const result = simplifyDebts(openingNet);

    assertAllAmountsArePositiveSafeIntegers(result);
    expect(projectToBalancesMap(result)).toEqual({
      B: { A: MAX - 1 },
      C: { A: 1 },
    });

    // Folding the transfers back nets every member to exactly zero.
    for (const residual of residualAfterSettling(openingNet, result).values()) {
      expect(residual).toBe(0);
    }
  });

  it("handles realistic large expenses far above the 10M-paise cap", () => {
    // Audit SC3: the property suite caps balances at 10,000,000 paise
    // (₹1 lakh). A ₹10 crore expense is 10,00,00,000 rupees, i.e.
    // 10,000,000,000 paise — three orders of magnitude past the cap, yet
    // still comfortably below MAX.
    const tenCroreInPaise = 10_000_000_000;
    const openingNet = new Map([
      ["A", 2 * tenCroreInPaise],
      ["B", -tenCroreInPaise],
      ["C", -tenCroreInPaise],
    ]);

    const result = simplifyDebts(openingNet);

    expect(result).toEqual([
      { from: "B", to: "A", amountPaise: tenCroreInPaise },
      { from: "C", to: "A", amountPaise: tenCroreInPaise },
    ]);
    assertAllAmountsArePositiveSafeIntegers(result);
  });

  it("documents the safe-integer ceiling as the algorithm's domain", () => {
    // The correctness contract holds while every balance — and every
    // partial sum the algorithm forms — stays within the safe-integer
    // range. This is the integer-paise contract (Invariant 1); paise are
    // whole numbers, so the only ceiling is JS number precision, never a
    // rupee decimal. Callers must keep paise within [-MAX, MAX].
    expect(Number.isSafeInteger(MAX)).toBe(true);
    // One step past the (even) ceiling is no longer distinctly representable.
    expect(Number.isSafeInteger(MAX + 2)).toBe(false);
    // MAX paise is an astronomically large rupee figure, so real-world
    // expenses never approach the ceiling.
    expect(MAX).toBeGreaterThan(9_000_000_000_000_000);
  });
});

describe("SC4: large-group (100+) scalability", () => {
  it("settles a 150-member star topology in exactly N-1 transfers", () => {
    // One creditor owed by 149 equal debtors. The greedy algorithm pays
    // each debtor off in a single transfer to the creditor.
    const memberCount = 150;
    const perDebtorPaise = 1_000;
    const debtorCount = memberCount - 1;

    const openingNet = new Map<string, number>();
    openingNet.set("creditor", perDebtorPaise * debtorCount);
    for (let i = 0; i < debtorCount; i++) {
      // Zero-padded ids keep the deterministic ascending tie-break stable.
      openingNet.set(`debtor_${String(i).padStart(3, "0")}`, -perDebtorPaise);
    }

    const result = simplifyDebts(openingNet);

    // Transfer count never exceeds N-1; a pure star hits the bound exactly.
    expect(result).toHaveLength(debtorCount);
    expect(result.length).toBeLessThanOrEqual(memberCount - 1);
    assertAllAmountsArePositiveSafeIntegers(result);

    for (const residual of residualAfterSettling(openingNet, result).values()) {
      expect(residual).toBe(0);
    }
  });

  it("settles 200 paired members within the N-1 transfer bound", () => {
    // 100 creditors and 100 debtors, each ±500 paise. Equal pairing keeps
    // the greedy loop to one transfer per pair.
    const pairCount = 100;
    const amountPaise = 500;

    const openingNet = new Map<string, number>();
    for (let i = 0; i < pairCount; i++) {
      const suffix = String(i).padStart(3, "0");
      openingNet.set(`creditor_${suffix}`, amountPaise);
      openingNet.set(`debtor_${suffix}`, -amountPaise);
    }
    const memberCount = pairCount * 2;

    const result = simplifyDebts(openingNet);

    expect(result.length).toBeLessThanOrEqual(memberCount - 1);
    expect(result).toHaveLength(pairCount);
    assertAllAmountsArePositiveSafeIntegers(result);

    for (const residual of residualAfterSettling(openingNet, result).values()) {
      expect(residual).toBe(0);
    }
  });

  it("is deterministic and fast for a 1000-member group", () => {
    // Scalability stress: 1000 members. The algorithm is O(N log N) (two
    // sorts plus a linear greedy pass), so this is a microsecond workload;
    // the generous 2s ceiling only guards against an accidental quadratic
    // regression and will never flake on CI.
    const memberCount = 1_000;
    const perDebtorPaise = 137;
    const debtorCount = memberCount - 1;

    const openingNet = new Map<string, number>();
    openingNet.set("creditor", perDebtorPaise * debtorCount);
    for (let i = 0; i < debtorCount; i++) {
      openingNet.set(`debtor_${String(i).padStart(4, "0")}`, -perDebtorPaise);
    }

    const start = Date.now();
    const first = simplifyDebts(openingNet);
    const elapsedMs = Date.now() - start;
    const second = simplifyDebts(openingNet);

    expect(first).toHaveLength(debtorCount);
    expect(first.length).toBeLessThanOrEqual(memberCount - 1);
    assertAllAmountsArePositiveSafeIntegers(first);
    // Determinism: identical input yields a byte-for-byte identical plan.
    expect(second).toEqual(first);
    expect(elapsedMs).toBeLessThan(2_000);

    for (const residual of residualAfterSettling(openingNet, first).values()) {
      expect(residual).toBe(0);
    }
  });
});
