/**
 * Rate limiting for callable functions.
 *
 * Uses a Firestore document per (user, action) pair to track
 * call counts within a sliding window. The document is stored
 * in the `rateLimits` collection (clients cannot read/write it).
 */

import { HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { rateLimitDoc } from "./firestore_paths";

interface RateLimitConfig {
  /** Maximum number of calls allowed within the window. */
  maxCalls: number;
  /** Window duration in milliseconds. */
  windowMs: number;
}

/**
 * Checks and increments the rate limit counter for a user action.
 *
 * @param uid - The user's Firebase Auth UID.
 * @param action - A unique action identifier (e.g. "simplifyDebts", "nudge_targetUserId").
 * @param limits - The rate limit configuration.
 * @throws RESOURCE_EXHAUSTED if the rate limit is exceeded.
 */
export async function checkRateLimit(
  uid: string,
  action: string,
  limits: RateLimitConfig
): Promise<void> {
  const db = getFirestore();
  const docPath = rateLimitDoc(`${uid}_${action}`);
  const docRef = db.doc(docPath);
  const doc = await docRef.get();

  const now = Date.now();
  const data = doc.data();

  if (data) {
    const windowStart = data.windowStart as number;
    if (now - windowStart < limits.windowMs) {
      if ((data.count as number) >= limits.maxCalls) {
        throw new HttpsError(
          "resource-exhausted",
          "Rate limit exceeded. Please try again later."
        );
      }
      await docRef.update({ count: FieldValue.increment(1) });
      return;
    }
  }

  // Start a new window
  await docRef.set({ windowStart: now, count: 1 });
}
