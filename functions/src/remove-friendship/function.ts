/**
 * FR-FR-05 Remove Friend — Callable Handler Boundary.
 *
 * HTTPS Callable that permanently removes a friendship the authenticated
 * caller belongs to (SRS section 4.5; design screen 13). Clients have NO
 * delete path: `firestore.rules` keeps `allow delete: if false` on
 * `friendships/{id}`, and a friendship owns an `expenses` subcollection that a
 * client delete could never recurse into. Removal therefore runs as a
 * region-pinned callable that validates server-side and `recursiveDelete`s the
 * document plus its subtree under the Admin SDK (which bypasses Security Rules
 * by design), exactly like FR-AU-09 account deletion (ADR-0016).
 *
 * Handler flow:
 *   1. Auth check (UNAUTHENTICATED) — FIRST, before any read.
 *   2. Input validation: `friendshipId` is a non-empty `a_b` string
 *      (INVALID_INPUT). Rejecting `/` is load-bearing — see
 *      FRIENDSHIP_ID_REGEX.
 *   3. Load `friendships/{friendshipId}`; absent -> FRIENDSHIP_NOT_FOUND.
 *   4. Authorization: caller uid MUST be in `memberIds` -> else NOT_A_MEMBER.
 *   5. Balance gate (load-bearing): READ the server `simplifiedBalances`
 *      projection; ANY non-zero entry -> FRIENDSHIP_NOT_SETTLED. Absent or
 *      empty is settled (allowed). The balance is NEVER recomputed here.
 *   6. `recursiveDelete` the friendship doc + its `expenses` subtree.
 *   7. Return `{ success: true }`.
 *
 * Invariant compliance:
 *   - Inv-1 (paise integer): N/A for arithmetic — the balance gate only
 *     compares leaf paise integers against zero; no money math, no conversion.
 *   - Inv-2 (simplifiedBalances server-only): the callable READS the
 *     projection for the settled-up precondition and NEVER writes it. The sole
 *     writer remains the simplified-debts recompute core
 *     (`functions/src/simplified-debts/function.ts`). Removing the whole
 *     document deletes its `simplifiedBalances` along with everything else —
 *     that is the document's removal, not a field write.
 *
 * Structured-log events (PII-safe — friendship IDs are `{uidA}_{uidB}`, so
 * they are hashed via `hashId` per ADR-0013 before logging):
 *   - remove_friendship_started
 *   - remove_friendship_succeeded
 *   - remove_friendship_failed
 *
 * Error codes follow docs/design/07-technical/cloud-functions-error-codes.md.
 *
 * @module remove-friendship/function
 */

import {HttpsError} from "firebase-functions/v2/https";
import {hashId} from "../utils/id-hash";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Deterministic friendship-ID shape: two non-empty UID segments — neither
 * containing an underscore or slash — joined by a single underscore
 * (`{uidA}_{uidB}`, sorted ascending; see `FriendshipRepository` /
 * `firestore.rules`). Rejecting `/` is load-bearing: a slash in the ID would
 * let `.doc(friendshipId)` resolve to an arbitrary nested document path
 * (path traversal). The system already assumes UIDs never contain `_` (the
 * deterministic ID would otherwise be ambiguous), so this is precise.
 */
const FRIENDSHIP_ID_REGEX = /^[^_/]+_[^_/]+$/;

/**
 * Hard cap on the accepted `friendshipId` length. A friendship ID is at most
 * two 128-char Firebase UIDs plus one underscore (257 chars); 1500 is the
 * Firestore document-ID byte limit and a comfortable defensive bound.
 */
const MAX_FRIENDSHIP_ID_LENGTH = 1500;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Shape of the successful callable response. */
export interface RemoveFriendshipResponse {
  success: true;
}

/** Structured logger surface (subset of firebase-functions/logger). */
export interface RemoveFriendshipLogger {
  info: (message: string, data?: Record<string, unknown>) => void;
  warn: (message: string, data?: Record<string, unknown>) => void;
  error: (message: string, data?: Record<string, unknown>) => void;
}

/** Dependencies injected into the handler for testability. */
export interface RemoveFriendshipFunctionDeps {
  db: FirebaseFirestore.Firestore;
  logger: RemoveFriendshipLogger;
}

