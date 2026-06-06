/**
 * onSettlementWrite — Trigger Registration
 *
 * Registers the Firestore `onDocumentWritten` trigger for
 * `settlements/{settlementId}` in `asia-south1` (Mumbai) per SRS
 * section 7.1. Retry is enabled per the Cloud Functions v2
 * `{retry: true}` option.
 *
 * Companion bindings:
 *   - `onExpenseWriteFriendship` handles expense writes under
 *     `friendships/{friendshipId}/expenses/{expenseId}` (FR-SE-03/04).
 *   - `onExpenseWriteGroup` for `groups/{groupId}/expenses/{expenseId}`
 *     is DEFERRED to Sprint 3 (groups epic). Architect notes §1 of the
 *     FR-SE-05-06-settlement-trigger story explain why the settlements
 *     trigger (top-level) can ship before the groups context exists —
 *     the trigger reads the context discriminator from the doc data, so
 *     it naturally handles both friendship and group contexts when
 *     groups become available without a new binding.
 *
 * @module triggers/on-settlement-write
 */

import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createTriggerHandler} from "./function";

const REGION = "asia-south1";

/**
 * Firestore trigger: recomputes `simplifiedBalances` and updates
 * `lastActivityAt` on the parent context (friendship or group)
 * document whenever a settlement is created, updated, or deleted at
 * `settlements/{settlementId}`.
 *
 * - First trigger on a TOP-LEVEL collection in the application's
 *   history (the existing expense trigger covers the subcollection-
 *   scoped case).
 * - First trigger to make the simplified-debts algorithm read settlements
 *   into the net-balance computation — the catalogue's "settlements"
 *   row of the algorithm read table is now truthful.
 * - Atomicity: both `simplifiedBalances` and `lastActivityAt` are
 *   written in the same Firestore transaction (FR-SE-05/06 AC-9).
 * - Retry: enabled. CONTEXT_NOT_FOUND returns successfully (no retry).
 *   BALANCE_INVARIANT_VIOLATED and INTERNAL throw (Cloud Functions
 *   retries).
 * - Stale-event guard: events older than 7 days are dropped.
 *
 * See `docs/sprint-zero/stories/FR-SE-05-06-settlement-trigger.md` for
 * full acceptance criteria.
 */
export const onSettlementWrite = onDocumentWritten(
  {
    region: REGION,
    document: "settlements/{settlementId}",
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
