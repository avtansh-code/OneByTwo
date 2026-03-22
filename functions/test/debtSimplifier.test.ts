/**
 * Tests for the debt simplification algorithm.
 */

import { simplifyDebts, pairwiseToNetBalances } from "../src/utils/debtSimplifier";

describe("simplifyDebts", () => {
  it("should return no transactions when all balances are zero", () => {
    const balances = new Map<string, number>([
      ["alice", 0],
      ["bob", 0],
    ]);
    const result = simplifyDebts(balances);
    expect(result).toEqual([]);
  });

  it("should return no transactions when the map is empty", () => {
    const result = simplifyDebts(new Map());
    expect(result).toEqual([]);
  });

  it("should handle a simple two-person debt", () => {
    // Alice is owed ₹100 (10000 paise), Bob owes ₹100
    const balances = new Map<string, number>([
      ["alice", 10000],
      ["bob", -10000],
    ]);
    const result = simplifyDebts(balances);
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      from: "bob",
      to: "alice",
      amountPaise: 10000,
    });
  });

  it("should simplify a three-person chain into fewer transactions", () => {
    // Alice is owed ₹300, Bob is owed ₹100, Charlie owes ₹400
    const balances = new Map<string, number>([
      ["alice", 30000],
      ["bob", 10000],
      ["charlie", -40000],
    ]);
    const result = simplifyDebts(balances);

    // Total owed to creditors: 40000. Charlie pays alice 30000, charlie pays bob 10000.
    expect(result).toHaveLength(2);

    const totalPaid = result.reduce((sum, t) => sum + t.amountPaise, 0);
    expect(totalPaid).toBe(40000);

    // All from charlie
    for (const t of result) {
      expect(t.from).toBe("charlie");
    }
  });

  it("should handle balanced net to zero across multiple users", () => {
    // A is owed 50, B is owed 30, C owes 40, D owes 40
    const balances = new Map<string, number>([
      ["A", 5000],
      ["B", 3000],
      ["C", -4000],
      ["D", -4000],
    ]);
    const result = simplifyDebts(balances);

    // Verify conservation: total credits = total debits
    const totalFrom = result.reduce((sum, t) => sum + t.amountPaise, 0);
    expect(totalFrom).toBe(8000);

    // Verify no self-payments
    for (const t of result) {
      expect(t.from).not.toBe(t.to);
      expect(t.amountPaise).toBeGreaterThan(0);
    }
  });

  it("should produce fewer transactions than the naive approach", () => {
    // 4 people, many potential pairwise debts
    // Naive: up to 6 transactions. Simplified should be ≤ 3.
    const balances = new Map<string, number>([
      ["A", 10000],   // owed ₹100
      ["B", 5000],    // owed ₹50
      ["C", -7000],   // owes ₹70
      ["D", -8000],   // owes ₹80
    ]);
    const result = simplifyDebts(balances);
    expect(result.length).toBeLessThanOrEqual(3);
  });
});

describe("pairwiseToNetBalances", () => {
  it("should convert pairwise balances to per-user net balances", () => {
    const pairwise = [
      { userA: "alice", userB: "bob", amount: 5000 },     // bob owes alice ₹50
      { userA: "alice", userB: "charlie", amount: -3000 }, // alice owes charlie ₹30
    ];
    const net = pairwiseToNetBalances(pairwise);

    // alice: +5000 (from bob) + (-3000) (owes charlie) = +2000
    expect(net.get("alice")).toBe(2000);
    // bob: -5000
    expect(net.get("bob")).toBe(-5000);
    // charlie: +3000
    expect(net.get("charlie")).toBe(3000);
  });

  it("should return an empty map for no balances", () => {
    const net = pairwiseToNetBalances([]);
    expect(net.size).toBe(0);
  });
});
