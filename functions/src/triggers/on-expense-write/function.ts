/**
 * onExpenseWriteFriendship — Function Boundary
 *
 * Handles every create / update / soft-delete / hard-delete of an expense
 * document under `friendships/{friendshipId}/expenses/{expenseId}`. Delegates
 * the read-compute-write transaction to the shared `recomputeAndWrite` core
 * (PR #12, refactored in PR #36 variant 2.3(b)), and atomically maintains
 * the parent friendship's `lastActivityAt` so the friends-list ordering
 * shipped in PR #35 (FR-FR-03 AC-6) actually moves on every event.
 *
 * This is the first Firestore trigger in the application's history and the
 * first non-callable producer of `simplifiedBalances`. Invariant 2 is
 * enforced server-side from this point forward.
 *
 * Error policy (Cloud Functions v2 retry semantics):
 *   - CONTEXT_NOT_FOUND: log structured failure, return successfully so
 *     Cloud Functions does NOT retry (the friendship is gone — retries
 *     cannot help).
 *   - BALANCE_INVARIANT_VIOLATED: log structured failure and THROW so
 *     Cloud Functions retries (per error catalogue "Retryable: Yes (after
 *     data investigation)"). Repeated retries surface as alerts.
 *   - INTERNAL (unknown errors): THROW so Cloud Functions retries.
 *   - Stale events (`event.time` > 7 days old): log and return — the
 *     7-day Cloud Functions delivery window guarantees no live event is
 *     older than this; anything that old is a stuck retry-queue artefact
 *     and must not rewrite balances.
 *
 * Telemetry:
 *   - `expense_trigger_fired` at the top of every invocation.
 *   - `expense_trigger_stale_event_dropped` on the stale-event branch.
 *   - `simplified_debts_compute_started` / `_completed` / `_failed` are
 *     emitted by this wrapper around the shared core (same event names as
 *     the callable for log uniformity).
 *
 * PII posture:
 *   Logger NEVER receives payerId, splits[].userId, amountPaise,
 *   sharePaise, or description values. Only opaque Firestore IDs
 *   (`friendshipId`, `expenseId`) and contextType discriminators are
 *   loggable.
 *
 * @module triggers/on-expense-write/function
 */

import {Timestamp} from "firebase-admin/firestore";
import type {Change, DocumentSnapshot, FirestoreEvent} from
  "firebase-functions/v2/firestore";
import {
  recomputeAndWrite,
  Dependencies,
} from "../../simplified-debts/function";
import {hashId} from "../../utils/id-hash";
import {writeExpenseActivity} from "./activity-writer";
import {
  buildExpenseActivityPayload,
  type ExpenseDocData,
} from "./payload-builder";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Cloud Functions event-delivery retention window. */
const STALE_EVENT_AGE_MS = 7 * 24 * 60 * 60 * 1000;

// ---------------------------------------------------------------------------
// Trigger event params
// ---------------------------------------------------------------------------

/** Path params extracted from `friendships/{friendshipId}/expenses/{expenseId}`. */
type FriendshipExpenseParams = {
  friendshipId: string;
  expenseId: string;
};

type TriggerEvent = FirestoreEvent<
  Change<DocumentSnapshot> | undefined,
  FriendshipExpenseParams
>;

// ---------------------------------------------------------------------------
// Change-type discrimination
// ---------------------------------------------------------------------------

type ChangeType = "create" | "update" | "delete";

/**
 * Derives the change type from the snapshot existence on each side of the
 * Firestore `Change<DocumentSnapshot>`. v2 events use `.exists` (boolean)
 * on the snapshot rather than `undefined`-ness of the snapshot itself —
 * the snapshot wrapper is always present per `firebase-functions/v2/firestore`.
 */
