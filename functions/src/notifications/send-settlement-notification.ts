/**
 * Trigger-facing dispatcher for settlement-related FCM notifications
 * (FR-AC-03).
 *
 * Mirrors `send-expense-notification.ts` but with a SINGLE recipient
 * (`toUserId` — the payee). The payer (`fromUserId`) is the actor
 * and is NOT notified of their own action per
 * `docs/design/07-technical/notifications.md` §2.2.
 *
 * Like the expense dispatcher, this helper:
 *
 *   1. Reads `users/{toUserId}` once.
 *   2. Runs the prefs-filter (gated by the `settlement` flag).
 *   3. Renders the `settlement_received` payload.
 *   4. Calls `sendFcmToTokens` if the token list is non-empty.
 *   5. Logs the skip / suppress branches.
 *
 * The helper does NOT throw — the trigger-side emitter
 * (`emitSettlementFcm`) wraps a try/catch around the entire
 * invocation so trigger success is preserved (FR-AC-03 AC-17).
 *
 * @module notifications/send-settlement-notification
 */

import {hashId} from "../utils/id-hash";
import {renderPayload} from "./payload-renderer";
import {isNotificationAllowed} from "./prefs-filter";
import {sendFcmToTokens} from "./fcm-send";
import type {
  NotificationDispatchResult,
  NotificationsDependencies,
  RecipientPrefs,
  SendSettlementNotificationParams,
} from "./types";

/**
 * Dispatches a settlement-received notification to the payee.
 *
 * @param deps - DI dependencies (db, messaging, logger).
 * @param params - Settlement parameters; only `toUserId` is used as
 *   recipient (the payer `fromUserId` is NOT notified).
 * @returns Dispatch result with counts ≤ 1.
 */
export async function sendSettlementNotification(
  deps: NotificationsDependencies,
  params: SendSettlementNotificationParams,
): Promise<NotificationDispatchResult> {
  const {db, logger} = deps;
  const {
    toUserId,
    contextType,
    contextId,
    settlementId,
    senderName,
    amountPaise,
    eventTimestamp,
  } = params;

  const notificationType = "settlement_received" as const;
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
    itemId: settlementId,
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
