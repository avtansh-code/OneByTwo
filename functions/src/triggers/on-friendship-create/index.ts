/**
 * onFriendshipCreate — Trigger Registration
 *
 * Registers the Firestore `onDocumentCreated` trigger for
 * `friendships/{friendshipId}` in `asia-south1` (Mumbai) per SRS section
 * 7.1. Retry is enabled per the Cloud Functions v2 `{retry: true}`
 * option, consistent with the sibling triggers; in-window redeliveries
 * duplicate items, dropped only by the handler's 7-day stale-event guard.
 *
 * Emits a single `friend_added` activity item to BOTH members of the new
 * friendship (be-activity-types / SCR-25). There is no money component, so
 * no `simplifiedBalances` recompute and no FCM dispatch — the trigger is a
 * pure activity-feed producer that reuses the shared
 * `writeExpenseActivity` fan-out writer.
 *
 * Companion bindings:
 *   - `onExpenseWriteFriendship` (friendship expenses) and
 *     `onSettlementWrite` (top-level settlements) handle balance recompute
 *     plus activity emission for money events.
 *
 * @module triggers/on-friendship-create
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createTriggerHandler} from "./function";

const REGION = "asia-south1";

/**
 * Firestore trigger: fans out a `friend_added` activity item to both
 * members whenever a friendship is created at
 * `friendships/{friendshipId}`.
 *
 * - Reuses the FR-EX-07 activity-writer fan-out (one
 *   `activity/{recipientUid}/items/{auto-id}` doc per member).
 * - Idempotency: `onDocumentCreated` fires once; retries are dropped by
 *   the handler's 7-day stale-event guard.
 * - Author resolution: `createdBy` when present, else `memberIds[0]`.
 * - Malformed docs (missing `memberIds`) are contained — log and return.
 */
export const onFriendshipCreate = onDocumentCreated(
  {
    region: REGION,
    document: "friendships/{friendshipId}",
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
