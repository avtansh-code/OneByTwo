/**
 * onSettlementWrite — Function Boundary
 *
 * Handles every create / update / soft-delete / hard-delete of a
 * settlement document at `settlements/{settlementId}` (a TOP-LEVEL
 * collection, unlike the subcollection-scoped expense trigger).
 * Delegates the read-compute-write transaction to the shared
 * `recomputeAndWrite` core (which is extended to read the top-level
 * settlements collection alongside the per-context expenses
 * subcollection — see `functions/src/simplified-debts/function.ts`),
 * and atomically maintains the parent context document's
 * `lastActivityAt` so the friends-list ordering (FR-FR-03 AC-6)
 * advances on every settlement event.
 *
 * This is the second Firestore trigger in the application's history
 * and the first on a top-level collection. Because the settlements
 * collection is top-level, the trigger reads the context discriminator
 * (`contextType`, `contextId`) from the document DATA rather than the
 * event path. The after-side snapshot is preferred (create/update); on
 * hard delete the before-side is the source.
 *
 * Error policy (Cloud Functions v2 retry semantics — identical to the
 * expense trigger):
 *   - CONTEXT_NOT_FOUND: log structured failure, return successfully so
 *     Cloud Functions does NOT retry (the friendship/group is gone —
 *     retries cannot help).
 *   - BALANCE_INVARIANT_VIOLATED: log structured failure and THROW so
 *     Cloud Functions retries (per error catalogue "Retryable: Yes (after
 *     data investigation)"). Repeated retries surface as alerts.
 *   - INTERNAL (unknown errors): THROW so Cloud Functions retries.
 *   - Stale events (`event.time` > 7 days old): log and return — the
 *     7-day Cloud Functions delivery window guarantees no live event is
 *     older than this; anything older is a stuck retry-queue artefact
 *     and must not rewrite balances.
 *
 * Telemetry:
 *   - `settlement_trigger_fired` at the top of every invocation.
 *   - `settlement_trigger_stale_event_dropped` on the stale-event branch.
 *   - `simplified_debts_compute_started` / `_completed` / `_failed` are
 *     emitted by this wrapper around the shared core (same event names as
 *     the expense trigger for log uniformity).
 *
 * PII posture:
 *   Logger NEVER receives fromUserId, toUserId, amountPaise, date, note,
 *   or any raw UID-containing identifier (including the unhashed
 *   composite friendship `contextId`). Only the opaque hashed
 *   `settlementIdHash` / `contextIdHash` values and contextType
 *   discriminators are loggable. Settlement IDs are themselves opaque
 *   auto-generated Firestore IDs (safe to log raw) but are hashed for
 *   log-format parity with the expense trigger.
 *
 * @module triggers/on-settlement-write/function
 */

import {Timestamp} from "firebase-admin/firestore";
import type {Change, DocumentSnapshot, FirestoreEvent} from
  "firebase-functions/v2/firestore";
import {
  recomputeAndWrite,
  Dependencies,
  ContextType,
} from "../../simplified-debts/function";
import {hashId} from "../../utils/id-hash";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Cloud Functions event-delivery retention window. */
const STALE_EVENT_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/** Permitted context discriminator values (mirrors callable validation). */
const VALID_CONTEXT_TYPES: ReadonlySet<string> = new Set([
  "friendship",
  "group",
]);

// ---------------------------------------------------------------------------
// Trigger event params
// ---------------------------------------------------------------------------

/** Path params extracted from `settlements/{settlementId}`. */
type SettlementParams = {
  settlementId: string;
};

type TriggerEvent = FirestoreEvent<
  Change<DocumentSnapshot> | undefined,
  SettlementParams
>;

// ---------------------------------------------------------------------------
// Change-type discrimination
// ---------------------------------------------------------------------------

type ChangeType = "create" | "update" | "delete";

/**
 * Derives the change type from snapshot existence on each side of the
 * Firestore `Change<DocumentSnapshot>` (mirrors the expense trigger).
 */
function deriveChangeType(
  change: Change<DocumentSnapshot> | undefined,
): ChangeType {
  if (!change) {
    return "create";
  }
  const beforeExists = change.before?.exists === true;
  const afterExists = change.after?.exists === true;
  if (!beforeExists && afterExists) return "create";
  if (beforeExists && !afterExists) return "delete";
  return "update";
}

// ---------------------------------------------------------------------------
// Discriminator extraction (the settlement-trigger-specific concern)
// ---------------------------------------------------------------------------

/**
 * Reads `contextType` and `contextId` from the settlement document data.
 * After-side takes precedence on create and update; before-side is the
 * source on hard delete (after.exists === false; after.data() is
 * undefined). Returns null if neither side carries a usable
 * discriminator — defensive guard so a malformed trigger event does not
 * crash the runtime.
 */
