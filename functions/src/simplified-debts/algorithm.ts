/**
 * Simplified Debts Algorithm — Pure Functions
 *
 * Implements the greedy debt-simplification algorithm per
 * docs/design/07-technical/simplified-debts-algorithm.md
 *
 * Determinism: ties between creditors or debtors with equal absolute netPaise
 * are broken by ascending userId (lexicographic string comparison).
 *
 * All monetary values are integer paise (Invariant 1). No floating-point
 * arithmetic is used.
 */

/** A single transfer from a debtor to a creditor. */
export interface Transfer {
  /** The userId who owes money (debtor). */
  from: string;
  /** The userId who is owed money (creditor). */
  to: string;
  /** Amount in integer paise, always > 0. */
  amountPaise: number;
}

/**
 * Nested map written to Firestore: debtorUserId -> creditorUserId -> amountPaise.
 * All amounts are positive integers in paise.
 * Per docs/design/07-technical/firestore-schema.md.
 */
export interface SimplifiedBalancesMap {
  [debtorUserId: string]: {
    [creditorUserId: string]: number;
  };
}

/**
 * Computes the minimal set of transfers that settle all debts.
 *
 * Algorithm:
 * 1. Validate that the sum of all netPaise is zero.
 * 2. Partition members into creditors (netPaise > 0) and debtors (netPaise < 0).
 * 3. Sort creditors descending by netPaise, tie-break ascending by userId.
 *    Sort debtors descending by |netPaise|, tie-break ascending by userId.
 * 4. Greedy pairing: match the largest creditor with the largest debtor,
 *    transfer Math.min of their absolute amounts, adjust balances, remove
 *    any participant reaching zero.
 *
 * @param netBalances - Map of userId to netPaise. Positive = creditor (owed money),
 *   negative = debtor (owes money), zero = balanced.
 * @returns Array of Transfer objects representing the simplified debt settlement.
 *   Transfer count is guaranteed to be <= N-1 where N is the number of members
 *   with non-zero balances.
 * @throws Error if the sum of all netPaise is not zero (balance invariant violation).
 */
export function simplifyDebts(
  netBalances: ReadonlyMap<string, number>,
): Transfer[] {
  // 1. Validate balance invariant
  let total = 0;
  for (const amount of netBalances.values()) {
    total += amount;
  }
  if (total !== 0) {
    throw new Error(
      `Balance invariant violation: sum of netPaise is ${total}, expected 0.`,
    );
  }

  // 2. Partition into creditors and debtors (skip zero-balance members)
  const creditors: Array<{ userId: string; amount: number }> = [];
  const debtors: Array<{ userId: string; amount: number }> = [];

  for (const [userId, amount] of netBalances) {
    if (amount > 0) {
      creditors.push({ userId, amount });
    } else if (amount < 0) {
      debtors.push({ userId, amount: Math.abs(amount) });
    }
    // amount === 0 => skip
  }

  // 3. Sort creditors: descending by amount, ascending by userId for ties
  creditors.sort((a, b) => {
    if (b.amount !== a.amount) {
      return b.amount - a.amount;
    }
    return a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0;
  });

  // Sort debtors: descending by amount (already absolute), ascending by userId for ties
  debtors.sort((a, b) => {
    if (b.amount !== a.amount) {
      return b.amount - a.amount;
    }
    return a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0;
  });

  // 4. Greedy pairing loop
  const transfers: Transfer[] = [];
  let ci = 0;
  let di = 0;

  while (ci < creditors.length && di < debtors.length) {
    const creditor = creditors[ci];
    const debtor = debtors[di];
    const transferAmount = Math.min(creditor.amount, debtor.amount);

    transfers.push({
      from: debtor.userId,
      to: creditor.userId,
      amountPaise: transferAmount,
    });

    creditor.amount -= transferAmount;
    debtor.amount -= transferAmount;

    if (creditor.amount === 0) {
      ci++;
    }
    if (debtor.amount === 0) {
      di++;
    }
  }

  return transfers;
}

/**
 * Projects a flat array of transfers into the nested simplifiedBalances map
 * for Firestore storage.
 *
 * The map shape is: { [debtorUserId]: { [creditorUserId]: amountPaise } }
 * Per docs/design/07-technical/firestore-schema.md — only debtors appear as
 * outer keys, amounts are always positive.
 *
 * @param transfers - Array of Transfer objects to project.
 * @returns The nested SimplifiedBalancesMap suitable for Firestore writes.
 */
export function projectToBalancesMap(
  transfers: Transfer[],
): SimplifiedBalancesMap {
  const result: SimplifiedBalancesMap = {};

  for (const transfer of transfers) {
    if (!(transfer.from in result)) {
      result[transfer.from] = {};
    }
    result[transfer.from][transfer.to] = transfer.amountPaise;
  }

  return result;
}
