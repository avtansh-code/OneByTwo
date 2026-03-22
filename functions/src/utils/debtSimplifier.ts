/**
 * Debt simplification algorithm.
 *
 * Minimizes the number of transactions needed to settle all debts
 * within a group. Uses a greedy algorithm that matches the largest
 * creditor with the largest debtor iteratively.
 *
 * All amounts are integers in paise.
 */

export interface SimplifiedTransaction {
  /** User who needs to pay. */
  from: string;
  /** User who receives the payment. */
  to: string;
  /** Amount in paise. */
  amountPaise: number;
}

/**
 * Simplifies debts by minimizing the number of transactions.
 *
 * @param netBalances - Map of userId → net balance in paise.
 *   Positive = the user is owed money (creditor).
 *   Negative = the user owes money (debtor).
 *   The sum of all balances must be zero.
 *
 * @returns An array of simplified transactions.
 */
export function simplifyDebts(
  netBalances: Map<string, number>
): SimplifiedTransaction[] {
  // Separate creditors and debtors
  const creditors: Array<[string, number]> = [];
  const debtors: Array<[string, number]> = [];

  for (const [userId, balance] of netBalances) {
    if (balance > 0) {
      creditors.push([userId, balance]);
    } else if (balance < 0) {
      debtors.push([userId, -balance]); // Store as positive for easier math
    }
    // balance === 0 → skip, user is fully settled
  }

  // Sort descending by amount for greedy matching
  creditors.sort((a, b) => b[1] - a[1]);
  debtors.sort((a, b) => b[1] - a[1]);

  const transactions: SimplifiedTransaction[] = [];
  let i = 0;
  let j = 0;

  while (i < creditors.length && j < debtors.length) {
    const amount = Math.min(creditors[i][1], debtors[j][1]);

    if (amount > 0) {
      transactions.push({
        from: debtors[j][0],
        to: creditors[i][0],
        amountPaise: amount,
      });
    }

    creditors[i][1] -= amount;
    debtors[j][1] -= amount;

    if (creditors[i][1] === 0) i++;
    if (debtors[j][1] === 0) j++;
  }

  return transactions;
}

/**
 * Converts pairwise balances (as stored in Firestore) into per-user
 * net balances suitable for the simplification algorithm.
 *
 * @param pairwiseBalances - Array of {userA, userB, amount} objects.
 *   amount > 0 means userB owes userA.
 *   amount < 0 means userA owes userB.
 *
 * @returns Map of userId → net balance (positive = owed money).
 */
export function pairwiseToNetBalances(
  pairwiseBalances: Array<{ userA: string; userB: string; amount: number }>
): Map<string, number> {
  const net = new Map<string, number>();

  for (const { userA, userB, amount } of pairwiseBalances) {
    // amount > 0 → userB owes userA → userA is creditor (+), userB is debtor (-)
    net.set(userA, (net.get(userA) ?? 0) + amount);
    net.set(userB, (net.get(userB) ?? 0) - amount);
  }

  return net;
}
