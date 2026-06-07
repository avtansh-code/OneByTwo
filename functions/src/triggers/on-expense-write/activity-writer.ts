/**
 * Activity-feed writer for friendship-expense triggers (FR-EX-07).
 *
 * Writes one `activity/{userId}/items/{auto-id}` document per friendship
 * member after every successful expense recompute. Idempotency is
 * INHERITED from the trigger's existing 7-day stale-event drop (per
 * FR-EX-07 architect notes §2.5); in-window redeliveries do duplicate
 * items, which is acceptable v1.0 behaviour.
 *
 * Architect ratification: FR-EX-07 architect notes §2.2, §2.3, §2.4.
 *
 * Module conventions:
 *   - Calls Firestore admin SDK via the injected `db` dependency.
 *   - Logs three structured events: `activity_item_written`,
 *     `activity_item_write_failed`, `activity_emission_completed`.
 *   - Every UID-derived log parameter is SHA-256 truncated via
 *     `hashId()` per ADR-0013 (FR-EX-07 AC-14).
 *   - Per-member write failures are CONTAINED inside the writer's
 *     own try/catch — the trigger's success branch is preserved
 *     (FR-EX-07 architect §2.9 item 2).
 *   - `Promise.allSettled` semantics: one member's failure does NOT
 *     short-circuit the other member's write.
 *
 * @module triggers/on-expense-write/activity-writer
 */

import {FieldValue} from "firebase-admin/firestore";
import {hashId} from "../../utils/id-hash";
import {validateActivityPayload} from "./activity-validator";
import type {ActivityItemType, ActivityPayload} from "./payload-builder";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type {ActivityItemType, ActivityPayload} from "./payload-builder";

/** Minimal logger surface the writer needs. */
export interface ActivityWriterLogger {
  info: (message: string, data?: Record<string, unknown>) => void;
  error: (message: string, data?: Record<string, unknown>) => void;
}

/** Dependencies injected into the writer for testability. */
export interface ActivityWriterDependencies {
  db: FirebaseFirestore.Firestore;
  logger: ActivityWriterLogger;
}

/** Request payload accepted by `writeExpenseActivity`. */
export interface WriteExpenseActivityRequest {
  friendshipId: string;
  expenseId: string;
  eventType: ActivityItemType;
  payload: ActivityPayload;
  memberIds: readonly string[];
}

/** Typed result returned to the trigger handler. */
export interface ActivityEmissionResult {
  membersSucceeded: number;
  membersFailed: number;
}

// ---------------------------------------------------------------------------
// Structured-log event names (FR-EX-07 architect notes §2.4)
// ---------------------------------------------------------------------------

export const EVENT_ACTIVITY_ITEM_WRITTEN = "activity_item_written";
export const EVENT_ACTIVITY_ITEM_WRITE_FAILED = "activity_item_write_failed";
export const EVENT_ACTIVITY_EMISSION_COMPLETED = "activity_emission_completed";

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Writes an activity item per friendship member.
 *
 * - Validates the payload against the per-event-type contract (throws
 *   on programmer error before any Firestore I/O).
 * - Issues per-member writes in parallel via `Promise.allSettled`.
 * - Per-member failures are contained — the writer NEVER rethrows.
 * - Logs `activity_item_written` per success, `activity_item_write_failed`
 *   per failure, and `activity_emission_completed` once per invocation.
 *
 * Idempotency: NONE at the writer level. Inherited from the trigger's
 * stale-event drop per FR-EX-07 architect §2.5.
 */
export async function writeExpenseActivity(
  deps: ActivityWriterDependencies,
  request: WriteExpenseActivityRequest,
): Promise<ActivityEmissionResult> {
  const {db, logger} = deps;
  const {friendshipId, expenseId, eventType, payload, memberIds} = request;

  // 1. Runtime validation — throws on programmer error BEFORE Firestore I/O.
  validateActivityPayload(eventType, payload);

  // 2. PII-safe IDs for structured logging.
  const contextIdHash = hashId(friendshipId);
  const expenseIdHash = hashId(expenseId);
  const authorUidHash = hashId(extractAuthorUid(payload));

  // 3. Defence-in-depth payload-size log parameter.
  const payloadSizeBytes = byteLengthOf(payload);

  // 4. Fan out to each member's subcollection.
  const writeOutcomes = await Promise.allSettled(
    memberIds.map((recipientUid) =>
      writeOneMember(db, recipientUid, eventType, payload),
    ),
  );

  // 5. Per-member structured logging.
  let membersSucceeded = 0;
  let membersFailed = 0;
  writeOutcomes.forEach((outcome, index) => {
    const recipientUid = memberIds[index];
    const recipientUidHash = hashId(recipientUid);

    if (outcome.status === "fulfilled") {
      membersSucceeded += 1;
      logger.info(EVENT_ACTIVITY_ITEM_WRITTEN, {
        event: EVENT_ACTIVITY_ITEM_WRITTEN,
        contextType: "friendship",
        contextIdHash,
        expenseIdHash,
        authorUidHash,
        recipientUidHash,
        eventType,
        payloadSizeBytes,
      });
    } else {
      membersFailed += 1;
      logger.error(EVENT_ACTIVITY_ITEM_WRITE_FAILED, {
        event: EVENT_ACTIVITY_ITEM_WRITE_FAILED,
        contextType: "friendship",
        contextIdHash,
        expenseIdHash,
        authorUidHash,
        recipientUidHash,
        eventType,
        payloadSizeBytes,
        errorCode: extractErrorCode(outcome.reason),
      });
    }
  });

  // 6. Summary log — once per invocation.
  logger.info(EVENT_ACTIVITY_EMISSION_COMPLETED, {
    event: EVENT_ACTIVITY_EMISSION_COMPLETED,
    contextType: "friendship",
    contextIdHash,
    expenseIdHash,
    eventType,
    membersSucceeded,
    membersFailed,
  });

  return {membersSucceeded, membersFailed};
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

async function writeOneMember(
  db: FirebaseFirestore.Firestore,
  recipientUid: string,
  eventType: ActivityItemType,
  payload: ActivityPayload,
): Promise<void> {
  await db
    .collection("activity")
    .doc(recipientUid)
    .collection("items")
    .add({
      type: eventType,
      payload,
      createdAt: FieldValue.serverTimestamp(),
    });
}

/**
 * Pulls `authorUid` from the payload regardless of variant. Every
 * payload variant in the FR-EX-07 contract includes `authorUid` as a
 * required field, so this is a safe accessor.
 */
function extractAuthorUid(payload: ActivityPayload): string {
  return (payload as {authorUid: string}).authorUid;
}

/**
 * Computes a defence-in-depth byte size of the payload. The result is
 * logged as a defensive signal — an unexpectedly large payload would
 * indicate a programmer error (e.g. accidentally embedding a base64
 * receipt blob).
 */
function byteLengthOf(payload: ActivityPayload): number {
  return Buffer.byteLength(JSON.stringify(payload), "utf8");
}

/**
 * Extracts a stable, low-cardinality error code from a Firestore admin
 * SDK rejection. Falls back to `'unknown'` to preserve PII safety on
 * arbitrary thrown values.
 */
function extractErrorCode(reason: unknown): string {
  if (reason !== null && typeof reason === "object") {
    const code = (reason as {code?: unknown}).code;
    if (typeof code === "string") {
      return code;
    }
  }
  return "unknown";
}
