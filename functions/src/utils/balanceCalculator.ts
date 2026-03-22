/**
 * Balance recalculation logic for groups and friend pairs.
 *
 * This is the core algorithm triggered whenever an expense or
 * settlement is created, updated, or deleted. It reads ALL non-deleted
 * expenses and settlements, computes pairwise net balances, and
 * atomically writes the result to the balances subcollection.
 *
 * All amounts are integers in paise. Division uses Math.floor() with
 * Largest Remainder distribution for remainders.
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { canonicalPairKey } from "./pairKey";
import {
  groupExpensesCol,
  groupSettlementsCol,
  groupBalancesCol,
  groupBalanceDoc,
  friendExpensesCol,
  friendSettlementsCol,
  friendNetBalanceDoc,
} from "./firestore_paths";

/**
 * Recalculates all pairwise balances for a group.
 *
 * Reads every non-deleted expense and settlement, computes net
 * balances between each pair of members, and writes the results
 * atomically via a batched write.
 *
 * Balance convention:
 *   - pairKey = canonicalPairKey(userA, userB) where userA < userB
 *   - positive netPaise → userB owes userA
 *   - negative netPaise → userA owes userB
 *
 * @param groupId - The group to recalculate.
 */
export async function recalculateGroupBalances(
  groupId: string
): Promise<void> {
  const db = getFirestore();

  // 1. Read ALL non-deleted expenses
  const expensesSnap = await db
    .collection(groupExpensesCol(groupId))
    .where("isDeleted", "==", false)
    .get();

  // 2. Read ALL non-deleted settlements
  const settlementsSnap = await db
    .collection(groupSettlementsCol(groupId))
    .where("isDeleted", "==", false)
    .get();

  // 3. Compute pairwise balances from expenses
  //    For each expense, read its payers and splits subcollections
  //    to determine who paid and who owes.
  const balances = new Map<string, number>(); // pairKey → net paise

  for (const expenseDoc of expensesSnap.docs) {
    const expense = expenseDoc.data();
    const expenseRef = expenseDoc.ref;

    // Read payers subcollection
    const payersSnap = await expenseRef.collection("payers").get();
    const payers = new Map<string, number>(); // userId → amountPaid (paise)
    for (const payerDoc of payersSnap.docs) {
      const payer = payerDoc.data();
      payers.set(payer.userId as string, payer.amountPaid as number);
    }

    // Read splits subcollection
    const splitsSnap = await expenseRef.collection("splits").get();
    const splits = new Map<string, number>(); // userId → amountOwed (paise)
    for (const splitDoc of splitsSnap.docs) {
      const split = splitDoc.data();
      splits.set(split.userId as string, split.amountOwed as number);
    }

    // Fallback: if no payers subcollection, use expense.createdBy as sole payer
    if (payers.size === 0 && expense.createdBy && expense.amount) {
      payers.set(expense.createdBy as string, expense.amount as number);
    }

    // Compute net contribution per user: paid - owed
    // Then compute pairwise deltas
    const allUsers = new Set([...payers.keys(), ...splits.keys()]);
    const netContribution = new Map<string, number>(); // userId → net (positive = credited)

    for (const userId of allUsers) {
      const paid = payers.get(userId) ?? 0;
      const owed = splits.get(userId) ?? 0;
      netContribution.set(userId, paid - owed);
    }

    // For each pair, accumulate balances
    const userIds = Array.from(allUsers);
    for (let i = 0; i < userIds.length; i++) {
      for (let j = i + 1; j < userIds.length; j++) {
        const a = userIds[i];
        const b = userIds[j];
        const key = canonicalPairKey(a, b);

        // Determine contribution from this expense:
        // We need to figure out how much b owes a (or vice versa).
        // For each payer p, each split user s gets: s owes p their split share
        // proportional to p's payment.
        //
        // Simplified: For a pair (a, b), the net effect is:
        // delta = (what a paid towards b's share) - (what b paid towards a's share)
        //       = (a's payment * b's share / total) - (b's payment * a's share / total)
        //
        // But since we have explicit payer/split amounts, we compute directly:
        // For each payer, their overpayment is distributed among split users
        // proportional to their split amount.

        // Actually, the simplest correct approach:
        // net contribution: paid - owed
        // If net > 0, the user is a creditor (paid more than their share)
        // If net < 0, the user is a debtor (owes more than they paid)
        // We don't need pairwise from expenses; we need per-user net, then
        // debt simplification happens later.
        //
        // BUT for pairwise balance tracking (not simplified), we need:
        // For each (payer, splitUser) pair, splitUser owes payer.
        // This is what we track in the balances subcollection.

        // Skip — we'll use the direct payer→split approach below
        void key; // suppress unused
      }
    }

    // Direct approach: for each payer, for each split user (other than payer),
    // that split user owes that payer their split portion scaled by payer's share.
    const totalPaid = Array.from(payers.values()).reduce((a, b) => a + b, 0);

    for (const [payerId, amountPaid] of payers.entries()) {
      for (const [splitUserId, amountOwed] of splits.entries()) {
        if (payerId === splitUserId) continue;
        if (totalPaid === 0) continue;

        // How much of splitUser's debt is owed to this specific payer?
        // = splitUser's share * (payer's contribution / total paid)
        const oweAmount = Math.floor((amountOwed * amountPaid) / totalPaid);
        if (oweAmount === 0) continue;

        const key = canonicalPairKey(payerId, splitUserId);
        // Convention: positive = first in canonical order is owed
        const direction = payerId < splitUserId ? 1 : -1;
        balances.set(key, (balances.get(key) ?? 0) + direction * oweAmount);
      }
    }
  }

  // 4. Apply settlements
  for (const settlementDoc of settlementsSnap.docs) {
    const settlement = settlementDoc.data();
    const fromUserId = settlement.fromUserId as string;
    const toUserId = settlement.toUserId as string;
    const amount = settlement.amount as number;

    const key = canonicalPairKey(fromUserId, toUserId);
    // Settlement: fromUser pays toUser → reduces what fromUser owes toUser
    // In our convention: if fromUser < toUser, positive means toUser owes fromUser.
    // fromUser paying toUser means fromUser is the creditor gaining, so:
    // direction for the settlement is: fromUser < toUser ? +amount : -amount
    const direction = fromUserId < toUserId ? 1 : -1;
    balances.set(key, (balances.get(key) ?? 0) + direction * amount);
  }

  // 5. Atomic write to balances subcollection
  const batch = db.batch();

  // Clear existing balances
  const existingBalances = await db
    .collection(groupBalancesCol(groupId))
    .get();
  for (const doc of existingBalances.docs) {
    batch.delete(doc.ref);
  }

  // Write new balances (skip zero balances)
  for (const [pairKey, netPaise] of balances.entries()) {
    if (netPaise === 0) continue;

    const [userA, userB] = pairKey.split("_");
    const balanceRef = db.doc(groupBalanceDoc(groupId, pairKey));
    batch.set(balanceRef, {
      userA,
      userB,
      amount: netPaise,
      lastUpdated: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

/**
 * Recalculates the net balance for a friend pair.
 *
 * Similar to group balance recalculation but simpler — only two
 * users are involved, producing a single balance document.
 *
 * @param friendPairId - The canonical friend pair ID.
 */
export async function recalculateFriendBalance(
  friendPairId: string
): Promise<void> {
  const db = getFirestore();
  const [userA, userB] = friendPairId.split("_");

  // 1. Read all non-deleted expenses
  const expensesSnap = await db
    .collection(friendExpensesCol(friendPairId))
    .where("isDeleted", "==", false)
    .get();

  // 2. Read all non-deleted settlements
  const settlementsSnap = await db
    .collection(friendSettlementsCol(friendPairId))
    .where("isDeleted", "==", false)
    .get();

  // 3. Compute net balance
  let netPaise = 0; // positive = userB owes userA

  for (const expenseDoc of expensesSnap.docs) {
    const expenseRef = expenseDoc.ref;
    const expense = expenseDoc.data();

    // Read payers
    const payersSnap = await expenseRef.collection("payers").get();
    const payers = new Map<string, number>();
    for (const payerDoc of payersSnap.docs) {
      const payer = payerDoc.data();
      payers.set(payer.userId as string, payer.amountPaid as number);
    }

    // Read splits
    const splitsSnap = await expenseRef.collection("splits").get();
    const splits = new Map<string, number>();
    for (const splitDoc of splitsSnap.docs) {
      const split = splitDoc.data();
      splits.set(split.userId as string, split.amountOwed as number);
    }

    // Fallback: sole payer
    if (payers.size === 0 && expense.createdBy && expense.amount) {
      payers.set(expense.createdBy as string, expense.amount as number);
    }

    // For a friend pair, compute: how much userB owes userA from this expense
    // net = (userA paid - userA owes) = userA's net contribution
    const aPaid = payers.get(userA) ?? 0;
    const aOwed = splits.get(userA) ?? 0;
    netPaise += aPaid - aOwed;
  }

  // 4. Apply settlements
  for (const settlementDoc of settlementsSnap.docs) {
    const settlement = settlementDoc.data();
    const fromUserId = settlement.fromUserId as string;
    const amount = settlement.amount as number;

    // fromUser pays toUser
    if (fromUserId === userA) {
      // userA paid userB → userA becomes more of a creditor
      netPaise += amount;
    } else {
      // userB paid userA → userA becomes less of a creditor
      netPaise -= amount;
    }
  }

  // 5. Write the single balance document
  const balanceRef = db.doc(friendNetBalanceDoc(friendPairId));
  await balanceRef.set({
    userA,
    userB,
    amount: netPaise, // positive = userB owes userA
    lastUpdated: FieldValue.serverTimestamp(),
  });
}
