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
import {writeExpenseActivity} from "../on-expense-write/activity-writer";
import {
  buildSettlementActivityPayload,
  ChangeType as ActivityChangeType,
  SettlementDocData,
} from "./settlement-payload-builder";

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

    // 3. FCM emission seam — FR-AC-03 closes this seam with
    //    emitSettlementFcm at the END of the success branch (after
    //    the activity emission at step 8). Placement parity with
    //    the expense trigger: FCM runs ONLY after a successful
    //    recompute so a retryable transient failure does not
    //    duplicate notifications. See `emitSettlementFcm` below.

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

    // 8. FR-AC-01: emit activity-feed items to BOTH parties.
    //    Mirror of the FR-EX-07 expense-trigger contract at
    //    on-expense-write/function.ts. The activity-writer
    //    contains its own per-member errors (Promise.allSettled);
    //    the validator throw (programmer error) is caught here so the
    //    trigger's success branch is preserved (architect §2.9 item 2).
    await emitSettlementActivity(deps, {
      settlementId,
      changeType,
      contextType,
      contextIdHash,
      settlementIdHash,
      changeData: event.data,
    });

    // 9. FR-AC-03: emit FCM push notification to the toUserId.
    //    Mirror of `emitExpenseFcm` in the expense trigger. Placed
    //    AFTER the activity emission and success log so a transient
    //    FCM-side failure (contained by emitSettlementFcm) does not
    //    duplicate notifications on retry. emitSettlementFcm NEVER
    //    rethrows; when notificationsApi/messaging is absent from
    //    deps, it no-ops silently.
    await emitSettlementFcm(deps, {
      settlementId,
      changeType,
      contextType,
      contextIdHash,
      settlementIdHash,
      eventTime,
      changeData: event.data,
    });
  };
}

// ---------------------------------------------------------------------------
// Activity emission (FR-AC-01)
// ---------------------------------------------------------------------------

/**
 * Discriminates the activity event type and writes one item per
 * settlement party. Wraps `writeExpenseActivity` with the settlement-
 * trigger-specific (a) soft-delete detection (architect §2.2 — no
 * emission), (b) party-ID resolution from the settlement doc itself
 * (the rules at firestore.rules:445-455 require fromUserId and
 * toUserId; no second .get() is needed), and (c) defensive try/catch
 * for programmer errors (validator throws).
 *
 * Per architect §2.9 item 2: NEVER rethrows. Activity-emission
 * failures must not propagate into the trigger's success branch,
 * otherwise Cloud Functions would retry the whole invocation and
 * potentially re-duplicate activity items on the successful members.
 *
 * The activity-writer's `WriteExpenseActivityRequest` interface
 * pre-dates the settlement consumer; the field names `friendshipId`
 * and `expenseId` are misnomers when the source entity is a
 * settlement. The architect deferred the rename to keep PR #51's
 * tests and the Cloud Logging schema stable. FUTURE-work cleanup PR
 * may rename to `writeContextActivity` + `contextId` + `entityId` +
 * `entityIdHash`.
 */
async function emitSettlementActivity(
  deps: Dependencies,
  params: {
    settlementId: string;
    changeType: ActivityChangeType;
    contextType: ContextType;
    contextIdHash: string;
    settlementIdHash: string;
    changeData: Change<DocumentSnapshot> | undefined;
  },
): Promise<void> {
  const {logger} = deps;
  const {
    settlementId,
    changeType,
    contextType,
    contextIdHash,
    settlementIdHash,
    changeData,
  } = params;

  try {
    const beforeData = changeData?.before?.exists
      ? (changeData.before.data() as SettlementDocData | undefined)
      : undefined;
    const afterData = changeData?.after?.exists
      ? (changeData.after.data() as SettlementDocData | undefined)
      : undefined;

    const built = buildSettlementActivityPayload(changeType, {
      settlementId,
      before: beforeData,
      after: afterData,
    });

    // V1.0 emission policy: only create events emit activity items.
    // Soft-delete and hard-delete return null from the builder; we
    // short-circuit cleanly here.
    if (built === null) {
      return;
    }

    // Resolve memberIds from the source settlement doc directly.
    // For friendship-context settlements, both UIDs are required by
    // the security rules; we use the source-of-truth values from the
    // settlement document rather than re-reading the parent context
    // doc (no additional Firestore read needed — saves cost and
    // race risk).
    const sourceData = afterData ?? beforeData;
    if (!sourceData) {
      logger.info("activity_emission_skipped_missing_data", {
        event: "activity_emission_skipped_missing_data",
        contextType,
        contextIdHash,
        settlementIdHash,
      });
      return;
    }
    const memberIds = [sourceData.fromUserId, sourceData.toUserId];

    await writeExpenseActivity(deps, {
      friendshipId: sourceData.contextId,
      expenseId: settlementId,
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
      settlementIdHash,
      errorMessage: err instanceof Error ? err.message : "unknown",
    });
  }
}

