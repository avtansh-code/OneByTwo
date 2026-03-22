/**
 * Firestore trigger: onUserCreated
 *
 * Fires when a new user document is created at `users/{uid}`.
 * Initializes supporting collections and sends a welcome notification.
 *
 * Actions (atomic via batched write):
 *   1. Create metadata doc at `userGroups/{uid}`
 *   2. Create metadata doc at `userFriends/{uid}`
 *   3. Create welcome notification at `users/{uid}/notifications/{auto-id}`
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { TRIGGER_OPTIONS } from "../config";
import {
  userGroupsMetaDoc,
  userFriendsMetaDoc,
  userNotificationsCol,
} from "../utils/firestore_paths";

/** Localized welcome notification messages keyed by language code. */
const WELCOME_MESSAGES: Record<string, { title: string; body: string }> = {
  en: {
    title: "Welcome to One By Two!",
    body: "Start splitting expenses with friends and groups.",
  },
  hi: {
    title: "वन बाय टू में आपका स्वागत है!",
    body: "दोस्तों और ग्रुप के साथ खर्चे बाँटना शुरू करें।",
  },
};

/**
 * Initializes Firestore documents for a newly created user.
 *
 * Performs the following atomically via a batched write:
 *   1. Creates a metadata document in `userGroups/{uid}`
 *   2. Creates a metadata document in `userFriends/{uid}`
 *   3. Creates a welcome notification in `users/{uid}/notifications`
 *
 * @param uid – Firebase Auth UID of the new user.
 * @param language – ISO 639-1 language code from the user document
 *                   (defaults to `"en"` when not provided).
 *
 * Exported separately so the batch logic can be unit-tested
 * without spinning up a Firestore emulator.
 */
export async function initializeNewUser(
  uid: string,
  language: string = "en",
): Promise<void> {
  const db = getFirestore();
  const batch = db.batch();

  // 1. Initialize userGroups metadata document
  batch.set(db.doc(userGroupsMetaDoc(uid)), {
    userId: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  // 2. Initialize userFriends metadata document
  batch.set(db.doc(userFriendsMetaDoc(uid)), {
    userId: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  // 3. Create welcome notification
  const messages = WELCOME_MESSAGES[language] || WELCOME_MESSAGES["en"];
  const notificationRef = db.collection(userNotificationsCol(uid)).doc();
  batch.set(notificationRef, {
    type: "welcome",
    title: messages.title,
    body: messages.body,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();
}

/**
 * Cloud Function trigger that fires when a new user document is created.
 */
export const onUserCreated = onDocumentCreated(
  { document: "users/{uid}", ...TRIGGER_OPTIONS },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error("onUserCreated: No data in event.");
      return;
    }

    const uid = event.params.uid;
    const userData = snapshot.data();
    const language = (userData?.language as string) || "en";

    try {
      await initializeNewUser(uid, language);
      logger.info(`onUserCreated: Successfully initialized user ${uid}.`);
    } catch (error) {
      // Do not re-throw: trigger retries on unhandled errors,
      // but business-logic failures should not be retried.
      logger.error(
        `onUserCreated: Failed to initialize user ${uid}.`,
        { error }
      );
    }
  }
);