function extractContextDiscriminator(
  change: Change<DocumentSnapshot> | undefined,
): {contextType: ContextType; contextId: string} | null {
  if (!change) return null;
  const data =
    (change.after?.exists === true ? change.after.data() : undefined) ??
    (change.before?.exists === true ? change.before.data() : undefined);
  if (!data) return null;
  const rawContextType = data.contextType;
  const rawContextId = data.contextId;
  if (
    typeof rawContextType !== "string" ||
    !VALID_CONTEXT_TYPES.has(rawContextType) ||
    typeof rawContextId !== "string" ||
    rawContextId.length === 0
  ) {
    return null;
  }
  return {
    contextType: rawContextType as ContextType,
    contextId: rawContextId,
  };
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the Firestore trigger handler with injected dependencies.
 *
 * @param deps - Firestore database and structured logger.
 * @returns An async handler suitable for
 *   `onDocumentWritten('settlements/{settlementId}', handler)`.
 */
export function createTriggerHandler(
  deps: Dependencies,
): (event: TriggerEvent) => Promise<void> {
  const {logger} = deps;

  return async (event: TriggerEvent): Promise<void> => {
    const startTime = Date.now();
    const {settlementId} = event.params;
    const eventTime = event.time;
    const changeType = deriveChangeType(event.data);

    // PII guard: settlement IDs are opaque auto-generated Firestore
    // IDs (safe raw) but the parent friendship `contextId` is the
    // composite `{uidA}_{uidB}` pattern — logging it raw would leak
    // user identifiers. Both are hashed for parity with the expense
    // trigger's log format.
    const settlementIdHash = hashId(settlementId);

    const discriminator = extractContextDiscriminator(event.data);

    // Defensive: if neither side carries a usable discriminator, log
    // and return successfully. This should not happen in production
    // because the security rules require `contextType` and `contextId`
    // on every settlement create; but guarding here keeps the trigger
    // resilient to admin-SDK seeds or future schema changes.
    if (!discriminator) {
      logger.error("simplified_debts_compute_failed", {
        event: "simplified_debts_compute_failed",
        contextType: "unknown",
        settlementIdHash,
        errorCode: "INVALID_INPUT",
        elapsedMs: Date.now() - startTime,
      });
      return;
    }

    const {contextType, contextId} = discriminator;
    const contextIdHash = hashId(contextId);

    // 1. Telemetry — first log call, fires for every invocation
    logger.info("settlement_trigger_fired", {
      event: "settlement_trigger_fired",
      contextType,
      contextIdHash,
      settlementIdHash,
      changeType,
      eventTime,
    });

    // 2. Stale-event guard
    const eventTimeMs = new Date(eventTime).getTime();
    const ageMs = Date.now() - eventTimeMs;
    if (
      Number.isFinite(eventTimeMs) &&
      ageMs > STALE_EVENT_AGE_MS
    ) {
      logger.info("settlement_trigger_stale_event_dropped", {
        event: "settlement_trigger_stale_event_dropped",
        contextType,
        contextIdHash,
        settlementIdHash,
        eventTime,
        ageMs,
      });
      return;
    }

    // 3. Hand-off seams for downstream stories (placement parity with
    //    the expense trigger):
    //    TODO(FR-AC-01): write activity-feed items to both parties'
    //      activity/{userId}/items subcollection after successful
    //      recompute.
    //    TODO(FR-AC-03): send FCM push notification to the toUserId
    //      respecting notificationPrefs.settlement.
    //    Placement note: both seams must execute ONLY after a
    //    successful recompute (i.e. inside or just below the success
    //    branch at the bottom of this handler) to keep retry semantics
    //    clean — a retryable transient failure must not duplicate
    //    activity items or notifications. Today they are deferred
    //    entirely; the actual placement decision lives with the story
    //    that implements them.

    // 4. Build the alsoSet payload — atomically advance lastActivityAt
    //    inside the same transaction as the simplifiedBalances write.
    //    The shared core applies the monotonicity guard so out-of-order
    //    delivery cannot regress the friends-list ordering.
    const eventTimestamp = Number.isFinite(eventTimeMs)
      ? Timestamp.fromDate(new Date(eventTimeMs))
      : Timestamp.now();

    // 5. Log compute-started (same event name as the callable and the
    //    expense trigger for log uniformity).
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
        contextId,
        alsoSet: {lastActivityAt: eventTimestamp},
      });
    } catch (err: unknown) {
      // INTERNAL — unknown error. Log and THROW so Cloud Functions retries.
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
        // Friendship/group was deleted — retries cannot help. Return
        // successfully so Cloud Functions does NOT retry.
        return;
      }

      // BALANCE_INVARIANT_VIOLATED — corrupt source data. THROW so
      // Cloud Functions retries; on-call investigates persistently
      // failing events. Per error catalogue "Retryable: Yes (after
      // data investigation)". The thrown message uses the hashed
      // contextId so it remains PII-safe even if the runtime includes
      // the error string in any subsequent log.
      throw new Error(
        `Balance invariant violated for ${contextType}(${contextIdHash}); ` +
          "see structured logs for correlation.",
      );
    }

    // 7. Success — log completed event
    logger.info("simplified_debts_compute_completed", {
      event: "simplified_debts_compute_completed",
      contextType,
      contextIdHash,
      elapsedMs: Date.now() - startTime,
      transferCount: result.transfers.length,
    });
  };
}
