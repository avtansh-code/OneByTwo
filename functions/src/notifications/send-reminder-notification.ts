/**
 * Callable-facing dispatcher for FR-SE-09 reminder FCM notifications.
 *
 * Mirrors `send-settlement-notification.ts` with a SINGLE recipient
 * (`toUserId` — the friend who owes the sender). The sender
 * (`fromUserId`) is the actor and is NOT notified.
 *
 * The helper composes:
 *
 *   1. Reads `users/{toUserId}` once.
 *   2. Runs the prefs-filter (gated by the `reminder` flag).
 *   3. Empty-tokens short-circuit.
 *   4. Renders the `reminder` payload.
 *   5. Calls `sendFcmToTokens` if the token list is non-empty.
 *
 * Unlike the trigger-side callers, the FR-SE-09 callable WANTS to
 * distinguish "prefs disabled" from "no tokens" from "delivery
 * failed" — so this helper returns the `NotificationDispatchResult`
 * tally unchanged and the caller maps it to its typed `HttpsError`
 * codes itself (see `functions/src/send-reminder-notification/function.ts`).
 *
 * The helper does NOT throw on dispatch failure; the caller decides
 * the policy.
 *
 * @module notifications/send-reminder-notification
 */

import {hashId} from "../utils/id-hash";
import {renderPayload} from "./payload-renderer";
import {isNotificationAllowed} from "./prefs-filter";
import {sendFcmToTokens} from "./fcm-send";
import type {
  NotificationDispatchResult,
  NotificationsDependencies,
  RecipientPrefs,
  SendReminderNotificationParams,
} from "./types";

/**
 * Dispatches a reminder notification to the recipient (toUserId).
 *
 * @param deps - DI dependencies (db, messaging, logger).
 * @param params - Reminder parameters; only `toUserId` is used as
 *   recipient (the sender `fromUserId` is NOT notified).
 * @returns Dispatch result with counts ≤ token-count.
 */
export async function sendReminderNotification(
  deps: NotificationsDependencies,
  params: SendReminderNotificationParams,
): Promise<NotificationDispatchResult> {
  const {db, logger} = deps;
  const {
    toUserId,
    contextType,
    contextId,
    senderName,
    amountPaise,
    eventTimestamp,
  } = params;

  const notificationType = "reminder" as const;
  const userIdHash = hashId(toUserId);

  const totals: NotificationDispatchResult = {
    succeeded: 0,
    failed: 0,
    pruned: [],
    suppressedByPrefs: 0,
    skippedEmptyTokens: 0,
    skippedMissingUser: 0,
  };

  let userSnap: FirebaseFirestore.DocumentSnapshot;
  try {
    userSnap = await db.collection("users").doc(toUserId).get();
  } catch (err) {
    logger.warn("fcm_send_user_read_failed", {
      event: "fcm_send_user_read_failed",
      userIdHash,
      notificationType,
      errorMessage: err instanceof Error ? err.message : String(err),
    });
    return totals;
  }

  if (!userSnap.exists) {
    logger.info("fcm_send_skipped_missing_user", {
      event: "fcm_send_skipped_missing_user",
      userIdHash,
      notificationType,
    });
    totals.skippedMissingUser += 1;
    return totals;
  }

  const userData = userSnap.data() as Record<string, unknown> | undefined;
  const prefs = userData?.notificationPrefs as RecipientPrefs | undefined;
  const tokens = (userData?.fcmTokens as string[] | undefined) ?? [];

  if (!isNotificationAllowed(notificationType, prefs)) {
    logger.info("fcm_send_suppressed_by_prefs", {
      event: "fcm_send_suppressed_by_prefs",
      userIdHash,
      notificationType,
    });
    totals.suppressedByPrefs += 1;
    return totals;
  }

  if (tokens.length === 0) {
    logger.info("fcm_send_skipped_empty_tokens", {
      event: "fcm_send_skipped_empty_tokens",
      userIdHash,
      notificationType,
    });
    totals.skippedEmptyTokens += 1;
    return totals;
  }

  const payload = renderPayload(notificationType, {
    senderName,
    amountPaise,
    contextType,
    contextId,
    createdAt: eventTimestamp,
  });

  const sendResult = await sendFcmToTokens(deps, {
    userId: toUserId,
    notificationType,
    tokens,
    payload,
  });

  totals.succeeded += sendResult.succeeded;
  totals.failed += sendResult.failed;
  totals.pruned = totals.pruned.concat(sendResult.pruned);
  return totals;
}