/** The caller context the handler reads (auth uid only). */
export interface RemoveFriendshipContext {
  auth?: {uid: string};
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Returns true when the server `simplifiedBalances` projection carries any
 * outstanding (non-zero) amount, i.e. the friendship is NOT fully settled.
 *
 * The projection shape is `{ [debtorUid]: { [creditorUid]: paiseInt } }`
 * (see simplified-debts/algorithm.ts `projectToBalancesMap`). Absent, empty,
 * or malformed data is treated as SETTLED (returns false) — mirroring the
 * client parser (`FriendshipDoc._parseSimplifiedBalances`) which renders such
 * data as "settled up", and Invariant 2 guarantees the server only ever
 * writes a well-formed map. This function only READS the projection; it never
 * recomputes or writes it.
 *
 * @param raw - The raw `simplifiedBalances` field from the friendship doc.
 * @returns True if any leaf amount is a non-zero number; false otherwise.
 */
export function hasOutstandingBalance(raw: unknown): boolean {
  if (raw === null || typeof raw !== "object") {
    return false;
  }
  const outer = raw as Record<string, unknown>;
  for (const debtorUid of Object.keys(outer)) {
    const inner = outer[debtorUid];
    if (inner === null || typeof inner !== "object") {
      continue;
    }
    const creditors = inner as Record<string, unknown>;
    for (const creditorUid of Object.keys(creditors)) {
      const amountPaise = creditors[creditorUid];
      if (typeof amountPaise === "number" && amountPaise !== 0) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Redacts the raw `friendshipId` from an error message before it is logged.
 * SDK error messages can embed the document path (e.g.
 * `friendships/{uidA}_{uidB}`), which would leak the two member UIDs into
 * Cloud Logging and defeat the hashing applied everywhere else (ADR-0013 /
 * SRS section 5.4). All occurrences are replaced with the hash.
 */
function redactFriendshipId(
  message: string,
  friendshipId: string,
  friendshipIdHash: string,
): string {
  if (friendshipId.length === 0) return message;
  return message.split(friendshipId).join(`friendship#${friendshipIdHash}`);
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the HTTPS Callable handler with injected dependencies.
 *
 * Input: `{ friendshipId: string }` — the deterministic `{uidA}_{uidB}` ID.
 * Output: `{ success: true }`.
 *
 * @param deps - Firestore database and logger instances.
 * @returns An async handler function compatible with the `onCall` wrapper.
 */
export function createRemoveFriendshipHandler(
  deps: RemoveFriendshipFunctionDeps,
): (
  data: unknown,
  context: RemoveFriendshipContext,
) => Promise<RemoveFriendshipResponse> {
  const {db, logger} = deps;

  return async (
    data: unknown,
    context: RemoveFriendshipContext,
  ): Promise<RemoveFriendshipResponse> => {
    // 1. Auth check (FIRST, before any read).
    const callerUid = context.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Authentication required.", {
        errorCode: "UNAUTHENTICATED",
      });
    }

    // 2. Input validation. The `a_b` shape + no-slash guard rejects obviously
    //    malformed input early AND prevents a slash from steering
    //    `.doc(friendshipId)` to an arbitrary nested document path.
    const obj = (data ?? {}) as Record<string, unknown>;
    const friendshipId = obj.friendshipId;
    if (
      typeof friendshipId !== "string" ||
      friendshipId.length === 0 ||
      friendshipId.length > MAX_FRIENDSHIP_ID_LENGTH ||
      !FRIENDSHIP_ID_REGEX.test(friendshipId)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "friendshipId must be a non-empty 'a_b' string.",
        {errorCode: "INVALID_INPUT"},
      );
    }

    const callerUidHash = hashId(callerUid);
    const friendshipIdHash = hashId(friendshipId);

    logger.info("remove_friendship_started", {
      event: "remove_friendship_started",
      callerUidHash,
      friendshipIdHash,
    });

    try {
      // 3. Load the friendship document.
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      const snap = await friendshipRef.get();

      if (!snap.exists) {
        logger.warn("remove_friendship_failed", {
          event: "remove_friendship_failed",
          callerUidHash,
          friendshipIdHash,
          errorCode: "FRIENDSHIP_NOT_FOUND",
        });
        throw new HttpsError("not-found", "Friendship not found.", {
          errorCode: "FRIENDSHIP_NOT_FOUND",
        });
      }

      const friendshipData = (snap.data() ?? {}) as Record<string, unknown>;

      // 4. Authorization — the caller must be one of the two members. The
      //    Admin SDK bypasses Security Rules, so this membership check is the
      //    authoritative gate (not the rules).
      const memberIds = Array.isArray(friendshipData.memberIds) ?
        (friendshipData.memberIds as unknown[]) :
        [];
      if (!memberIds.includes(callerUid)) {
        logger.warn("remove_friendship_failed", {
          event: "remove_friendship_failed",
          callerUidHash,
          friendshipIdHash,
          errorCode: "NOT_A_MEMBER",
        });
        throw new HttpsError(
          "permission-denied",
          "Caller is not a member of this friendship.",
          {errorCode: "NOT_A_MEMBER"},
        );
      }

      // 5. Balance gate — the friendship must be fully settled. READ-ONLY:
      //    the `simplifiedBalances` projection is never recomputed or written
      //    here (Invariant 2). Absent / empty / all-zero is settled (allowed).
      if (hasOutstandingBalance(friendshipData.simplifiedBalances)) {
        logger.warn("remove_friendship_failed", {
          event: "remove_friendship_failed",
          callerUidHash,
          friendshipIdHash,
          errorCode: "FRIENDSHIP_NOT_SETTLED",
        });
        throw new HttpsError(
          "failed-precondition",
          "Settle up before removing this friend.",
          {errorCode: "FRIENDSHIP_NOT_SETTLED"},
        );
      }

      // 6. recursiveDelete the friendship doc + its `expenses` subtree. The
      //    Admin SDK bypasses the client `allow delete: if false` rule by
      //    design; recursiveDelete uses a BulkWriter under the hood (handles
      //    the 500-write WriteBatch cap) and is a no-op on an absent path.
      await db.recursiveDelete(friendshipRef);

      logger.info("remove_friendship_succeeded", {
        event: "remove_friendship_succeeded",
        callerUidHash,
        friendshipIdHash,
      });
      return {success: true};
    } catch (err: unknown) {
      if (err instanceof HttpsError) {
        throw err;
      }
      logger.error("remove_friendship_failed", {
        event: "remove_friendship_failed",
        callerUidHash,
        friendshipIdHash,
        errorCode: "INTERNAL",
        errorMessage: redactFriendshipId(
          err instanceof Error ? err.message : String(err),
          friendshipId,
          friendshipIdHash,
        ),
      });
      throw new HttpsError(
        "internal",
        "Friendship could not be removed. Please try again.",
        {errorCode: "INTERNAL"},
      );
    }
  };
}