// ---------------------------------------------------------------------------
// FCM emission (FR-AC-03)
// ---------------------------------------------------------------------------

/**
 * Emits an FCM push notification to the settlement's payee
 * (`toUserId`) after a successful recompute + activity emission.
 *
 * Mirrors the architectural pattern of `emitSettlementActivity`:
 *
 *   - Reads the settlement source data from `changeData` (after
 *     snapshot for create/update; before snapshot fallback for hard
 *     delete) to extract `fromUserId`, `toUserId`, `amountPaise`,
 *     `contextId`. No additional Firestore read is needed for
 *     member resolution — the settlement doc itself carries both
 *     UIDs (security rules at firestore.rules:445-455 require them).
 *   - Reads `users/{fromUserId}` to resolve the payer's displayName
 *     for the notification body.
 *   - Delegates to `deps.notificationsApi.sendSettlementNotification`
 *     which does the per-recipient prefs / tokens / render / send
 *     for the SINGLE recipient (`toUserId`).
 *
 * Containment policy (FR-AC-03 AC-17 + architect §2.9 item 2):
 *
 *   - NEVER rethrows. FCM-emission failures must NOT propagate into
 *     the trigger's success branch (the recompute is already done;
 *     a rethrow would cause Cloud Functions to retry, re-running
 *     the recompute and duplicating notifications on the toUserId).
 *   - When `deps.notificationsApi` or `deps.messaging` is absent,
 *     no-ops silently. Preserves backward-compat with existing
 *     tests and local-dev environments without FCM wiring.
 *
 * V1.0 emission policy parity (architect §2.2): only CREATE events
 * emit FCM notifications. Settlements only update on soft-delete
 * (and hard-delete is rare/unreachable in production); neither
 * should fire a notification — the original create event already
 * notified the payee, and a "deleted" notification has no defined
 * UX in MVP. We short-circuit on non-create changeType.
 */
async function emitSettlementFcm(
  deps: Dependencies,
  params: {
    settlementId: string;
    changeType: ActivityChangeType;
    contextType: ContextType;
    contextIdHash: string;
    settlementIdHash: string;
    eventTime: string;
    changeData: Change<DocumentSnapshot> | undefined;
  },
): Promise<void> {
  const {db, logger, notificationsApi, messaging} = deps;
  const {
    settlementId,
    changeType,
    contextType,
    contextIdHash,
    settlementIdHash,
    eventTime,
    changeData,
  } = params;

  // Architect §2.10 item 7: absent notificationsApi or messaging →
  // silent no-op (backward-compat with existing tests).
  if (!notificationsApi || !messaging) {
    return;
  }

  // V1.0 policy parity with emitSettlementActivity: only CREATE
  // events fire a notification. Update / delete are silent.
  if (changeType !== "create") {
    return;
  }

  try {
    const sourceData = changeData?.after?.exists
      ? (changeData.after.data() as SettlementDocData | undefined)
      : (changeData?.before?.exists ?
          (changeData.before.data() as SettlementDocData | undefined) :
          undefined);
    if (!sourceData) {
      logger.info("fcm_emission_skipped_missing_data", {
        event: "fcm_emission_skipped_missing_data",
        contextType,
        contextIdHash,
        settlementIdHash,
      });
      return;
    }

    const {fromUserId, toUserId, amountPaise, contextId} = sourceData;
    if (!fromUserId || !toUserId) {
      logger.info("fcm_emission_skipped_missing_parties", {
        event: "fcm_emission_skipped_missing_parties",
        contextType,
        contextIdHash,
        settlementIdHash,
      });
      return;
    }

    // Resolve senderName via users/{fromUserId}.displayName.
    const payerSnap = await db.collection("users").doc(fromUserId).get();
    const senderName =
      (payerSnap.exists ?
        (payerSnap.data()?.displayName as string | undefined) :
        undefined) ?? "Someone";

    await notificationsApi.sendSettlementNotification(
      {
        db,
        messaging,
        logger: {
          info: (msg, data) => logger.info(msg, data),
          // See emitExpenseFcm for rationale: Dependencies.logger
          // does not expose `warn`; we promote it to `info` so
          // diagnostic events still land in structured logs.
          warn: (msg, data) => logger.info(msg, data),
          error: (msg, data) => logger.error(msg, data),
        },
      },
      {
        fromUserId,
        toUserId,
        contextType,
        contextId,
        settlementId,
        senderName,
        amountPaise,
        eventTimestamp: new Date(eventTime),
      },
    );
  } catch (err: unknown) {
    // Programmer error in the FCM module — log and absorb.
    // Trigger's success branch is preserved (architect §2.9 item 2).
    logger.error("fcm_emission_internal_error", {
      event: "fcm_emission_internal_error",
      contextType,
      contextIdHash,
      settlementIdHash,
      errorMessage: err instanceof Error ? err.message : "unknown",
    });
  }
}