function deriveChangeType(
  change: Change<DocumentSnapshot> | undefined,
): ChangeType {
  if (!change) {
    // Defensive — the v2 onDocumentWritten event always carries a Change
    // for write triggers, but if somehow undefined, treat as create.
    return "create";
  }
  const beforeExists = change.before?.exists === true;
  const afterExists = change.after?.exists === true;
  if (!beforeExists && afterExists) return "create";
  if (beforeExists && !afterExists) return "delete";
  return "update";
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the Firestore trigger handler with injected dependencies.
 *
 * @param deps - Firestore database and structured logger.
 * @returns An async handler suitable for
 *   `onDocumentWritten('friendships/{friendshipId}/expenses/{expenseId}', handler)`.
 */
export function createTriggerHandler(
  deps: Dependencies,
): (event: TriggerEvent) => Promise<void> {
  const {logger} = deps;

  return async (event: TriggerEvent): Promise<void> => {
    const startTime = Date.now();
    const {friendshipId, expenseId} = event.params;
    const contextType = "friendship" as const;
    const eventTime = event.time;
    const changeType = deriveChangeType(event.data);

    // PII guard: friendshipId is `{uidA}_{uidB}` (deterministic
    // composite of two user UIDs per the schema). Logging the raw value
    // would leak user identifiers into Cloud Logging in violation of
    // SRS section 5.4 and ADR-0013. Hash before logging.
    const contextIdHash = hashId(friendshipId);
    const expenseIdHash = hashId(expenseId);

    // 1. Telemetry — first log call, fires for every invocation
    logger.info("expense_trigger_fired", {
      event: "expense_trigger_fired",
      contextType,
      contextIdHash,
      expenseIdHash,
      changeType,
      eventTime,
    });

    // 2. Stale-event guard (AC-11)
    const eventTimeMs = new Date(eventTime).getTime();
    const ageMs = Date.now() - eventTimeMs;
    if (
      Number.isFinite(eventTimeMs) &&
      ageMs > STALE_EVENT_AGE_MS
    ) {
      logger.info("expense_trigger_stale_event_dropped", {
        event: "expense_trigger_stale_event_dropped",
        contextType,
        contextIdHash,
        expenseIdHash,
        eventTime,
        ageMs,
      });
      return;
    }

    // 3. Activity-feed seam — FR-EX-07 ships the expense-side write.
    //    The remaining hand-off seam below is for the future story:
    //    TODO(FR-AC-03): send FCM push notification respecting
    //    notificationPrefs. Placement note: FCM (like the activity
    //    emission) MUST run only after a successful recompute (i.e.
    //    inside or just below the success branch) to keep retry
    //    semantics clean — a retryable transient failure must not
    //    duplicate notifications.

    // 4. Build the alsoSet payload — atomically advance lastActivityAt
    //    inside the same transaction as the simplifiedBalances write.
    //    The shared core applies the monotonicity guard so out-of-order
    //    delivery cannot regress the friends-list ordering (PR #35 AC-6,
    //    PR #36 AC-12).
    const eventTimestamp = Number.isFinite(eventTimeMs)
      ? Timestamp.fromDate(new Date(eventTimeMs))
      : Timestamp.now();

    // 5. Log compute-started (same event name as the callable for log
    //    uniformity across both invocation paths). The trigger uses
    //    `contextIdHash` because friendship IDs are composite UIDs;
    //    the callable's separate logging path is preserved unchanged
    //    (callable invocations are commonly for groups, where context
    //    IDs are opaque auto-generated Firestore IDs).
    logger.info("simplified_debts_compute_started", {
      event: "simplified_debts_compute_started",
      contextType,
      contextIdHash,
    });

    // 6. Delegate to the shared core. Map the typed result to the
    //    trigger's error policy.
    let result;
    try {
      result = await recomputeAndWrite(deps, {
        contextType,
        contextId: friendshipId,
        alsoSet: {lastActivityAt: eventTimestamp},
      });
    } catch (err: unknown) {
      // INTERNAL — unknown error (transient Firestore contention, deadline,
      // runtime exception). Log and THROW so Cloud Functions retries.
      logger.error("simplified_debts_compute_failed", {
        event: "simplified_debts_compute_failed",
        contextType,
        contextIdHash,
        errorCode: "INTERNAL",
        elapsedMs: Date.now() - startTime,
      });
      throw err;
    }

    if (!result.ok) {
      logger.error("simplified_debts_compute_failed", {
        event: "simplified_debts_compute_failed",
        contextType,
        contextIdHash,
        errorCode: result.code,
        elapsedMs: Date.now() - startTime,
      });

      if (result.code === "CONTEXT_NOT_FOUND") {
        // Friendship was deleted — retries cannot help. Return successfully
        // so Cloud Functions does NOT retry. AC-10.
        return;
      }

      // BALANCE_INVARIANT_VIOLATED — corrupt source data. THROW so Cloud
      // Functions retries; on-call investigates persistently failing
      // events. Per error catalogue "Retryable: Yes (after data
      // investigation)". The thrown message uses the hashed friendship
      // ID so it remains PII-safe even if the runtime includes the
      // error string in any subsequent log.
      throw new Error(
        `Balance invariant violated for friendship(${contextIdHash}); ` +
          "see structured logs for correlation.",
      );
    }

    // 7. Emit activity items for both friendship members (FR-EX-07).
    //    Runs AFTER the successful recomputeAndWrite per architect
    //    notes §2.1 so a transient recompute failure does NOT
    //    duplicate items. Failures inside the activity emission are
    //    contained — the writer's Promise.allSettled prevents
    //    per-member failures from rethrowing, and the validator
    //    throw (programmer error) is caught here so the trigger's
    //    success branch is preserved (architect §2.9 item 2).
    await emitExpenseActivity(deps, {
      friendshipId,
      expenseId,
      changeType,
      contextType,
      contextIdHash,
      expenseIdHash,
      eventTimestamp,
      changeData: event.data,
    });

    // 8. Success — log completed event
    logger.info("simplified_debts_compute_completed", {
      event: "simplified_debts_compute_completed",
      contextType,
      contextIdHash,
      elapsedMs: Date.now() - startTime,
      transferCount: result.transfers.length,
    });
  };
}

// ---------------------------------------------------------------------------
// Activity emission (FR-EX-07)
// ---------------------------------------------------------------------------

/**
 * Discriminates the activity event type and writes one item per
 * friendship member. Wraps `writeExpenseActivity` with the trigger-
 * specific (a) soft-delete detection, (b) member-ID resolution, and
 * (c) defensive try/catch for programmer errors (validator throws).
 *
 * Per architect §2.9 item 2: NEVER rethrows. Activity-emission
 * failures must not propagate into the trigger's success branch,
 * otherwise Cloud Functions would retry the whole invocation and
 * potentially re-duplicate activity items on the successful members.
 */
async function emitExpenseActivity(
  deps: Dependencies,
  params: {
    friendshipId: string;
    expenseId: string;
    changeType: ChangeType;
    contextType: "friendship";
    contextIdHash: string;
    expenseIdHash: string;
    eventTimestamp: Timestamp;
    changeData: Change<DocumentSnapshot> | undefined;
  },
): Promise<void> {
  const {db, logger} = deps;
  const {
    friendshipId,
    expenseId,
    changeType,
    contextType,
    contextIdHash,
    expenseIdHash,
    eventTimestamp,
    changeData,
  } = params;

  try {
    const beforeData = changeData?.before?.exists
      ? (changeData.before.data() as ExpenseDocData | undefined)
      : undefined;
    const afterData = changeData?.after?.exists
      ? (changeData.after.data() as ExpenseDocData | undefined)
      : undefined;

    // Soft-delete discrimination: an update that flips deleted false
    // -> true emits expense_deleted, NOT expense_edited.
    let activityChangeType: ChangeType = changeType;
    if (
      changeType === "update" &&
      beforeData?.deleted === false &&
      afterData?.deleted === true
    ) {
      activityChangeType = "delete";
    }

    // Resolve memberIds via a re-read of the friendship doc. The
    // recomputeAndWrite path already read this doc inside its
    // transaction but does not expose the snapshot in its typed
    // return; one extra read here is the simplest non-invasive
    // approach. If the friendship was deleted between the recompute
    // and this read (rare race), memberIds is empty and we skip
    // emission silently — symmetric with the CONTEXT_NOT_FOUND
    // behaviour on the recompute path.
    const friendshipSnap = await db
      .collection("friendships")
      .doc(friendshipId)
      .get();
    if (!friendshipSnap.exists) {
      logger.info("activity_emission_skipped_missing_context", {
        event: "activity_emission_skipped_missing_context",
        contextType,
        contextIdHash,
        expenseIdHash,
      });
      return;
    }
    const memberIds =
      (friendshipSnap.data()?.memberIds as string[] | undefined) ?? [];
    if (memberIds.length === 0) {
      logger.info("activity_emission_skipped_empty_members", {
        event: "activity_emission_skipped_empty_members",
        contextType,
        contextIdHash,
        expenseIdHash,
      });
      return;
    }

    const built = buildExpenseActivityPayload(
      activityChangeType,
      {friendshipId, expenseId, before: beforeData, after: afterData},
      eventTimestamp,
    );

    await writeExpenseActivity(deps, {
      friendshipId,
      expenseId,
      eventType: built.eventType,
      payload: built.payload,
      memberIds,
    });
  } catch (err: unknown) {
    // Defence-in-depth: writeExpenseActivity itself uses
    // Promise.allSettled and never rethrows for per-member Firestore
    // failures. But the validator inside it DOES throw on programmer
    // error (e.g. a malformed payload), and the payload-builder
    // throws on inconsistent (changeType, before, after) tuples.
    // Both are programmer errors that should NOT mark the trigger as
    // failed — the recompute is already done; failing here would
    // only cause a retry-storm that re-runs the recompute.
    logger.error("activity_emission_internal_error", {
      event: "activity_emission_internal_error",
      contextType,
      contextIdHash,
      expenseIdHash,
      errorMessage: err instanceof Error ? err.message : "unknown",
    });
  }
}
