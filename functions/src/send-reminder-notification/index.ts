/**
 * FR-SE-09 Send Reminder — Module Index
 *
 * Exports the `sendReminderNotification` HTTPS Callable Cloud
 * Function. Region-pinned to asia-south1 (Mumbai) per SRS section
 * 7.1.
 *
 * @module send-reminder-notification
 */

import {onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import {createSendReminderHandler} from "./function";

const REGION = "asia-south1";

/**
 * HTTPS Callable Cloud Function that sends a reminder push
 * notification to a friend who owes the caller money.
 *
 * Input: `SendReminderInput` — `{ toUserId, contextType, contextId,
 *   message? }`.
 *
 * Output: `SendReminderResponse` — `{ success: true, nextAllowedAtIso }`.
 *
 * Error codes: UNAUTHENTICATED, INVALID_INPUT, NOT_A_MEMBER,
 *   RECIPIENT_DOESNT_OWE, RATE_LIMITED, RECIPIENT_PREFS_DISABLED,
 *   RECIPIENT_NO_TOKENS, FCM_DISPATCH_FAILED,
 *   GROUP_CONTEXT_NOT_SUPPORTED, INTERNAL.
 */
export const sendReminderNotification = onCall(
  {region: REGION},
  async (request) => {
    const handler = createSendReminderHandler({
      db: getFirestore(),
      logger,
      messaging: getMessaging(),
      // sendFcm defaults to sendFcmToTokens from ../notifications/fcm-send
      now: () => new Date(),
    });
    return handler(request.data, {
      auth: request.auth ? {uid: request.auth.uid} : undefined,
    });
  },
);
