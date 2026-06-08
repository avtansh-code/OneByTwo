/**
 * Simplified Debts — Function Boundary
 *
 * Provides two layered entry points:
 *
 *   1. `recomputeAndWrite(deps, request)` — shared core. Reads the context
 *      document and its active expenses inside a Firestore transaction,
 *      runs the simplified-debts algorithm, and writes the resulting
 *      `simplifiedBalances` map (plus any caller-provided `alsoSet` fields)
 *      back to the context document in the same transaction. Returns a
 *      typed discriminated union — never throws `HttpsError` itself.
 *      Consumed by BOTH the HTTPS Callable handler AND the
 *      `onExpenseWriteFriendship` trigger (FR-SE-03/04).
 *
 *   2. `createHandler(deps)` — HTTPS Callable handler. Validates client
 *      input, delegates to `recomputeAndWrite`, maps documented failure
 *      codes to `HttpsError`, and emits structured telemetry.
 *
 * Error codes follow `docs/design/07-technical/cloud-functions-error-codes.md`.
 * All monetary values are integer paise (Invariant 1).
 * The `simplifiedBalances` field is written only by `recomputeAndWrite`
 * (Invariant 2 — server-side writer).
 *
 * @module simplified-debts/function
 */

import {HttpsError} from "firebase-functions/v2/https";
import {Timestamp} from "firebase-admin/firestore";
import {
  simplifyDebts,
  projectToBalancesMap,
  Transfer,
  SimplifiedBalancesMap,
} from "./algorithm";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Valid context types for the recomputation callable. */
export type ContextType = "friendship" | "group";

/** Shape of the input data for the callable. */
export interface RecomputeInput {
  contextType: ContextType;
  contextId: string;
}

/** Shape of the successful callable response. */
export interface RecomputeResponse {
  ok: true;
  transfers: Transfer[];
  simplifiedBalances: SimplifiedBalancesMap;
  computedAt: string;
}

/** Dependencies injected into the handler for testability. */
export interface Dependencies {
  db: FirebaseFirestore.Firestore;
  logger: {
    info: (message: string, data?: Record<string, unknown>) => void;
    error: (message: string, data?: Record<string, unknown>) => void;
  };
  /**
   * Optional FCM notifications API (FR-AC-03 — architect §2.10 item 7).
   *
   * Trigger entry points wire this when push notifications should be
   * emitted as a side effect of the trigger's success branch. When
   * absent, the trigger's FCM emitter helpers no-op silently — this
   * preserves backward-compatibility with existing tests that wire
   * `Dependencies` without the FCM surface.
   *
   * `simplifiedBalances` recomputation itself does NOT use this field
   * — it is consumed exclusively by `emitExpenseFcm` /
   * `emitSettlementFcm` in the trigger handlers.
   */
  notificationsApi?:
    import("../notifications").NotificationsApi;
  /**
   * Optional admin SDK `Messaging` instance (FR-AC-03). Paired with
   * `notificationsApi`; the trigger constructs a
   * `NotificationsDependencies` shape from `db + logger + messaging`
   * before delegating into the FCM module.
   */
  messaging?:
    import("firebase-admin/messaging").Messaging;
}

/**
 * Request payload for the shared `recomputeAndWrite` core.
 *
 * `alsoSet` permits callers to atomically write additional fields on the
 * context document inside the same `tx.update(...)` call as
 * `simplifiedBalances`. The trigger uses this to write
 * `lastActivityAt` (FR-SE-03/04 AC-6). The callable currently passes
 * nothing (or an empty object), so its behaviour is unchanged.
 *
 * Reserved key: `lastActivityAt`. When present in `alsoSet`, the core
 * applies a MONOTONICITY GUARD — the value actually written is
 * `max(existingLastActivityAt, alsoSet.lastActivityAt)`. This prevents
 * out-of-order Cloud Functions delivery from regressing the friends-list
 * ordering. No other reserved keys exist today.
 */
export interface RecomputeRequest {
  contextType: ContextType;
  contextId: string;
  alsoSet?: Record<string, unknown>;
}

/**
 * Typed result returned by `recomputeAndWrite`. The shared core never
 * throws `HttpsError`; instead it returns this discriminated union so
 * the callable wrapper can map failures to `HttpsError` and the trigger
 * wrapper can apply its own log-and-return-vs-retry policy.
 *
 * Unknown errors (transient Firestore contention, runtime exceptions)
 * are NOT caught inside the core — they bubble up so the caller can
 * apply the appropriate INTERNAL mapping or retry semantics.
 */
