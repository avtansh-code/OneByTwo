/**
 * Admin-SDK FCM send helper (FR-AC-03 / notifications.md §1.4).
 *
 * Dispatches a `NotificationPayload` to one or more FCM tokens for a
 * single recipient. Per-token sends run in parallel via
 * `Promise.allSettled`; on a `messaging/registration-token-not-registered`
 * (HTTP 410) error, the token is pruned from
 * `users/{uid}.fcmTokens` via `FieldValue.arrayRemove`.
 *
 * Structured-log contract (FR-AC-03 AC-14):
 *
 *   - `fcm_send_attempted` (info) — once before the parallel sends;
 *     `{userIdHash, notificationType, tokenCount}`.
 *   - `fcm_send_succeeded`  (info) — per successful send;
 *     `{userIdHash, notificationType, tokenFingerprint}`.
 *   - `fcm_send_failed`     (error) — per non-410 failure;
 *     `{userIdHash, notificationType, tokenFingerprint, errorCode}`.
 *   - `fcm_token_pruned`    (info) — per 410 cleanup;
 *     `{userIdHash, notificationType, tokenFingerprint}`.
 *
 * PII guard (architect §2.10 item 8):
 *
 *   - `userId` is hashed through `hashId()` (16 hex chars) before any
 *     log call.
 *   - Raw FCM tokens are NEVER logged; only the 8-char SHA-256
 *     fingerprint from `fingerprintToken()` appears in structured
 *     logs. Note that FCM tokens are NOT subject to ADR-0013
 *     `hashId()` wrapping (they are not UIDs), but they are still
 *     opaque platform credentials we minimise in logs by policy.
 *
 * @module notifications/fcm-send
 */

import {createHash} from "crypto";
import {FieldValue} from "firebase-admin/firestore";
import {hashId} from "../utils/id-hash";
import type {NotificationPayload, NotificationType} from "./types";
import type {NotificationsDependencies} from "./types";

/**
 * Per-call parameters for `sendFcmToTokens`. The `userId` is required
 * for the cleanup branch (the 410-token-arrayRemove targets
 * `users/{userId}`) and for the structured-log `userIdHash`.
 */
export interface SendFcmParams {
  userId: string;
  notificationType: NotificationType;
  tokens: readonly string[];
  payload: NotificationPayload;
}

/**
 * Aggregated result. `pruned` lists the raw tokens that were removed
 * from the user's `fcmTokens` array — the trigger does not log these
 * itself (the cleanup-log is emitted inside this helper).
 */
export interface SendFcmResult {
  succeeded: number;
  failed: number;
  pruned: string[];
}

/**
 * FCM error code returned by the admin SDK when a token is no longer
 * registered with the FCM service. Matches both the canonical
 * `messaging/registration-token-not-registered` form returned by the
 * Firebase Admin Node SDK and the bare `registration-token-not-registered`
 * form some adapters emit (defence-in-depth).
 */
const FCM_NOT_REGISTERED_CODES = new Set<string>([
  "messaging/registration-token-not-registered",
  "registration-token-not-registered",
]);

/**
 * Returns the first 8 hex characters of SHA-256(token). Used purely
 * for log diagnosability so that two distinct token-related events
 * for the same physical token can be correlated WITHOUT exposing the
 * raw credential.
 *
 * 8 hex chars ≈ 32 bits of entropy; collision probability across the
 * tokens of a single user is negligible. We accept the (cryptographically
 * irrelevant) possibility of intra-user collisions.
 *
 * @param token - The raw FCM token.
 * @returns 8-character lowercase hex string.
 */
export function fingerprintToken(token: string): string {
  return createHash("sha256").update(token).digest("hex").slice(0, 8);
}

/**
 * Sends a `NotificationPayload` to each token in `params.tokens`,
 * pruning 410-failed tokens and emitting the structured-log contract.
 *
 * @param deps - DI dependencies (db for the 410 cleanup, messaging
 *   for the admin SDK, logger for structured events).
 * @param params - Recipient userId, notification type discriminator,
 *   tokens to dispatch to, and the rendered payload.
 * @returns Aggregated counts of successes, failures, and pruned tokens.
 */
