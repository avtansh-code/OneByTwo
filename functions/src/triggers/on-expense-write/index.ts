/**
 * onExpenseWriteFriendship — Trigger Registration
 *
 * Registers the Firestore `onDocumentWritten` trigger for
 * `friendships/{friendshipId}/expenses/{expenseId}` in `asia-south1`
 * (Mumbai) per SRS section 7.1. Retry is enabled per the Cloud Functions
 * v2 `{retry: true}` option (the v1 `failurePolicy: { retry: {} }` is
 * superseded by this).
 *
 * FR-AC-03: the production wiring constructs a `NotificationsApi` from
 * the two dispatcher entry points re-exported by `../../notifications`
 * and the admin-SDK `Messaging` instance, and passes both via the
 * extended `Dependencies` shape. The trigger-side emitter helper
 * (`emitExpenseFcm` in `./function.ts`) consumes them inside its
 * try/catch wrapper.
 *
 * Companion bindings:
 *   - `onExpenseWriteGroup` for `groups/{groupId}/expenses/{expenseId}`
 *     is DEFERRED to Sprint 3 (groups epic). Architect notes §2 of the
 *     FR-SE-03-04-expense-trigger-friendship story explain the rationale.
 *
 * @module triggers/on-expense-write
 */

import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import {createTriggerHandler} from "./function";
import {
  sendExpenseNotification,
  sendSettlementNotification,
} from "../../notifications";

const REGION = "asia-south1";

/**
 * Firestore trigger: recomputes `simplifiedBalances` and updates
 * `lastActivityAt` on the parent friendship document whenever an
 * expense is created, updated, or deleted under
 * `friendships/{friendshipId}/expenses/{expenseId}`.
 *
 * - First non-callable producer of `simplifiedBalances` (Invariant 2).
 * - Atomicity: both fields written in the same Firestore transaction
 *   (FR-SE-03/04 AC-6).
 * - Retry: enabled. CONTEXT_NOT_FOUND returns successfully (no retry).
 *   BALANCE_INVARIANT_VIOLATED and INTERNAL throw (Cloud Functions
 *   retries).
 * - Stale-event guard: events older than 7 days are dropped.
 * - FR-AC-03: after a successful recompute + activity emission, the
 *   trigger fires an FCM push notification to non-author members of
 *   the friendship. FCM failures are CONTAINED — they never block
 *   or retry the trigger.
 *
 * See `docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md`
 * and `docs/sprint-zero/stories/FR-AC-03-fcm-push-notifications.md`
 * for full acceptance criteria.
 */
export const onExpenseWriteFriendship = onDocumentWritten(
  {
    region: REGION,
    document: "friendships/{friendshipId}/expenses/{expenseId}",
    retry: true,
  },
  async (event) => {
    const handler = createTriggerHandler({
      db: getFirestore(),
      logger,
      // FR-AC-03 production wiring: inject the FCM dispatcher
      // surface so the trigger-side emitter helper can fire push
      // notifications. Both fields are OPTIONAL on the
      // Dependencies type — existing tests that don't wire them
      // continue to pass (emitExpenseFcm no-ops silently).
      notificationsApi: {
        sendExpenseNotification,
        sendSettlementNotification,
      },
      messaging: getMessaging(),
    });
    return handler(event);
  },
);
