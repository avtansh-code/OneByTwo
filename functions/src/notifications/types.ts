/**
 * Shared types for the FR-AC-03 FCM notifications module.
 *
 * The types in this file form the public contract between the
 * triggers (callers) and the dispatcher (this module). They are
 * exported from `./index.ts` so trigger code can import them via
 * `from "../../notifications"`.
 *
 * Cross-references:
 *   - `docs/design/07-technical/notifications.md` §2.1 (payload
 *     envelope), §2.3 (prefs filter).
 *   - `docs/sprint-zero/stories/FR-AC-03-fcm-push-notifications.md`
 *     architect §2.10 item 7 (`NotificationsApi` injected as an
 *     OPTIONAL field on the trigger's `Dependencies` shape).
 *
 * @module notifications/types
 */

import type {Messaging} from "firebase-admin/messaging";
import type {Firestore} from "firebase-admin/firestore";

/**
 * The six notification types currently supported by the FCM module.
 * Each maps 1:1 to a render template in `payload-renderer.ts` and a
 * preference flag in `prefs-filter.ts` (with `group_invite` bypassing
 * the filter per AC-19 forward-compat).
 *
 * IMPORTANT: clients dispatch on the `type` field of the FCM data
 * envelope, so this string is part of the wire contract. Adding a new
 * value requires a coordinated client-side change.
 */
export type NotificationType =
  | "expense_added"
  | "expense_edited"
  | "expense_deleted"
  | "settlement_received"
  | "reminder"
  | "group_invite";

/**
 * The FCM data envelope sent to clients (per `notifications.md` §2.1).
 *
 * All field values are STRINGS — FCM data payloads do not support
 * native typed values. Numeric fields like `amountPaise` are
 * stringified at the renderer boundary; clients parse back to integer
 * on receipt.
 *
 * The `notification` block (`title`/`body` outside `data`) is OMITTED
 * — this is a data-only message. Clients construct the platform
 * notification from `title` and `body` inside `data` so we retain
 * full control over visual presentation across iOS / Android.
 */
export interface NotificationPayload {
  /** Discriminator for the client-side router. */
  type: NotificationType;
  /** "friendship" or "group" — currently only "friendship" in MVP. */
  contextType: "friendship" | "group";
  /** Raw friendship or group id (NOT a hash — clients need to navigate). */
  contextId: string;
  /** Optional item id (expense, settlement, invite) for deep-linking. */
  itemId?: string;
  /** Localised notification title; ≤ 100 chars. */
  title: string;
  /** Localised notification body; ≤ 240 chars. */
  body: string;
  /** displayName of the actor (payer / settler / sender). */
  senderName: string;
  /**
   * Integer paise as a string (FCM data is string-only). OPTIONAL —
   * the `group_invite` template has no monetary value and omits this
   * field. All other templates set it to the stringified paise.
   */
  amountPaise?: string;
  /** ISO 8601 timestamp of the originating Firestore write. */
  createdAt: string;
  /**
   * OPTIONAL invite token for the `group_invite` payload (forward-
   * compat, no producer in FR-AC-03 itself). Other templates omit it.
   */
  inviteToken?: string;
}

/**
 * The user's notification preferences, mirroring the
 * `users/{uid}.notificationPrefs` map (FR-AU-06 schema).
 *
 * All flags default to TRUE if missing from the map — see
 * `prefs-filter.ts` for the resolver.
 */
export interface RecipientPrefs {
  newExpense?: boolean;
  settlement?: boolean;
  reminder?: boolean;
}

/**
 * Shared dependencies for all notification dispatch helpers. The
 * `messaging` and `db` instances are injected so unit tests can pass
 * mocks; in production they come from the trigger's wiring.
 *
 * The `logger` shape matches the firebase-functions/logger interface
 * (2-arg: message + structured data) so the FCM module can be called
 * directly from a Cloud Functions trigger or a callable handler
 * without a wrapper. Trigger-side emitters wrap their existing 1-arg
 * logger to fit this shape.
 */
export interface NotificationsDependencies {
  db: Firestore;
  messaging: Messaging;
  logger: {
    info(message: string, data?: Record<string, unknown>): void;
    warn(message: string, data?: Record<string, unknown>): void;
    error(message: string, data?: Record<string, unknown>): void;
  };
}

