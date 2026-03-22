/**
 * FCM notification helpers.
 *
 * Provides fan-out notification delivery to group members or
 * individual users, with automatic cleanup of stale FCM tokens.
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { groupMembersCol, userDoc } from "./firestore_paths";

interface NotificationPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

/**
 * Sends a push notification to all active members of a group,
 * excluding the actor who triggered the event.
 *
 * @param groupId - The group to notify.
 * @param excludeUserId - The user to exclude (typically the actor).
 * @param notification - The notification content.
 */
export async function notifyGroupMembers(
  groupId: string,
  excludeUserId: string,
  notification: NotificationPayload
): Promise<void> {
  const db = getFirestore();

  // 1. Get all active group members
  const membersSnap = await db.collection(groupMembersCol(groupId)).get();

  const memberIds = membersSnap.docs
    .filter((doc) => {
      const data = doc.data();
      return doc.id !== excludeUserId && data.isActive !== false;
    })
    .map((doc) => doc.id);

  if (memberIds.length === 0) return;

  await sendToUsers(memberIds, notification);
}

/**
 * Sends a push notification to a single user.
 *
 * @param userId - The target user's UID.
 * @param notification - The notification content.
 */
export async function notifyUser(
  userId: string,
  notification: NotificationPayload
): Promise<void> {
  await sendToUsers([userId], notification);
}

/**
 * Sends a push notification to a list of users, checking their
 * notification preferences and cleaning up stale FCM tokens.
 */
async function sendToUsers(
  userIds: string[],
  notification: NotificationPayload
): Promise<void> {
  const db = getFirestore();

  // Batch-fetch all user documents in a single call
  const docRefs = userIds.map((userId) => db.doc(userDoc(userId)));
  const userSnaps = await db.getAll(...docRefs);

  // Collect FCM tokens from users who have notifications enabled
  const tokensByUser = new Map<string, string[]>();
  const allTokens: string[] = [];

  for (let i = 0; i < userIds.length; i++) {
    const userSnap = userSnaps[i];
    if (!userSnap.exists) continue;

    const userData = userSnap.data();
    if (!userData) continue;

    // Check notification preferences
    const prefs = userData.notificationPrefs;
    if (prefs && prefs.expenses === false && prefs.settlements === false) {
      continue;
    }

    const tokens: string[] = userData.fcmTokens ?? [];
    if (tokens.length > 0) {
      tokensByUser.set(userIds[i], tokens);
      allTokens.push(...tokens);
    }
  }

  if (allTokens.length === 0) return;

  // Send multicast notification
  const response = await getMessaging().sendEachForMulticast({
    tokens: allTokens,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: notification.data,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });

  // Collect stale tokens
  const staleTokens = new Set<string>();
  response.responses.forEach((resp, idx) => {
    if (
      resp.error?.code === "messaging/registration-token-not-registered" ||
      resp.error?.code === "messaging/invalid-registration-token"
    ) {
      staleTokens.add(allTokens[idx]);
    }
  });

  // Remove stale tokens from user documents using a batch write
  if (staleTokens.size > 0) {
    const batch = db.batch();
    let hasBatchOps = false;

    for (const [userId, tokens] of tokensByUser.entries()) {
      const staleForUser = tokens.filter((t) => staleTokens.has(t));
      if (staleForUser.length > 0) {
        batch.update(db.doc(userDoc(userId)), {
          fcmTokens: FieldValue.arrayRemove(...staleForUser),
        });
        hasBatchOps = true;
      }
    }

    if (hasBatchOps) {
      await batch.commit();
    }
  }
}
