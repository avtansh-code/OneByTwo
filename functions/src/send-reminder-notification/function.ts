/**
 * FR-SE-09 Send Reminder — Callable Handler Boundary.
 *
 * HTTPS Callable that allows an authenticated user to send a reminder
 * push notification to a friend who owes them money, rate-limited to
 * one reminder per friend per 24 hours (SRS §4.6).
 *
 * Handler flow:
 *
 *   1. Auth check (UNAUTHENTICATED).
 *   2. Input validation (INVALID_INPUT).
 *   3. Group-context forward-compat short-circuit
 *      (GROUP_CONTEXT_NOT_SUPPORTED).
 *   4. Friendship doc read + membership check (NOT_A_MEMBER).
 *   5. simplifiedBalances precondition: recipient must owe sender
 *      (RECIPIENT_DOESNT_OWE). Invariant 1: amountPaise carried as
 *      int; no inline /100 anywhere.
 *   6. Rate-limit pre-check against
 *      _rateLimits/{senderUid}/sends/{recipientUid}
 *      (RATE_LIMITED with nextAllowedAtIso).
 *   7. Recipient user-doc read for displayName + prefs gate
 *      (RECIPIENT_PREFS_DISABLED) + token presence check
 *      (RECIPIENT_NO_TOKENS).
 *   8. Sender displayName read (for FCM body string).
 *   9. FCM dispatch via the injected sendReminderFcm helper.
 *  10. Full-failure check (FCM_DISPATCH_FAILED — rate-limit NOT
 *      recorded per architect §2.5).
 *  11. Rate-limit document write (on succeeded >= 1).
 *  12. Activity-feed emission to recipient ONLY (architect §2.3).
 *  13. Return { success: true, nextAllowedAtIso }.
 *
 * Invariant compliance:
 *   - Inv-1 (paise integer): amountPaise read as int from
 *     simplifiedBalances[recipientUid][senderUid], passed unchanged
 *     through the FCM helper to renderPayload('reminder', ...). Zero
 *     /100 arithmetic.
 *   - Inv-2 (simplifiedBalances server-only): the callable READS the
 *     field for the precondition check; ZERO new writers. Rate-limit
 *     and activity writes go to _rateLimits/* and activity/*.
 *
 * Structured-log events (PII-hashed via hashId per ADR-0013):
 *   - reminder_send_attempted
 *   - reminder_send_succeeded
 *   - reminder_send_rate_limited
 *   - reminder_send_skipped_by_prefs
 *   - reminder_send_failed_no_tokens
 *   - reminder_send_recipient_doesnt_owe
 *   - reminder_send_failed
 *
 * Error codes follow docs/design/07-technical/cloud-functions-error-codes.md.
 *
 * @module send-reminder-notification/function
 */

import {HttpsError} from "firebase-functions/v2/https";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {hashId} from "../utils/id-hash";
import {validateActivityPayload} from
  "../triggers/on-expense-write/activity-validator";
import type {ReminderPayload} from
  "../triggers/on-expense-write/payload-builder";
import type {
  NotificationsDependencies,
  NotificationDispatchResult,
  SendReminderNotificationParams,
} from "../notifications/types";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Per-friend 24-hour rate-limit window in milliseconds. */
const REMINDER_WINDOW_MS = 24 * 60 * 60 * 1000;

/** Maximum length of the optional free-text reminder message. */
const REMINDER_MESSAGE_MAX_LENGTH = 500;

/**
 * Default reminder body text (architect §2.5). v1.0 clients always
 * omit the optional `message` field; the server stores this default
 * on the activity-feed item so the recipient sees a friendly note.
 */
const REMINDER_DEFAULT_MESSAGE = "This is a friendly reminder!";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Shape of the input data for the callable. */
export interface SendReminderInput {
  toUserId: string;
  contextType: "friendship" | "group";
  contextId: string;
  message?: string;
}

/** Shape of the successful callable response. */
export interface SendReminderResponse {
  success: true;
  nextAllowedAtIso: string;
}

/**
 * FCM dispatch leaf injected for testability. Production wires to
 * `sendReminderNotification` from `../notifications`; tests inject a
 * jest.fn() that returns a scripted NotificationDispatchResult.
 */