export type RecomputeResult =
  | {
      ok: true;
      transfers: Transfer[];
      simplifiedBalances: SimplifiedBalancesMap;
    }
  | {
      ok: false;
      code: "CONTEXT_NOT_FOUND" | "BALANCE_INVARIANT_VIOLATED";
    };

// ---------------------------------------------------------------------------
// Error codes (from cloud-functions-error-codes.md)
// ---------------------------------------------------------------------------

const ERROR_INVALID_INPUT = "INVALID_INPUT";
const ERROR_CONTEXT_NOT_FOUND = "CONTEXT_NOT_FOUND";
const ERROR_BALANCE_INVARIANT_VIOLATED = "BALANCE_INVARIANT_VIOLATED";
const ERROR_INTERNAL = "INTERNAL";

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

const VALID_CONTEXT_TYPES: ReadonlySet<string> = new Set([
  "friendship",
  "group",
]);

/**
 * Validates and narrows raw callable input to RecomputeInput.
 * Throws HttpsError with INVALID_INPUT if validation fails.
 */
function validateInput(data: unknown): RecomputeInput {
  if (data === null || data === undefined || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Input must be an object.", {
      errorCode: ERROR_INVALID_INPUT,
    });
  }

  const obj = data as Record<string, unknown>;

  if (
    typeof obj.contextType !== "string" ||
    !VALID_CONTEXT_TYPES.has(obj.contextType)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "contextType must be 'friendship' or 'group'.",
      {errorCode: ERROR_INVALID_INPUT},
    );
  }

  if (typeof obj.contextId !== "string" || obj.contextId.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "contextId must be a non-empty string.",
      {errorCode: ERROR_INVALID_INPUT},
    );
  }

  return {
    contextType: obj.contextType as ContextType,
    contextId: obj.contextId,
  };
}

// ---------------------------------------------------------------------------
// Firestore path helpers
// ---------------------------------------------------------------------------

function contextCollectionName(contextType: ContextType): string {
  return contextType === "friendship" ? "friendships" : "groups";
}

// ---------------------------------------------------------------------------
// Net-balance computation from expenses AND settlements
// ---------------------------------------------------------------------------

/**
 * Computes net balances from a list of expense AND settlement document
 * snapshots.
 *
 * Expense semantics: the payer is credited +amountPaise and each split
 * member is debited -sharePaise. All values are integer paise (Invariant 1).
 *
 * Settlement semantics (FR-SE-05/06): a settlement of
 * `{fromUserId: A, toUserId: B, amountPaise: N}` represents A paying B N
 * paise in cash. This CREDITS A's net balance (+N — A's debt is reduced)
 * and DEBITS B's net balance (-N — B is now owed less). Combined with the
 * expense fold, the zero-sum invariant is preserved by construction (every
 * transaction is internally balanced).
 *
 * In-code soft-delete filter: settlements with `deleted === true` are
 * excluded from the fold. The expense query already applies the
 * `where('deleted', '!=', true)` filter at the Firestore level; the
 * settlements query reads ALL matching docs and filters in code to
 * avoid an unnecessary composite-index requirement (see Architect Notes
 * §2 of FR-SE-05-06 story).
 *
 * Exported for direct exercise by `algorithm.property.test.ts`. The
 * production callers (`recomputeAndWrite`) call it through the
 * transaction-scoped read sequence below.
 */
export function computeNetBalances(
  expenseSnapshots: FirebaseFirestore.QueryDocumentSnapshot[],
  settlementSnapshots: FirebaseFirestore.QueryDocumentSnapshot[] = [],
): Map<string, number> {
  const netBalances = new Map<string, number>();

  for (const snap of expenseSnapshots) {
    const data = snap.data();
    const payerId: string = data.payerId;
    const amountPaise: number = data.amountPaise;
    const splits: Array<{userId: string; sharePaise: number}> =
      data.splits ?? [];

    // Credit the payer
    netBalances.set(payerId, (netBalances.get(payerId) ?? 0) + amountPaise);

    // Debit each split member
    for (const split of splits) {
      netBalances.set(
        split.userId,
        (netBalances.get(split.userId) ?? 0) - split.sharePaise,
      );
    }
  }

  for (const snap of settlementSnapshots) {
    const data = snap.data();
    if (data.deleted === true) {
      // In-code soft-delete filter — see function doc above.
      continue;
    }
    const fromUserId: string = data.fromUserId;
    const toUserId: string = data.toUserId;
    const amountPaise: number = data.amountPaise;

    // Credit the payer (the fromUserId), debit the recipient (the toUserId).
    netBalances.set(
      fromUserId,
      (netBalances.get(fromUserId) ?? 0) + amountPaise,
    );
    netBalances.set(toUserId, (netBalances.get(toUserId) ?? 0) - amountPaise);
  }

  return netBalances;
}