export async function sendFcmToTokens(
  deps: NotificationsDependencies,
  params: SendFcmParams,
): Promise<SendFcmResult> {
  const {db, messaging, logger} = deps;
  const {userId, notificationType, tokens, payload} = params;

  // Empty tokens array → silent no-op. No admin-SDK call, no log
  // (the caller will have already logged the per-recipient context).
  if (tokens.length === 0) {
    return {succeeded: 0, failed: 0, pruned: []};
  }

  const userIdHash = hashId(userId);

  logger.info("fcm_send_attempted", {
    event: "fcm_send_attempted",
    userIdHash,
    notificationType,
    tokenCount: tokens.length,
  });

  // Build the FCM `Message` envelope per notifications.md §2.1. Data-
  // only message (no top-level `notification` block) so clients have
  // full control over presentation. High-priority on both platforms
  // so messages wake the device for time-sensitive notifications
  // (FR-AC-03 latency target).
  const data: Record<string, string> = {
    type: payload.type,
    contextType: payload.contextType,
    contextId: payload.contextId,
    title: payload.title,
    body: payload.body,
    senderName: payload.senderName,
    createdAt: payload.createdAt,
  };
  if (payload.itemId !== undefined) data.itemId = payload.itemId;
  if (payload.amountPaise !== undefined) data.amountPaise = payload.amountPaise;
  if (payload.inviteToken !== undefined) {
    data.inviteToken = payload.inviteToken;
  }

  // Parallel dispatch — one `send()` call per token. The admin SDK's
  // `sendMulticast` is deprecated; per-token `send()` is the
  // recommended pattern (see Firebase docs at /docs/cloud-messaging/
  // send-message). `Promise.allSettled` gathers the per-token
  // outcomes so a single 410 doesn't short-circuit the others.
  const sends = tokens.map((token) => {
    const message = {
      token,
      data,
      android: {priority: "high" as const},
      apns: {
        headers: {"apns-priority": "10"},
        payload: {aps: {"content-available": 1}},
      },
    };
    return messaging.send(message);
  });

  const settled = await Promise.allSettled(sends);

  const pruned: string[] = [];
  let succeeded = 0;
  let failed = 0;

  // Per-token result handling. We do the prune updates SEQUENTIALLY
  // within the loop body to keep the test's `expect(updateFn).toHaveBeenCalledTimes(1)`
  // semantics deterministic; in the multi-prune case the cost is
  // O(prunedTokens) round-trips, which is acceptable for the rare
  // 410 cleanup branch.
  for (let i = 0; i < settled.length; i++) {
    const outcome = settled[i];
    const token = tokens[i];
    const tokenFingerprint = fingerprintToken(token);

    if (outcome.status === "fulfilled") {
      succeeded += 1;
      logger.info("fcm_send_succeeded", {
        event: "fcm_send_succeeded",
        userIdHash,
        notificationType,
        tokenFingerprint,
      });
      continue;
    }

    failed += 1;
    const err = outcome.reason as Error & {code?: string};
    const errorCode = err?.code ?? "unknown";

    if (FCM_NOT_REGISTERED_CODES.has(errorCode)) {
      // HTTP 410 → token is dead. Remove it from the user's fcmTokens
      // array and log a structured prune event.
      try {
        await db.collection("users").doc(userId).update({
          fcmTokens: FieldValue.arrayRemove(token),
        });
        pruned.push(token);
        logger.info("fcm_token_pruned", {
          event: "fcm_token_pruned",
          userIdHash,
          notificationType,
          tokenFingerprint,
        });
      } catch (cleanupErr) {
        // The prune itself failed (e.g. Firestore unreachable).
        // Surface as a non-fatal warn — the next dispatch attempt
        // will see the same dead token and retry the cleanup.
        logger.warn("fcm_token_prune_failed", {
          event: "fcm_token_prune_failed",
          userIdHash,
          notificationType,
          tokenFingerprint,
          errorMessage:
            cleanupErr instanceof Error ? cleanupErr.message : String(cleanupErr),
        });
      }
      continue;
    }

    // Non-410 error (network, quota, invalid argument, etc.) — log
    // but do NOT prune. The same token will be retried on the next
    // dispatch; transient errors should self-heal.
    logger.error("fcm_send_failed", {
      event: "fcm_send_failed",
      userIdHash,
      notificationType,
      tokenFingerprint,
      errorCode,
    });
  }

  return {succeeded, failed, pruned};
}
