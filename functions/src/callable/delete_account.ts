/**
 * Cloud Function: deleteUserAccount
 *
 * GDPR-compliant account deletion (Article 17 - Right to Erasure)
 *
 * This function:
 * - Authenticates the caller
 * - Deletes ALL user data from Firestore
 * - Removes user from group memberships
 * - Soft-deletes user's expenses and settlements (marks is_deleted)
 * - Deletes Cloud Storage files (avatar)
 * - Deletes Firebase Auth account
 *
 * Security: Authenticated users can only delete their own account
 * Region: asia-south1
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

interface DeleteAccountResponse {
  success: boolean;
  message: string;
}

export const deleteUserAccount = onCall<void, Promise<DeleteAccountResponse>>(
  {
    region: "asia-south1",
    enforceAppCheck: false, // TODO: Enable in production
  },
  async (request) => {
    const TAG = "CF.DeleteAccount";

    // 1. Verify authentication
    if (!request.auth) {
      logger.error(`[${TAG}] Unauthenticated request`);
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to delete account"
      );
    }

    const uid = request.auth.uid;
    logger.info(`[${TAG}] Account deletion requested`, {uid});

    try {
      // 2. Delete user data from Firestore in batches
      await deleteUserFirestoreData(uid);

      // 3. Delete user's avatar from Cloud Storage
      await deleteUserStorage(uid);

      // 4. Delete Firebase Auth account
      await auth.deleteUser(uid);
      logger.info(`[${TAG}] Firebase Auth account deleted`, {uid});

      logger.info(`[${TAG}] Account deletion completed successfully`, {uid});

      return {
        success: true,
        message: "Account deleted successfully",
      };
    } catch (error) {
      logger.error(
        `[${TAG}] Account deletion failed`,
        {uid, error: String(error)}
      );

      // If it's already an HttpsError, rethrow it
      if (error instanceof HttpsError) {
        throw error;
      }

      // Otherwise wrap in internal error
      throw new HttpsError(
        "internal",
        "Failed to delete account. Please try again.",
        {error: String(error)}
      );
    }
  }
);

/**
 * Delete all user data from Firestore
 * Uses batch writes for atomicity (500 operations per batch)
 * @param {string} uid - User ID
 * @return {Promise<void>}
 */
async function deleteUserFirestoreData(uid: string): Promise<void> {
  const TAG = "CF.DeleteAccount.Firestore";
  logger.info(`[${TAG}] Deleting Firestore data`, {uid});

  // Use batched deletes to handle large amounts of data
  let batch = db.batch();
  let batchCount = 0;

  // 1. Delete user document
  const userRef = db.collection("users").doc(uid);
  batch.delete(userRef);
  batchCount++;
  logger.info(`[${TAG}] Marked user document for deletion`, {uid});

  // 2. Delete all documents in userGroups subcollection
  const userGroupsSnapshot = await db
    .collection("userGroups")
    .doc(uid)
    .collection("groups")
    .get();

  for (const doc of userGroupsSnapshot.docs) {
    batch.delete(doc.ref);
    batchCount++;

    // Commit batch if it reaches 500 operations
    if (batchCount >= 500) {
      await batch.commit();
      logger.info(`[${TAG}] Batch committed`, {uid, count: batchCount});
      batch = db.batch();
      batchCount = 0;
    }
  }
  logger.info(`[${TAG}] Marked userGroups for deletion`, {
    uid,
    count: userGroupsSnapshot.size,
  });

  // 3. Delete all documents in userFriends subcollection
  const userFriendsSnapshot = await db
    .collection("userFriends")
    .doc(uid)
    .collection("friends")
    .get();

  for (const doc of userFriendsSnapshot.docs) {
    batch.delete(doc.ref);
    batchCount++;

    if (batchCount >= 500) {
      await batch.commit();
      logger.info(`[${TAG}] Batch committed`, {uid, count: batchCount});
      batch = db.batch();
      batchCount = 0;
    }
  }
  logger.info(`[${TAG}] Marked userFriends for deletion`, {
    uid,
    count: userFriendsSnapshot.size,
  });

  // 4. Remove user from all group member subcollections
  await removeUserFromGroups(uid, batch, batchCount);

  // 5. Soft-delete user's expenses (mark is_deleted = true)
  // This preserves group integrity while removing PII
  await softDeleteUserExpenses(uid);

  // 6. Soft-delete user's settlements
  await softDeleteUserSettlements(uid);

  // Commit any remaining operations in the batch
  if (batchCount > 0) {
    await batch.commit();
    logger.info(`[${TAG}] Final batch committed`, {uid, count: batchCount});
  }

  logger.info(`[${TAG}] Firestore data deletion completed`, {uid});
}