export type SendReminderFcm = (
  deps: NotificationsDependencies,
  params: SendReminderNotificationParams,
) => Promise<NotificationDispatchResult>;

/** Dependencies injected into the handler for testability. */
export interface SendReminderFunctionDeps {
  db: FirebaseFirestore.Firestore;
  logger: {
    info: (message: string, data?: Record<string, unknown>) => void;
    warn: (message: string, data?: Record<string, unknown>) => void;
    error: (message: string, data?: Record<string, unknown>) => void;
  };
  /** FCM dispatch helper from `../notifications`. */
  sendReminderFcm: SendReminderFcm;
  /** Optional Messaging instance — wired in production via the onCall index. */
  messaging?: import("firebase-admin/messaging").Messaging;
  /** Clock injection for deterministic tests. */
  now: () => Date;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface RateLimitDocData {
  lastSentAt: Timestamp | {toMillis(): number};
  count?: number;
  windowStart?: number;
  recipientUid?: string;
  senderUid?: string;
}

function readLastSentMs(data: unknown): number {
  if (data === null || typeof data !== "object") return 0;
  const lastSentAt = (data as RateLimitDocData).lastSentAt as
    | {toMillis?: () => number}
    | undefined;
  if (
    lastSentAt &&
    typeof lastSentAt === "object" &&
    typeof lastSentAt.toMillis === "function"
  ) {
    return lastSentAt.toMillis();
  }
  return 0;
}

function throwInvalidInput(message: string): never {
  throw new HttpsError("invalid-argument", message, {
    errorCode: "INVALID_INPUT",
  });
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.length > 0;
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the HTTPS Callable handler with injected dependencies.
 */
export function createSendReminderHandler(
  deps: SendReminderFunctionDeps,
): (
  data: unknown,
  context: {auth?: {uid: string}},
) => Promise<SendReminderResponse> {
  const {db, logger, sendReminderFcm, messaging, now} = deps;

  return async (
    data: unknown,
    context: {auth?: {uid: string}},
  ): Promise<SendReminderResponse> => {
    // 1. Auth check
    const senderUid = context.auth?.uid;
    if (!senderUid) {
      throw new HttpsError("unauthenticated", "Authentication required.", {
        errorCode: "UNAUTHENTICATED",
      });
    }

    // 2. Input validation
    const obj = (data ?? {}) as Record<string, unknown>;
    const toUserId = obj.toUserId;
    const contextType = obj.contextType;
    const contextId = obj.contextId;
    const messageRaw = obj.message;

    if (!isNonEmptyString(toUserId)) {
      throwInvalidInput("toUserId must be a non-empty string.");
    }
    if (contextType !== "friendship" && contextType !== "group") {
      throwInvalidInput("contextType must be 'friendship' or 'group'.");
    }
    if (!isNonEmptyString(contextId)) {
      throwInvalidInput("contextId must be a non-empty string.");
    }
    let message: string | undefined;
    if (messageRaw !== undefined) {
      if (typeof messageRaw !== "string") {
        throwInvalidInput("message, when present, must be a string.");
      }
      if ((messageRaw as string).length > REMINDER_MESSAGE_MAX_LENGTH) {
        throwInvalidInput(
          `message length must be \u2264 ${REMINDER_MESSAGE_MAX_LENGTH} chars.`,
        );
      }
      message = messageRaw as string;
    }

    const senderUidHash = hashId(senderUid);
    const recipientUidHash = hashId(toUserId as string);
    const contextIdHash = hashId(contextId as string);

    logger.info("reminder_send_attempted", {
      event: "reminder_send_attempted",
      senderUidHash,
      recipientUidHash,
      contextType,
      contextIdHash,
    });

    // 3. Group-context forward-compat short-circuit
    if (contextType === "group") {
      logger.warn("reminder_send_failed", {
        event: "reminder_send_failed",
        senderUidHash,
        recipientUidHash,
        contextType,
        contextIdHash,
        errorCode: "GROUP_CONTEXT_NOT_SUPPORTED",
      });
      throw new HttpsError(
        "unimplemented",
        "Reminders for group contexts are not supported in v1.0.",
        {errorCode: "GROUP_CONTEXT_NOT_SUPPORTED"},
      );
    }

    try {
      // 4. Friendship doc read + membership check
      const friendshipSnap = await db
        .collection("friendships")
        .doc(contextId as string)
        .get();

      if (!friendshipSnap.exists) {
        logger.warn("reminder_send_failed", {
          event: "reminder_send_failed",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
          errorCode: "NOT_A_MEMBER",
        });
        throw new HttpsError(
          "permission-denied",
          "Caller is not a member of the requested context.",
          {errorCode: "NOT_A_MEMBER"},
        );
      }

      const friendshipData = friendshipSnap.data() as
        | Record<string, unknown>
        | undefined;
      const memberIds = (friendshipData?.memberIds as string[] | undefined) ??
        [];
      if (!memberIds.includes(senderUid)) {
        logger.warn("reminder_send_failed", {
          event: "reminder_send_failed",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
          errorCode: "NOT_A_MEMBER",
        });
        throw new HttpsError(
          "permission-denied",
          "Caller is not a member of the requested context.",
          {errorCode: "NOT_A_MEMBER"},
        );
      }

      // 5. simplifiedBalances precondition
      // Shape: { [debtorUid]: { [creditorUid]: paiseAmount } }.
      // Valid IFF simplifiedBalances[recipientUid][senderUid] > 0.
      const simplifiedBalances = (friendshipData?.simplifiedBalances as
        | Record<string, Record<string, number> | undefined>
        | undefined) ?? {};
      const owedRow = simplifiedBalances[toUserId as string];
      const owedPaise = owedRow ? owedRow[senderUid] : undefined;

      if (
        typeof owedPaise !== "number" ||
        !Number.isInteger(owedPaise) ||
        owedPaise <= 0
      ) {
        logger.info("reminder_send_recipient_doesnt_owe", {
          event: "reminder_send_recipient_doesnt_owe",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
        });
        throw new HttpsError(
          "failed-precondition",
          "The recipient does not owe you in this context.",
          {errorCode: "RECIPIENT_DOESNT_OWE"},
        );
      }

      // 6. Rate-limit pre-check
      const rateLimitPath =
        `_rateLimits/${senderUid}/sends/${toUserId as string}`;
      const rateLimitRef = db.doc(rateLimitPath);
      const rateLimitSnap = await rateLimitRef.get();
      const nowDate = now();
      const nowMs = nowDate.getTime();

      if (rateLimitSnap.exists) {
        const rlData = rateLimitSnap.data();
        const lastSentMs = readLastSentMs(rlData);
        if (lastSentMs > 0 && nowMs - lastSentMs < REMINDER_WINDOW_MS) {
          const nextAllowedAtIso = new Date(
            lastSentMs + REMINDER_WINDOW_MS,
          ).toISOString();
          logger.info("reminder_send_rate_limited", {
            event: "reminder_send_rate_limited",
            senderUidHash,
            recipientUidHash,
            contextType,
            contextIdHash,
            nextAllowedAtIso,
          });
          throw new HttpsError(
            "resource-exhausted",
            "You can send another reminder after the cooldown.",
            {errorCode: "RATE_LIMITED", nextAllowedAtIso},
          );
        }
      }

      // 7. Recipient user-doc read
      const recipientSnap = await db
        .collection("users")
        .doc(toUserId as string)
        .get();

      if (!recipientSnap.exists) {
        logger.warn("reminder_send_failed_no_tokens", {
          event: "reminder_send_failed_no_tokens",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
        });
        throw new HttpsError(
          "failed-precondition",
          "Recipient has not enabled push notifications.",
          {errorCode: "RECIPIENT_NO_TOKENS"},
        );
      }

      const recipientData = recipientSnap.data() as
        | Record<string, unknown>
        | undefined;
      const prefs = (recipientData?.notificationPrefs as
        | Record<string, boolean | undefined>
        | undefined);
      const reminderAllowed = prefs?.reminder !== false;
      if (!reminderAllowed) {
        logger.info("reminder_send_skipped_by_prefs", {
          event: "reminder_send_skipped_by_prefs",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
        });
        throw new HttpsError(
          "failed-precondition",
          "Recipient has notifications turned off.",
          {errorCode: "RECIPIENT_PREFS_DISABLED"},
        );
      }

      const tokens =
        (recipientData?.fcmTokens as string[] | undefined) ?? [];
      if (tokens.length === 0) {
        logger.info("reminder_send_failed_no_tokens", {
          event: "reminder_send_failed_no_tokens",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
        });
        throw new HttpsError(
          "failed-precondition",
          "Recipient has not enabled push notifications.",
          {errorCode: "RECIPIENT_NO_TOKENS"},
        );
      }

      // 8. Sender displayName read (for FCM body string)
      const senderSnap = await db.collection("users").doc(senderUid).get();
      const senderData = senderSnap.exists ?
        (senderSnap.data() as Record<string, unknown> | undefined) :
        undefined;
      const senderName =
        (senderData?.displayName as string | undefined) ?? "A friend";

      // 9. FCM dispatch — Invariant 1: amountPaise carried as int
      const dispatchResult = await sendReminderFcm(
        {db, logger, messaging: messaging as never},
        {
          fromUserId: senderUid,
          toUserId: toUserId as string,
          contextType: "friendship",
          contextId: contextId as string,
          senderName,
          amountPaise: owedPaise,
          eventTimestamp: nowDate,
        },
      );

      // 10. Full-failure check (architect §2.5)
      if (dispatchResult.succeeded < 1) {
        logger.error("reminder_send_failed", {
          event: "reminder_send_failed",
          senderUidHash,
          recipientUidHash,
          contextType,
          contextIdHash,
          errorCode: "FCM_DISPATCH_FAILED",
          failed: dispatchResult.failed,
          pruned: dispatchResult.pruned.length,
        });
        throw new HttpsError(
          "unavailable",
          "Reminder could not be delivered to the recipient's device(s).",
          {errorCode: "FCM_DISPATCH_FAILED"},
        );
      }

      // 11. Rate-limit document write
      const windowStart =
        (rateLimitSnap.exists &&
          typeof rateLimitSnap.data()?.windowStart === "number") ?
          (rateLimitSnap.data()!.windowStart as number) :
          nowMs;

      await rateLimitRef.set({
        lastSentAt: Timestamp.fromDate(nowDate),
        count: rateLimitSnap.exists ? FieldValue.increment(1) : 1,
        windowStart,
        recipientUid: toUserId as string,
        senderUid,
        updatedAt: Timestamp.fromDate(nowDate),
      });

      // 12. Activity-feed emission (recipient-only)
      const reminderPayload: ReminderPayload = {
        senderUid,
        recipientUid: toUserId as string,
        contextType: "friendship",
        contextId: contextId as string,
        amountPaise: owedPaise,
        message: message ?? REMINDER_DEFAULT_MESSAGE,
      };
      validateActivityPayload("reminder", reminderPayload);

      await db
        .collection("activity")
        .doc(toUserId as string)
        .collection("items")
        .add({
          type: "reminder",
          payload: reminderPayload,
          createdAt: FieldValue.serverTimestamp(),
        });

      const nextAllowedAtIso = new Date(
        nowMs + REMINDER_WINDOW_MS,
      ).toISOString();

      logger.info("reminder_send_succeeded", {
        event: "reminder_send_succeeded",
        senderUidHash,
        recipientUidHash,
        contextType,
        contextIdHash,
        succeeded: dispatchResult.succeeded,
        failed: dispatchResult.failed,
        pruned: dispatchResult.pruned.length,
        ...(message !== undefined ? {messageLength: message.length} : {}),
      });

      return {success: true, nextAllowedAtIso};
    } catch (err: unknown) {
      if (err instanceof HttpsError) {
        throw err;
      }
      logger.error("reminder_send_failed", {
        event: "reminder_send_failed",
        senderUidHash,
        recipientUidHash,
        contextType,
        contextIdHash,
        errorCode: "INTERNAL",
        errorMessage: err instanceof Error ? err.message : String(err),
      });
      throw new HttpsError("internal", "Internal error.", {
        errorCode: "INTERNAL",
      });
    }
  };
}
