/**
 * Canonical pair key utilities.
 *
 * Used for:
 *  - Balance pair IDs in groups: groups/{gid}/balances/{pairKey}
 *  - Friend pair document IDs: friends/{pairKey}
 *
 * The canonical key is deterministic: min(a, b) + "_" + max(a, b),
 * ensuring the same pair always produces the same key regardless
 * of argument order.
 */

/**
 * Produces a canonical pair key from two user IDs.
 *
 * @param userA - First user ID.
 * @param userB - Second user ID.
 * @returns A deterministic key: `${min}_${max}` (lexicographic ordering).
 * @throws Error if userA and userB are the same.
 */
export function canonicalPairKey(userA: string, userB: string): string {
  if (userA === userB) {
    throw new Error("Cannot create a pair key for the same user.");
  }
  return userA < userB ? `${userA}_${userB}` : `${userB}_${userA}`;
}

/**
 * Splits a canonical pair key back into its two user IDs.
 *
 * @param pairKey - The canonical pair key.
 * @returns A tuple [userA, userB] where userA < userB.
 * @throws Error if the pair key is not in the expected format.
 */
export function splitPairKey(pairKey: string): [string, string] {
  const idx = pairKey.indexOf("_");
  if (idx <= 0 || idx >= pairKey.length - 1) {
    throw new Error(`Invalid pair key format: ${pairKey}`);
  }
  const userA = pairKey.substring(0, idx);
  const userB = pairKey.substring(idx + 1);
  if (userA >= userB) {
    throw new Error(`Pair key is not in canonical order: ${pairKey}`);
  }
  return [userA, userB];
}

/**
 * Given a pair key and one user ID, returns the other user ID.
 *
 * @param pairKey - The canonical pair key.
 * @param userId - One of the two user IDs in the pair.
 * @returns The other user ID.
 * @throws Error if userId is not part of the pair.
 */
export function otherUserInPair(pairKey: string, userId: string): string {
  const [userA, userB] = splitPairKey(pairKey);
  if (userId === userA) return userB;
  if (userId === userB) return userA;
  throw new Error(`User ${userId} is not part of pair ${pairKey}.`);
}
