/**
 * Lookup User By Phone Number — Pure Algorithm
 *
 * Queries Firestore for a user document matching the given phone number
 * and returns a safe subset of fields (displayName, photoUrl, otherUserId).
 * Private fields (phoneNumber, fcmTokens, notificationPrefs, locale,
 * createdAt, updatedAt) are never included in the response.
 *
 * @module lookup-user-by-phone-number/algorithm
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Dependencies injected for testability. */
export interface LookupAlgorithmDeps {
  db: FirebaseFirestore.Firestore;
}

/** Discriminated union for the lookup result. */
export type LookupResult =
  | {matched: false}
  | {matched: true; displayName: string; photoUrl: string | null; otherUserId: string};

// ---------------------------------------------------------------------------
// Algorithm
// ---------------------------------------------------------------------------

/**
 * Looks up a user by phone number, returning only safe public fields.
 *
 * @param phoneNumber - E.164 phone number to search for.
 * @param callerUserId - UID of the calling user (currently unused but
 *   reserved for future self-lookup filtering).
 * @param deps - Injected Firestore dependency.
 * @returns A LookupResult — either unmatched or matched with safe fields.
 */
export async function lookupUserByPhoneNumber(
  phoneNumber: string,
  callerUserId: string,
  deps: LookupAlgorithmDeps,
): Promise<LookupResult> {
  // Suppress unused-parameter lint — callerUserId is part of the contract.
  void callerUserId;

  const snapshot = await deps.db
    .collection("users")
    .where("phoneNumber", "==", phoneNumber)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return {matched: false};
  }

  const doc = snapshot.docs[0];
  const data = doc.data();

  return {
    matched: true,
    displayName: data.displayName as string,
    photoUrl: (data.photoUrl as string | null) ?? null,
    otherUserId: doc.id,
  };
}
