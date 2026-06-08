/**
 * Trigger-facing dispatcher for expense-related FCM notifications
 * (FR-AC-03).
 *
 * Per `docs/design/07-technical/notifications.md` and FR-AC-03 §2.7,
 * this helper:
 *
 *   1. Iterates the recipient list `memberIds \ {authorUid}` (the
 *      author never receives a notification for their own write).
 *   2. For each recipient: reads `users/{uid}` once; runs the
 *      prefs-filter; renders the per-type payload; calls
 *      `sendFcmToTokens` if the token list is non-empty.
 *   3. Logs the per-recipient skip / suppress branches for diagnosability
 *      via the structured-log contract (AC-14).
 *
 * The helper does NOT throw on per-recipient failures — the dispatch
 * loop continues for the remaining recipients. The trigger-side
 * emitter (`emitExpenseFcm`) wraps a try/catch around the entire
 * invocation so the trigger's success branch is preserved even if
 * something goes wrong here (FR-AC-03 AC-17 "errors contained").
 *
 * @module notifications/send-expense-notification
 */

import {hashId} from "../utils/id-hash";
import {renderPayload} from "./payload-renderer";
import {isNotificationAllowed} from "./prefs-filter";
import {sendFcmToTokens} from "./fcm-send";
import type {
  NotificationDispatchResult,
  NotificationsDependencies,
  NotificationType,
  RecipientPrefs,
  SendExpenseNotificationParams,
} from "./types";

/**
 * Dispatches an expense notification to all non-author members of a
 * context (friendship or group). Each member receives at most one
 * FCM message per device (`fcmTokens` entry).
 *
 * @param deps - DI dependencies (db, messaging, logger).
 * @param params - Trigger-side parameters (memberIds, authorUid,
 *   senderName, description, amountPaise, changeType, etc).
 * @returns Aggregated dispatch result across all recipients.
 */
export async function sendExpenseNotification(
  deps: NotificationsDependencies,
  params: SendExpenseNotificationParams,
): Promise<NotificationDispatchResult> {
  const {db, logger} = deps;
  const {
    authorUid,
    memberIds,
    contextType,
    contextId,
    expenseId,
    senderName,
    description,
    amountPaise,
    eventTimestamp,
    changeType,
  } = params;

  // Map changeType → NotificationType discriminator.
  const notificationType: NotificationType =
    changeType === "create" ? "expense_added" :
      changeType === "update" ? "expense_edited" :
        "expense_deleted";

  // Exclude the author — they never receive a push for their own write.
  const recipients = memberIds.filter((uid) => uid !== authorUid);

  // Aggregated counters; reduced from per-recipient results.
  const totals: NotificationDispatchResult = {
    succeeded: 0,
    failed: 0,
    pruned: [],
    suppressedByPrefs: 0,
    skippedEmptyTokens: 0,
    skippedMissingUser: 0,
  };

  // Per-recipient fan-out. We iterate sequentially over the recipient
  // user-doc reads for predictable resource use; the actual FCM sends
  // are parallelised inside `sendFcmToTokens` via Promise.allSettled.
  // For small recipient counts (friendships have 2; groups will have
  // ~5-20), the cost of sequential per-recipient reads is negligible
  // versus the latency budget for a Firestore trigger.
  for (const uid of recipients) {
    const userIdHash = hashId(uid);

    let userSnap: FirebaseFirestore.DocumentSnapshot;
    try {
      userSnap = await db.collection("users").doc(uid).get();
    } catch (err) {
      logger.warn("fcm_send_user_read_failed", {
        event: "fcm_send_user_read_failed",
        userIdHash,
        notificationType,
        errorMessage: err instanceof Error ? err.message : String(err),
      });
      continue;
    }

    if (!userSnap.exists) {
      logger.info("fcm_send_skipped_missing_user", {
        event: "fcm_send_skipped_missing_user",
        userIdHash,
        notificationType,
      });
      totals.skippedMissingUser += 1;
      continue;
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
      continue;
    }

    if (tokens.length === 0) {
      logger.info("fcm_send_skipped_empty_tokens", {
        event: "fcm_send_skipped_empty_tokens",
        userIdHash,
        notificationType,
      });
      totals.skippedEmptyTokens += 1;
      continue;
    }

    const payload = renderPayload(notificationType, {
      senderName,
      description,
      amountPaise,
      contextType,
      contextId,
      itemId: expenseId,
      createdAt: eventTimestamp,
    });

    const sendResult = await sendFcmToTokens(deps, {
      userId: uid,
      notificationType,
      tokens,
      payload,
    });

    totals.succeeded += sendResult.succeeded;
    totals.failed += sendResult.failed;
    totals.pruned = totals.pruned.concat(sendResult.pruned);
  }

  return totals;
}