/**
 * Remove user from all groups they belong to
 * @param {string} uid - User ID
 * @param {admin.firestore.WriteBatch} batch - Firestore batch
 * @param {number} batchCount - Current batch operation count
 * @return {Promise<void>}
 */
async function removeUserFromGroups(
  uid: string,
  batch: admin.firestore.WriteBatch,
  batchCount: number
): Promise<void> {
  const TAG = "CF.DeleteAccount.Groups";

  // Find all groups where user is a member
  const userGroupsSnapshot = await db
    .collection("userGroups")
    .doc(uid)
    .collection("groups")
    .get();

  for (const userGroupDoc of userGroupsSnapshot.docs) {
    const groupId = userGroupDoc.id;

    // Remove user from group's members subcollection
    const memberRef = db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .doc(uid);

    batch.delete(memberRef);
    batchCount++;

    // Note: We DON'T delete the group itself, even if user is the owner
    // Group expenses/settlements are kept for historical accuracy
    // Other members can still see the data with "Deleted User" placeholder

    if (batchCount >= 500) {
      await batch.commit();
      logger.info(`[${TAG}] Batch committed during group removal`, {
        uid,
        count: batchCount,
      });
      batch = db.batch();
      batchCount = 0;
    }
  }

  logger.info(`[${TAG}] User removed from groups`, {
    uid,
    count: userGroupsSnapshot.size,
  });
}

/**
 * Soft-delete user's expenses across all contexts
 * Marks is_deleted = true and removes PII (description anonymized)
 * @param {string} uid - User ID
 * @return {Promise<void>}
 */
async function softDeleteUserExpenses(uid: string): Promise<void> {
  const TAG = "CF.DeleteAccount.Expenses";

  // Query expenses where user is the payer
  // Note: In production, this should use a composite index on payer_id
  const expensesSnapshot = await db
    .collection("expenses")
    .where("payer_id", "==", uid)
    .get();

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of expensesSnapshot.docs) {
    batch.update(doc.ref, {
      is_deleted: true,
      deleted_at: admin.firestore.FieldValue.serverTimestamp(),
      description: "[Deleted]",
    });
    batchCount++;

    if (batchCount >= 500) {
      await batch.commit();
      logger.info(`[${TAG}] Batch committed`, {uid, count: batchCount});
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  logger.info(`[${TAG}] Expenses soft-deleted`, {
    uid,
    count: expensesSnapshot.size,
  });
}

/**
 * Soft-delete user's settlements
 * @param {string} uid - User ID
 * @return {Promise<void>}
 */
async function softDeleteUserSettlements(uid: string): Promise<void> {
  const TAG = "CF.DeleteAccount.Settlements";

  // Query settlements where user is the payer
  const payerSettlementsSnapshot = await db
    .collection("settlements")
    .where("payer_id", "==", uid)
    .get();

  // Query settlements where user is the receiver
  const receiverSettlementsSnapshot = await db
    .collection("settlements")
    .where("receiver_id", "==", uid)
    .get();

  let batch = db.batch();
  let batchCount = 0;

  // Mark all settlements as deleted
  for (const doc of payerSettlementsSnapshot.docs) {
    batch.update(doc.ref, {
      is_deleted: true,
      deleted_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    batchCount++;

    if (batchCount >= 500) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  for (const doc of receiverSettlementsSnapshot.docs) {
    batch.update(doc.ref, {
      is_deleted: true,
      deleted_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    batchCount++;

    if (batchCount >= 500) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  logger.info(`[${TAG}] Settlements soft-deleted`, {
    uid,
    payerCount: payerSettlementsSnapshot.size,
    receiverCount: receiverSettlementsSnapshot.size,
  });
}

/**
 * Delete user's files from Cloud Storage
 * @param {string} uid - User ID
 * @return {Promise<void>}
 */
async function deleteUserStorage(uid: string): Promise<void> {
  const TAG = "CF.DeleteAccount.Storage";

  try {
    const bucket = storage.bucket();

    // Delete avatar if exists
    const avatarPath = `users/${uid}/avatar.jpg`;
    await bucket.file(avatarPath).delete({ignoreNotFound: true});
    logger.info(`[${TAG}] Avatar deleted`, {uid});

    // Delete any other user files in the user's directory
    const [files] = await bucket.getFiles({prefix: `users/${uid}/`});
    for (const file of files) {
      await file.delete({ignoreNotFound: true});
    }

    logger.info(`[${TAG}] Storage files deleted`, {
      uid,
      count: files.length,
    });
  } catch (error) {
    // Storage deletion is not critical - log but don't fail
    logger.warn(`[${TAG}] Failed to delete storage files`, {
      uid,
      error: String(error),
    });
  }
}
