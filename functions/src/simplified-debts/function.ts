/**
 * Simplified Debts — Function Boundary (HTTPS Callable Handler)
 *
 * Validates input, reads Firestore, runs the simplified-debts algorithm,
 * writes `simplifiedBalances` back to the context document, and returns
 * the result to the caller.
 *
 * Error codes follow docs/design/07-technical/cloud-functions-error-codes.md.
 * All monetary values are integer paise (Invariant 1).
 * The `simplifiedBalances` field is written only by this function (Invariant 2).
 *
 * @module simplified-debts/function
 */

import {HttpsError} from "firebase-functions/v2/https";
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

/** Shape of the successful response. */
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
}

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
// Net-balance computation from expenses
// ---------------------------------------------------------------------------

/**
 * Computes net balances from a list of expense document snapshots.
 *
 * For each expense the payer is credited +amountPaise and each split member
 * is debited -sharePaise. All values are integer paise (Invariant 1).
 */
function computeNetBalances(
  expenseSnapshots: FirebaseFirestore.QueryDocumentSnapshot[],
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

  return netBalances;
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the HTTPS Callable handler with injected dependencies.
 *
 * @param deps - Firestore database and logger instances.
 * @returns An async handler function that validates input, computes
 *   simplified debts, writes the result to Firestore, and returns the
 *   response.
 */
export function createHandler(
  deps: Dependencies,
): (data: unknown) => Promise<RecomputeResponse> {
  const {db, logger} = deps;

  return async (data: unknown): Promise<RecomputeResponse> => {
    const startTime = Date.now();

    // 1. Validate input (throws HttpsError on failure)
    const {contextType, contextId} = validateInput(data);

    // 2. Log started event (no PII)
    logger.info("simplified_debts_compute_started", {
      event: "simplified_debts_compute_started",
      contextType,
      contextId,
    });

    try {
      const collectionName = contextCollectionName(contextType);
      const contextRef = db.collection(collectionName).doc(contextId);

      // 3. Run inside a Firestore transaction
      const result = await db.runTransaction(async (tx) => {
        // Read context document
        const contextSnap = await tx.get(contextRef);
        if (!contextSnap.exists) {
          throw new HttpsError(
            "not-found",
            `Context ${contextType}/${contextId} not found.`,
            {errorCode: ERROR_CONTEXT_NOT_FOUND},
          );
        }

        // Read non-deleted expenses
        const expensesRef = contextRef
          .collection("expenses")
          .where("deleted", "!=", true);
        const expensesSnap = await tx.get(expensesRef);

        // Compute net balances from expenses
        const netBalances = computeNetBalances(expensesSnap.docs);

        // Run the simplified-debts algorithm
        const transfers = simplifyDebts(netBalances);

        // Project to the Firestore map shape
        const simplifiedBalances = projectToBalancesMap(transfers);

        // Write simplified balances back to context document
        tx.update(contextRef, {simplifiedBalances});

        return {transfers, simplifiedBalances};
      });

      const computedAt = new Date().toISOString();

      // 4. Log completed event (no PII — no userId values or amounts)
      logger.info("simplified_debts_compute_completed", {
        event: "simplified_debts_compute_completed",
        contextType,
        contextId,
        elapsedMs: Date.now() - startTime,
        transferCount: result.transfers.length,
      });

      // 5. Return response
      return {
        ok: true,
        transfers: result.transfers,
        simplifiedBalances: result.simplifiedBalances,
        computedAt,
      };
    } catch (err: unknown) {
      // Re-throw HttpsError instances directly (already typed)
      if (err instanceof HttpsError) {
        logger.error("simplified_debts_compute_failed", {
          event: "simplified_debts_compute_failed",
          contextType,
          contextId,
          errorCode:
            (
              (err as HttpsError & {details?: {errorCode?: string}})
                .details as {errorCode?: string} | undefined
            )?.errorCode ?? err.code,
          elapsedMs: Date.now() - startTime,
        });
        throw err;
      }

      // Map balance invariant violations
      if (
        err instanceof Error &&
        err.message.includes("Balance invariant violation")
      ) {
        logger.error("simplified_debts_compute_failed", {
          event: "simplified_debts_compute_failed",
          contextType,
          contextId,
          errorCode: ERROR_BALANCE_INVARIANT_VIOLATED,
          elapsedMs: Date.now() - startTime,
        });
        throw new HttpsError(
          "internal",
          "Balance invariant violated during computation.",
          {errorCode: ERROR_BALANCE_INVARIANT_VIOLATED},
        );
      }

      // Catch-all: map to INTERNAL
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
  };
}
