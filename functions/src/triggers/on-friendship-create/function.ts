/**
 * onFriendshipCreate — Function Boundary
 *
 * Handles the creation of a `friendships/{friendshipId}` document and
 * fans out a single `friend_added` activity item to BOTH members so the
 * SCR-25 activity feed shows "friend added" events (be-activity-types).
 * Reuses the shared `writeExpenseActivity` fan-out writer — it already
 * writes one `activity/{recipientUid}/items/{auto-id}` doc per member
 * with `{type, payload, createdAt: serverTimestamp}`; this trigger never
 * duplicates that loop.
 *
 * No money is involved: friend creation has no `amountPaise`, so there is
 * no recompute of `simplifiedBalances` here. The trigger is a pure
 * activity-feed producer.
 *
 * Idempotency:
 *   - `onDocumentCreated` fires exactly once per document, so no
 *     create/update/delete discrimination is needed. The only redelivery
 *     vector is a Cloud Functions retry; in-window redeliveries duplicate
 *     items, which is acceptable v1.0 behaviour and matches the
 *     expense/settlement triggers (idempotency inherited from the 7-day
 *     stale-event drop).
 *   - Stale events (`event.time` > 7 days old) are dropped — a stuck
 *     retry-queue artefact must not re-emit a "friend added" row.
 *
 * PII posture: the logger NEVER receives raw member UIDs or the composite
 * `{uidA}_{uidB}` friendship ID. Only the hashed `friendshipIdHash` and
 * member-count discriminators are loggable.
 *
 * @module triggers/on-friendship-create/function
 */

import type {FirestoreEvent, QueryDocumentSnapshot} from
  "firebase-functions/v2/firestore";
import {hashId} from "../../utils/id-hash";
import {
  writeExpenseActivity,
  ActivityWriterDependencies,
} from "../on-expense-write/activity-writer";
import type {FriendAddedPayload} from "../on-expense-write/payload-builder";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Cloud Functions event-delivery retention window. */
const STALE_EVENT_AGE_MS = 7 * 24 * 60 * 60 * 1000;

// ---------------------------------------------------------------------------
// Dependencies + trigger event params
// ---------------------------------------------------------------------------

/**
 * Dependencies injected into the handler for testability. The
 * friendship-create trigger only needs the writer's surface
 * (`db` + `logger`) — no FCM dispatcher and no simplified-debts core.
 */
export type Dependencies = ActivityWriterDependencies;

/** Path params extracted from `friendships/{friendshipId}`. */
type FriendshipParams = {
  friendshipId: string;
};

type TriggerEvent = FirestoreEvent<
  QueryDocumentSnapshot | undefined,
  FriendshipParams
>;

/** Source friendship document shape (subset this trigger reads). */
interface FriendshipDocData {
  memberIds?: unknown;
  createdBy?: unknown;
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the Firestore trigger handler with injected dependencies.
 *
 * @param deps - Firestore database and structured logger.
 * @returns An async handler suitable for
 *   `onDocumentCreated('friendships/{friendshipId}', handler)`.
 */
export function createTriggerHandler(
  deps: Dependencies,
): (event: TriggerEvent) => Promise<void> {
  const {logger} = deps;

  return async (event: TriggerEvent): Promise<void> => {
    const {friendshipId} = event.params;
    const eventTime = event.time;
    const friendshipIdHash = hashId(friendshipId);

    // 1. Telemetry — first log call, fires for every invocation.
    logger.info("friendship_create_trigger_fired", {
      event: "friendship_create_trigger_fired",
      friendshipIdHash,
      eventTime,
    });

    // 2. Stale-event guard. The 7-day delivery window guarantees no live
    //    event is older than this; anything older is a stuck retry-queue
    //    artefact and must not re-emit a "friend added" row.
    const eventTimeMs = new Date(eventTime).getTime();
    const ageMs = Date.now() - eventTimeMs;
    if (Number.isFinite(eventTimeMs) && ageMs > STALE_EVENT_AGE_MS) {
      logger.info("friendship_create_trigger_stale_event_dropped", {
        event: "friendship_create_trigger_stale_event_dropped",
        friendshipIdHash,
        eventTime,
        ageMs,
      });
      return;
    }

    // 3. Resolve members + author from the created document. A malformed
    //    doc (missing/empty memberIds) is contained — log and return so
    //    the trigger does not crash or retry-storm.
    const data = event.data?.data() as FriendshipDocData | undefined;
    const members = resolveMemberIds(data);
    if (members === null) {
      logger.error("friend_added_emission_skipped_missing_members", {
        event: "friend_added_emission_skipped_missing_members",
        friendshipIdHash,
      });
      return;
    }

    const authorUid = resolveAuthorUid(data, members);
    const payload: FriendAddedPayload = {authorUid, friendshipId};

    // 4. Fan out ONE friend_added item per member via the shared writer.
    //    Containment mirrors the settlement trigger: the writer's
    //    per-member failures are already contained (Promise.allSettled);
    //    a validator throw (programmer error) is caught here so the
    //    trigger never retry-storms on a malformed payload.
    try {
      await writeExpenseActivity(deps, {
        friendshipId,
        expenseId: friendshipId,
        eventType: "friend_added",
        payload,
        memberIds: members,
      });
    } catch (err: unknown) {
      logger.error("friend_added_emission_internal_error", {
        event: "friend_added_emission_internal_error",
        friendshipIdHash,
        errorMessage: err instanceof Error ? err.message : "unknown",
      });
    }
  };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Returns the friendship's `memberIds` as a non-empty array of non-empty
 * strings, or `null` when the field is missing or malformed. Defensive
 * guard: the rules require exactly two members, but the trigger must not
 * crash on an admin-SDK seed or future schema change.
 */
function resolveMemberIds(data: FriendshipDocData | undefined): string[] | null {
  if (!data || !Array.isArray(data.memberIds) || data.memberIds.length === 0) {
    return null;
  }
  const members = data.memberIds;
  if (!members.every((id) => typeof id === "string" && id.length > 0)) {
    return null;
  }
  return members as string[];
}

/**
 * Resolves the author UID: the friendship's `createdBy` (the inviter who
 * accepted the friend) when present and non-empty, else falls back to the
 * first member. `members` is guaranteed non-empty by the caller.
 */
function resolveAuthorUid(
  data: FriendshipDocData | undefined,
  members: readonly string[],
): string {
  const createdBy = data?.createdBy;
  if (typeof createdBy === "string" && createdBy.length > 0) {
    return createdBy;
  }
  return members[0];
}
