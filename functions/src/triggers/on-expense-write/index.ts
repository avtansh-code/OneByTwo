/**
 * onExpenseWriteFriendship — Trigger Registration
 *
 * Registers the Firestore `onDocumentWritten` trigger for
 * `friendships/{friendshipId}/expenses/{expenseId}` in `asia-south1`
 * (Mumbai) per SRS section 7.1. Retry is enabled per the Cloud Functions
 * v2 `{retry: true}` option (the v1 `failurePolicy: { retry: {} }` is
 * superseded by this).
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
import * as logger from "firebase-functions/logger";
import {createTriggerHandler} from "./function";

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
 *
 * See `docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md`
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
    });
    return handler(event);
  },
);
