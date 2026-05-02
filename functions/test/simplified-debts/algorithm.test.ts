import {
  simplifyDebts,
  projectToBalancesMap,
  Transfer,
} from "../../src/simplified-debts/algorithm";

describe("simplifyDebts", () => {
  /**
   * Helper: asserts every transfer has a positive integer amountPaise.
   */
  function assertAllAmountsArePositiveIntegers(transfers: Transfer[]): void {
    for (const t of transfers) {
      expect(t.amountPaise).toBeGreaterThan(0);
      expect(Number.isInteger(t.amountPaise)).toBe(true);
    }
  }

  // ---------------------------------------------------------------
  // Case 1: Empty input
  // ---------------------------------------------------------------
  it("returns empty transfers for empty input", () => {
    const result = simplifyDebts(new Map());
    expect(result).toEqual([]);
  });

  it("returns empty balances map for empty input", () => {
    const transfers = simplifyDebts(new Map());
    const balancesMap = projectToBalancesMap(transfers);
    expect(balancesMap).toEqual({});
  });

  // ---------------------------------------------------------------
  // Case 2: Single member with zero balance
  // ---------------------------------------------------------------
  it("returns empty transfers for a single zero-balance member", () => {
    const result = simplifyDebts(new Map([["A", 0]]));
    expect(result).toEqual([]);
  });

  // ---------------------------------------------------------------
  // Case 3: Perfectly balanced (all zeroes)
  // ---------------------------------------------------------------
  it("returns empty transfers when all members are balanced", () => {
    const result = simplifyDebts(
      new Map([
        ["A", 0],
        ["B", 0],
        ["C", 0],
      ]),
    );
    expect(result).toEqual([]);
  });

  // ---------------------------------------------------------------
  // Case 4: Cyclic debts that cancel to zero
  // ---------------------------------------------------------------
  it("returns empty transfers when cyclic debts cancel to zero balances", () => {
    // After netting, all balances are zero — the cycle already cancels.
    const result = simplifyDebts(
      new Map([
        ["A", 0],
        ["B", 0],
        ["C", 0],
      ]),
    );
    expect(result).toEqual([]);
  });

  // ---------------------------------------------------------------
  // Case 5: Three-person trip
  // ---------------------------------------------------------------
  describe("three-person trip", () => {
    const netBalances = new Map([
      ["A", 40000],
      ["B", -20000],
      ["C", -20000],
    ]);

    it("produces exactly 2 transfers", () => {
      const result = simplifyDebts(netBalances);
      expect(result).toHaveLength(2);
      assertAllAmountsArePositiveIntegers(result);
    });

    it("produces the correct transfers: B->A 20000, C->A 20000", () => {
      const result = simplifyDebts(netBalances);
      // Debtors B and C are tied at |20000|. Tie-break ascending by userId:
      // B < C, so B is paired first.
      expect(result).toEqual([
        { from: "B", to: "A", amountPaise: 20000 },
        { from: "C", to: "A", amountPaise: 20000 },
      ]);
    });

    it("produces the correct balances map", () => {
      const result = simplifyDebts(netBalances);
      const balancesMap = projectToBalancesMap(result);
      expect(balancesMap).toEqual({
        B: { A: 20000 },
        C: { A: 20000 },
      });
    });
  });

  // ---------------------------------------------------------------
  // Case 6: Five-person flat-share
  // ---------------------------------------------------------------
  describe("five-person flat-share", () => {
    const netBalances = new Map([
      ["A", 3900000],
      ["B", -800000],
      ["C", -900000],
      ["D", -1100000],
      ["E", -1100000],
    ]);

    it("produces exactly 4 transfers", () => {
      const result = simplifyDebts(netBalances);
      expect(result).toHaveLength(4);
      assertAllAmountsArePositiveIntegers(result);
    });

    it("produces the correct transfers in deterministic order", () => {
      const result = simplifyDebts(netBalances);
      // Debtors sorted descending by |amount|, then ascending userId for ties:
      // D (1100000) and E (1100000) tied -> D < E, so D first
      // Then C (900000), then B (800000)
      expect(result).toEqual([
        { from: "D", to: "A", amountPaise: 1100000 },
        { from: "E", to: "A", amountPaise: 1100000 },
        { from: "C", to: "A", amountPaise: 900000 },
        { from: "B", to: "A", amountPaise: 800000 },
      ]);
    });

    it("produces the correct balances map", () => {
      const result = simplifyDebts(netBalances);
      const balancesMap = projectToBalancesMap(result);
      expect(balancesMap).toEqual({
        B: { A: 800000 },
        C: { A: 900000 },
        D: { A: 1100000 },
        E: { A: 1100000 },
      });
    });
  });

  // ---------------------------------------------------------------
  // Case 7: Tie-breaking by userId
  // ---------------------------------------------------------------
  describe("tie-breaking by ascending userId", () => {
    const netBalances = new Map([
      ["uid_ghi", 30000],
      ["uid_abc", -15000],
      ["uid_def", -15000],
    ]);

    it("places uid_abc before uid_def when both owe 15000", () => {
      const result = simplifyDebts(netBalances);
      expect(result).toHaveLength(2);
      assertAllAmountsArePositiveIntegers(result);

      // uid_abc sorts before uid_def lexicographically
      expect(result[0]).toEqual({
        from: "uid_abc",
        to: "uid_ghi",
        amountPaise: 15000,
      });
      expect(result[1]).toEqual({
        from: "uid_def",
        to: "uid_ghi",
        amountPaise: 15000,
      });
    });
  });

  // ---------------------------------------------------------------
  // Case 8: Balance invariant violation
  // ---------------------------------------------------------------
  it("throws when sum of netPaise is not zero", () => {
    const netBalances = new Map([
      ["A", 100],
      ["B", -50],
    ]);
    expect(() => simplifyDebts(netBalances)).toThrow(
      /balance invariant violation/i,
    );
  });
});

describe("projectToBalancesMap", () => {
  it("returns empty object for empty transfers", () => {
    expect(projectToBalancesMap([])).toEqual({});
  });

  it("groups transfers by debtor (from) with creditor (to) as inner key", () => {
    const transfers: Transfer[] = [
      { from: "B", to: "A", amountPaise: 20000 },
      { from: "B", to: "C", amountPaise: 10000 },
      { from: "D", to: "A", amountPaise: 5000 },
    ];
    expect(projectToBalancesMap(transfers)).toEqual({
      B: { A: 20000, C: 10000 },
      D: { A: 5000 },
    });
  });
});