/**
 * Parameters for `sendExpenseNotification`.
 *
 * The `changeType` discriminator maps to the `expense_added` /
 * `expense_edited` / `expense_deleted` payload type. `senderName` is
 * the displayName of the expense's `createdBy` user (resolved by the
 * trigger before invoking this helper).
 */
export interface SendExpenseNotificationParams {
  /** UID of the expense's `createdBy` actor — EXCLUDED from recipients. */
  authorUid: string;
  /** All members of the parent context (friendship.memberIds). */
  memberIds: string[];
  contextType: "friendship" | "group";
  contextId: string;
  expenseId: string;
  /** Resolved displayName of the actor. */
  senderName: string;
  /** Expense description (free text, ≤ 200 chars). */
  description: string;
  /** Integer paise amount of the expense. */
  amountPaise: number;
  /**
   * Source timestamp of the Firestore event as a `Date`. The trigger
   * parses `event.time` (ISO 8601 string) to a Date before invoking
   * this helper.
   */
  eventTimestamp: Date;
  /** "create" → expense_added, "update" → expense_edited, "delete" → expense_deleted. */
  changeType: "create" | "update" | "delete";
}

/**
 * Parameters for `sendSettlementNotification`. Only one recipient
 * (`toUserId`); the payer (`fromUserId`) is the actor and is NOT
 * notified.
 */
export interface SendSettlementNotificationParams {
  fromUserId: string;
  toUserId: string;
  contextType: "friendship" | "group";
  contextId: string;
  settlementId: string;
  /** Resolved displayName of the payer (fromUserId). */
  senderName: string;
  amountPaise: number;
  /**
   * Source timestamp of the Firestore event as a `Date`. The trigger
   * parses `event.time` (ISO 8601 string) to a Date before invoking
   * this helper.
   */
  eventTimestamp: Date;
}

/**
 * Parameters for `sendReminderNotification` (FR-SE-09). Only one
 * recipient (`toUserId`); the sender (`fromUserId`) is the actor and
 * is NOT notified. The `amountPaise` is the OWED amount per
 * `simplifiedBalances[toUserId][fromUserId]` (resolved by the
 * callable's precondition check before invoking this helper).
 */
export interface SendReminderNotificationParams {
  /** Sender UID — for log correlation. NOT a recipient. */
  fromUserId: string;
  /** Recipient UID — the friend who owes the sender. */
  toUserId: string;
  contextType: "friendship" | "group";
  contextId: string;
  /** Resolved displayName of the sender (fromUserId). */
  senderName: string;
  /** Integer paise the recipient owes the sender. */
  amountPaise: number;
  /** Server-side `now()` at the time the callable fires. */
  eventTimestamp: Date;
}

/**
 * Aggregated result of an FCM dispatch. Per-recipient counts are
 * tallied across the multi-recipient expense case; the settlement
 * helper produces a result with counts ≤ 1.
 */
export interface NotificationDispatchResult {
  /** Number of FCM `send()` calls that resolved successfully. */
  succeeded: number;
  /** Number of FCM `send()` calls that rejected with a non-410 error. */
  failed: number;
  /** Tokens removed from `users/{uid}.fcmTokens` due to a 410 response. */
  pruned: string[];
  /** Recipients suppressed by the per-user preference filter. */
  suppressedByPrefs: number;
  /** Recipients skipped because their `fcmTokens` array was empty. */
  skippedEmptyTokens: number;
  /** Recipients skipped because their `users/{uid}` doc was missing. */
  skippedMissingUser: number;
}

/**
 * The public surface of this module — the shape injected into the
 * trigger's `Dependencies.notificationsApi` field (architect §2.10
 * item 7). Marking the field optional on the Dependencies type lets
 * existing tests continue to pass without wiring this api.
 */
export interface NotificationsApi {
  sendExpenseNotification(
    deps: NotificationsDependencies,
    params: SendExpenseNotificationParams,
  ): Promise<NotificationDispatchResult>;
  sendSettlementNotification(
    deps: NotificationsDependencies,
    params: SendSettlementNotificationParams,
  ): Promise<NotificationDispatchResult>;
  sendReminderNotification(
    deps: NotificationsDependencies,
    params: SendReminderNotificationParams,
  ): Promise<NotificationDispatchResult>;
}