// ---------------------------------------------------------------------------
// Monotonicity guard for lastActivityAt
// ---------------------------------------------------------------------------

/**
 * Returns the LATER of two timestamps. Used to enforce monotonicity on
 * `lastActivityAt` writes — out-of-order Cloud Functions delivery must
 * never regress the friends-list ordering.
 *
 * Falls back to `next` when `existing` is missing or not a Timestamp.
 */
function laterTimestamp(
  existing: unknown,
  next: Timestamp,
): Timestamp {
  if (!(existing instanceof Timestamp)) {
    return next;
  }
  return existing.toMillis() >= next.toMillis() ? existing : next;
}

/**
 * Applies the monotonicity guard to an `alsoSet` payload. Returns a new
 * object where `lastActivityAt` (if present) is replaced with
 * `max(existing.lastActivityAt, alsoSet.lastActivityAt)`. Other keys are
 * passed through unchanged.
 */
function applyMonotonicityGuard(
  existingData: FirebaseFirestore.DocumentData,
  alsoSet: Record<string, unknown> | undefined,
): Record<string, unknown> {
  if (!alsoSet || alsoSet.lastActivityAt === undefined) {
    return {...(alsoSet ?? {})};
  }
  const incoming = alsoSet.lastActivityAt;
  if (!(incoming instanceof Timestamp)) {
    // Caller passed something that isn't a Timestamp — pass through
    // unchanged and let Firestore reject it.
    return {...alsoSet};
  }
  return {
    ...alsoSet,
    lastActivityAt: laterTimestamp(existingData.lastActivityAt, incoming),
  };
}

// ---------------------------------------------------------------------------
// Shared core — recomputeAndWrite
// ---------------------------------------------------------------------------

/**
 * Reserved keys in the `alsoSet` payload — fields written by the core
 * itself MUST NOT be overrideable by callers. `simplifiedBalances` is
 * the load-bearing Invariant-2 field.
 */
const ALSO_SET_RESERVED_KEYS = new Set<string>(["simplifiedBalances"]);

/**
 * Reads the context document and its non-deleted expenses inside a
 * Firestore transaction, runs the simplified-debts algorithm, and writes
 * `simplifiedBalances` (plus any caller-provided `alsoSet` fields) back
 * to the context document in the SAME transaction.
 *
 * Returns a typed result; never throws `HttpsError` directly. Unknown
 * errors bubble up so callers can map them to their own error semantics.
 *
 * @param deps - Firestore database and logger.
 * @param request - Context discriminator, ID, and optional `alsoSet`.
 * @returns Either a successful result with transfers and balances, or a
 *   failure result with a typed `code`.
 * @throws Error when `alsoSet` contains a reserved key (e.g.
 *   `simplifiedBalances`) — defence-in-depth against accidental writes.
 *   Also throws if `alsoSet.lastActivityAt` is present but not a
 *   `Timestamp`.
 */
