/**
 * Authentication helpers for Cloud Functions.
 */

import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { groupMemberDoc, friendDoc } from "./firestore_paths";

/**
 * Validates that the caller is authenticated.
 *
 * @param request - The callable function request.
 * @returns The authenticated user's UID.
 * @throws UNAUTHENTICATED if the request has no auth context.
 */
export function requireAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return request.auth.uid;
}

/**
 * Validates that the caller is an active member of the specified group.
 *
 * @param uid - The user's UID.
 * @param groupId - The group to check membership for.
 * @throws PERMISSION_DENIED if the user is not an active group member.
 */
export async function requireGroupMember(
  uid: string,
  groupId: string
): Promise<void> {
  const memberSnap = await getFirestore()
    .doc(groupMemberDoc(groupId, uid))
    .get();

  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "Not a group member.");
  }

  const data = memberSnap.data();
  if (data && data.isActive === false) {
    throw new HttpsError("permission-denied", "Group membership is inactive.");
  }
}

/**
 * Validates that the caller is an admin (or owner) of the specified group.
 *
 * @param uid - The user's UID.
 * @param groupId - The group to check admin status for.
 * @throws PERMISSION_DENIED if the user is not a group admin or owner.
 */
export async function requireGroupAdmin(
  uid: string,
  groupId: string
): Promise<void> {
  const memberSnap = await getFirestore()
    .doc(groupMemberDoc(groupId, uid))
    .get();

  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "Not a group member.");
  }

  const data = memberSnap.data();
  if (!data || data.isActive === false) {
    throw new HttpsError("permission-denied", "Group membership is inactive.");
  }

  if (data.role !== "owner" && data.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin privileges required.");
  }
}

/**
 * Validates that the caller is a member of the specified friend pair.
 *
 * @param uid - The user's UID.
 * @param friendPairId - The canonical friend pair document ID.
 * @throws PERMISSION_DENIED if the user is not part of the friend pair.
 */
export async function requireFriendPairMember(
  uid: string,
  friendPairId: string
): Promise<void> {
  const pairSnap = await getFirestore()
    .doc(friendDoc(friendPairId))
    .get();

  if (!pairSnap.exists) {
    throw new HttpsError("not-found", "Friend relationship not found.");
  }

  const data = pairSnap.data();
  if (!data || (data.userA !== uid && data.userB !== uid)) {
    throw new HttpsError(
      "permission-denied",
      "Not a member of this friend pair."
    );
  }
}