export async function recomputeAndWrite(
  deps: Dependencies,
  request: RecomputeRequest,
): Promise<RecomputeResult> {
  const {db} = deps;
  const {contextType, contextId, alsoSet} = request;

  // Defence-in-depth: reject reserved keys before opening a transaction.
  if (alsoSet) {
    for (const key of Object.keys(alsoSet)) {
      if (ALSO_SET_RESERVED_KEYS.has(key)) {
        throw new Error(
          `recomputeAndWrite: alsoSet must not contain reserved key '${key}' ` +
            `(it is the core's responsibility to write this field).`,
        );
      }
    }
    if (
      alsoSet.lastActivityAt !== undefined &&
      !(alsoSet.lastActivityAt instanceof Timestamp)
    ) {
      throw new Error(
        "recomputeAndWrite: alsoSet.lastActivityAt must be a Firestore " +
          "Timestamp (received: " + typeof alsoSet.lastActivityAt + ").",
      );
    }
  }

  const collectionName = contextCollectionName(contextType);
  const contextRef = db.collection(collectionName).doc(contextId);

  return db.runTransaction(async (tx) => {
    const contextSnap = await tx.get(contextRef);
    if (!contextSnap.exists) {
      return {ok: false as const, code: "CONTEXT_NOT_FOUND" as const};
    }

    // Read active expenses from the context subcollection. The expense
    // collection's `where('deleted', '!=', true)` server-side filter is
    // sufficient because no other equality filters are combined with it.
    const expensesRef = contextRef
      .collection("expenses")
      .where("deleted", "!=", true);

    // Read settlements for this context from the TOP-LEVEL settlements
    // collection (FR-SE-05/06). Settlements carry their context
    // discriminator in the doc data — not the path — because a single
    // settlement could in principle move between contexts (it cannot in
    // v1.0 — immutable contextType/contextId per security rules — but
    // the schema design preserves the option).
    //
    // The query uses TWO equality filters: contextType + contextId.
    // The soft-delete filter is applied IN CODE inside
    // `computeNetBalances` to avoid a three-field composite index
    // requirement (cross-field == + == + != combinations require
    // declaring the inequality field as part of the index, which
    // unnecessarily over-specifies the index for the small per-context
    // settlement volume seen in v1.0).
    const settlementsRef = db
      .collection("settlements")
      .where("contextType", "==", contextType)
      .where("contextId", "==", contextId);

    const [expensesSnap, settlementsSnap] = await Promise.all([
      tx.get(expensesRef),
      tx.get(settlementsRef),
    ]);

    const netBalances = computeNetBalances(
      expensesSnap.docs,
      settlementsSnap.docs,
    );

    let transfers: Transfer[];
    try {
      transfers = simplifyDebts(netBalances);
    } catch (err: unknown) {
      if (
        err instanceof Error &&
        err.message.includes("Balance invariant violation")
      ) {
        return {
          ok: false as const,
          code: "BALANCE_INVARIANT_VIOLATED" as const,
        };
      }
      throw err;
    }

    const simplifiedBalances = projectToBalancesMap(transfers);

    const guardedAlsoSet = applyMonotonicityGuard(
      contextSnap.data() ?? {},
      alsoSet,
    );

    // Defence-in-depth: place the computed `simplifiedBalances` LAST in
    // the spread so it cannot be overwritten by a malformed `alsoSet`.
    // The core is the sole writer of this field (Invariant 2) — any
    // caller-supplied `simplifiedBalances` in `alsoSet` is ignored by
    // the spread order, AND would have been rejected by the explicit
    // reserved-keys guard above.
    tx.update(contextRef, {...guardedAlsoSet, simplifiedBalances});

    return {ok: true as const, transfers, simplifiedBalances};
  });
}

// ---------------------------------------------------------------------------
// Callable handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the HTTPS Callable handler with injected dependencies.
 *
 * Validates input, delegates compute+write to `recomputeAndWrite`, maps
 * typed failure codes to `HttpsError`, and emits structured telemetry.
 *
 * @param deps - Firestore database and logger.
 * @returns An async handler function suitable for `onCall(..., handler)`.
 */
export function createHandler(
  deps: Dependencies,
): (data: unknown) => Promise<RecomputeResponse> {
  const {logger} = deps;

  return async (data: unknown): Promise<RecomputeResponse> => {
    const startTime = Date.now();

    const {contextType, contextId} = validateInput(data);

    logger.info("simplified_debts_compute_started", {
      event: "simplified_debts_compute_started",
      contextType,
      contextId,
    });

    let result: RecomputeResult;
    try {
      result = await recomputeAndWrite(deps, {contextType, contextId});
    } catch {
      // INTERNAL — any unknown error from the shared core. Log and map
      // to HttpsError("internal", INTERNAL). Trigger callers map this
      // path to a re-thrown error so Cloud Functions retries.
      logger.error("simplified_debts_compute_failed", {
        event: "simplified_debts_compute_failed",
        contextType,
        contextId,
        errorCode: ERROR_INTERNAL,
        elapsedMs: Date.now() - startTime,
      });
      throw new HttpsError(
        "internal",
        "An unexpected error occurred during computation.",
        {errorCode: ERROR_INTERNAL},
      );
    }

    if (!result.ok) {
      logger.error("simplified_debts_compute_failed", {
        event: "simplified_debts_compute_failed",
        contextType,
        contextId,
        errorCode: result.code,
        elapsedMs: Date.now() - startTime,
      });
      if (result.code === "CONTEXT_NOT_FOUND") {
        throw new HttpsError(
          "not-found",
          `Context ${contextType}/${contextId} not found.`,
          {errorCode: ERROR_CONTEXT_NOT_FOUND},
        );
      }
      // BALANCE_INVARIANT_VIOLATED
      throw new HttpsError(
        "internal",
        "Balance invariant violated during computation.",
        {errorCode: ERROR_BALANCE_INVARIANT_VIOLATED},
      );
    }

    const computedAt = new Date().toISOString();

    logger.info("simplified_debts_compute_completed", {
      event: "simplified_debts_compute_completed",
      contextType,
      contextId,
      elapsedMs: Date.now() - startTime,
      transferCount: result.transfers.length,
    });

    return {
      ok: true,
      transfers: result.transfers,
      simplifiedBalances: result.simplifiedBalances,
      computedAt,
    };
  };
}
