/**
 * FR-AU-09 Delete Account — Callable Handler Boundary.
 *
 * HTTPS Callable that permanently deletes the authenticated caller's
 * account (SRS section 4.1, line 168). It runs a synchronous cascade via
 * the Admin SDK — clients have NO delete path (Firestore Security Rules
 * keep `allow delete: if false` for users/friendships/settlements; the
 * Admin SDK bypasses rules by design). See ADR-0016.
 *
 * Data-fate matrix (ADR-0016):
 *
 *   - DELETE (personal): `activity/{uid}` + `items/**`; `_rateLimits/{uid}/**`;
 *     the Storage object `avatars/{uid}`; the Firebase Auth record (LAST).
 *   - TOMBSTONE (identity): `users/{uid}` is REPLACED with the PII-free shell
 *     `{ displayName: 'Deleted User', deletedAt }`, stripping phoneNumber,
 *     photoUrl, fcmTokens, notificationPrefs and locale. This single write is
 *     the anonymisation.
 *   - PRESERVE / no-op (shared): friendships the user belongs to, their
 *     expenses, related settlements, and receipts are UNTOUCHED — the
 *     surviving member keeps their exact balance and history.
 *
 * Invariant compliance:
 *   - Inv-1 (paise integer): N/A — no monetary surface; no balance is read,
 *     written, or converted.
 *   - Inv-2 (simplifiedBalances server-only): the cascade NEVER recomputes,
 *     zeroes, or strips `simplifiedBalances` on a surviving friendship. The
 *     sole writer of those values remains the recompute core
 *     (`functions/src/simplified-debts/function.ts`). Anonymisation is
 *     delivered entirely by the users-doc tombstone.
 *
 * Idempotency (SCR-28 edge cases 3/4): the client may time out or force-quit
 * while the cascade runs server-side. Every step treats already-absent state
 * as success (`recursiveDelete` no-ops on an absent path; the tombstone
 * `set()` is repeatable; an absent avatar / `auth/user-not-found` are
 * swallowed), so a re-run converges. Step order is Firestore -> Storage ->
 * Auth LAST: while the Auth record exists the caller can re-authenticate and
 * retry; once it is gone the account is unreachable.
 *
 * Structured-log events (PII-safe — only `uidHash` via hashId, ADR-0013):
 *   - delete_account_cascade_started
 *   - delete_account_cascade_succeeded
 *   - delete_account_cascade_failed
 *   - delete_account_reauth_required
 *   - delete_account_avatar_absent
 *   - delete_account_auth_absent
 *
 * Error codes follow docs/design/07-technical/cloud-functions-error-codes.md
 * (section 2.6): UNAUTHENTICATED, REAUTH_REQUIRED, INTERNAL.
 *
 * @module delete-user-account/function
 */

import {HttpsError} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";
import {hashId} from "../utils/id-hash";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Display name written to the PII-free users-doc tombstone (SCR-28 Step A
 * copy / ADR-0016). The client's existing `displayName ?? 'Unknown'`
 * fallback resolves this to "Deleted User" with no client change, while a
 * genuinely absent users-doc still renders "Unknown".
 */
const TOMBSTONE_DISPLAY_NAME = "Deleted User";

/**
 * Maximum age of the caller's last authentication (`auth_time` claim) for a
 * deletion to proceed. SCR-28 Step B re-authentication refreshes this claim;
 * enforcing it server-side makes the re-auth gate defence-in-depth rather
 * than client-only (ADR-0016). Five minutes comfortably covers the
 * re-auth -> type-DELETE -> call window while rejecting a stale token.
 */
const REAUTH_MAX_AGE_MS = 5 * 60 * 1000;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Shape of the successful callable response. */
export interface DeleteUserAccountResponse {
  success: true;
}

/**
 * The Admin Auth surface the cascade needs — just user deletion. Injected
 * for testability; production passes the real `getAuth()` instance.
 */
export interface DeleteUserAccountAuth {
  deleteUser(uid: string): Promise<void>;
}

/**
 * A deletable Storage object handle. Mirrors the subset of the Admin SDK
 * `File` API the cascade uses, so production can pass a real bucket `File`
 * and tests can pass a stub.
 */
export interface DeletableStorageObject {
  delete(options?: {ignoreNotFound?: boolean}): Promise<unknown>;
}

/**
 * The Storage bucket surface the cascade needs — resolve a single object by
 * path. Production passes `getStorage().bucket()`; tests pass a stub.
 */
export interface DeleteUserAccountBucket {
  file(path: string): DeletableStorageObject;
}

/** Structured logger surface (subset of firebase-functions/logger). */
export interface DeleteUserAccountLogger {
  info: (message: string, data?: Record<string, unknown>) => void;
  warn: (message: string, data?: Record<string, unknown>) => void;
  error: (message: string, data?: Record<string, unknown>) => void;
}

/** Dependencies injected into the handler for testability. */
export interface DeleteUserAccountFunctionDeps {
  db: FirebaseFirestore.Firestore;
  /** Admin Auth instance (`getAuth()` in production). */
  authAdmin: DeleteUserAccountAuth;
  /** Default Storage bucket (`getStorage().bucket()` in production). */
  bucket: DeleteUserAccountBucket;
  logger: DeleteUserAccountLogger;
  /**
   * Clock injection for the `auth_time` recency check. Defaults to the
   * system clock; tests inject a fixed clock.
   */
  now?: () => Date;
}

/** The caller context the handler reads (auth uid + the recent-login claim). */
export interface DeleteUserAccountContext {
  auth?: {uid: string; token?: {auth_time?: number}};
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Returns true when [err] is the Admin Auth "user already gone" error, which
 * the idempotent cascade treats as success.
 */
function isAuthUserNotFound(err: unknown): boolean {
  return (
    typeof err === "object" &&
    err !== null &&
    (err as {code?: string}).code === "auth/user-not-found"
  );
}

/**
 * Returns true when [err] is a Storage "object not found" (HTTP 404) error.
 * `delete({ ignoreNotFound: true })` covers this on most SDK paths; this
 * guard makes the cascade robust to emulators / SDK builds that surface a
 * 404 despite the flag.
 */
function isObjectNotFound(err: unknown): boolean {
  if (typeof err !== "object" || err === null) return false;
  const code = (err as {code?: number | string}).code;
  return code === 404 || code === "404";
}

/**
 * Redacts the raw uid from an error message before it is logged. SDK error
 * messages can embed the uid through a resource path (e.g. a non-404 Storage
 * error mentioning `avatars/{uid}`), which would defeat the uid-hashing this
 * function applies everywhere else (ADR-0013 / SRS section 5.4). All
 * occurrences of the uid are replaced with its hash.
 */
function redactUid(message: string, uid: string, uidHash: string): string {
  if (uid.length === 0) return message;
  return message.split(uid).join(`uid#${uidHash}`);
}

/**
 * Deletes the personal avatar object `avatars/{uid}` idempotently.
 */
async function deleteAvatar(
  bucket: DeleteUserAccountBucket,
  uid: string,
  logger: DeleteUserAccountLogger,
  uidHash: string,
): Promise<void> {
  try {
    await bucket.file(`avatars/${uid}`).delete({ignoreNotFound: true});
  } catch (err: unknown) {
    if (isObjectNotFound(err)) {
      logger.info("delete_account_avatar_absent", {
        event: "delete_account_avatar_absent",
        uidHash,
      });
      return;
    }
    throw err;
  }
}

/**
 * Deletes the Firebase Auth record idempotently (LAST step).
 */
async function deleteAuthUser(
  authAdmin: DeleteUserAccountAuth,
  uid: string,
  logger: DeleteUserAccountLogger,
  uidHash: string,
): Promise<void> {
  try {
    await authAdmin.deleteUser(uid);
  } catch (err: unknown) {
    if (isAuthUserNotFound(err)) {
      logger.info("delete_account_auth_absent", {
        event: "delete_account_auth_absent",
        uidHash,
      });
      return;
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the HTTPS Callable handler with injected dependencies.
 *
 * Input: none — the subject is the caller's own `context.auth.uid`, so a
 * user can only delete themselves. Output: `{ success: true }`.
 */
export function createDeleteUserAccountHandler(
  deps: DeleteUserAccountFunctionDeps,
): (
  data: unknown,
  context: DeleteUserAccountContext,
) => Promise<DeleteUserAccountResponse> {
  const {db, authAdmin, bucket, logger} = deps;
  const now = deps.now ?? ((): Date => new Date());

  return async (
    _data: unknown,
    context: DeleteUserAccountContext,
  ): Promise<DeleteUserAccountResponse> => {
    // 1. Auth check (FIRST, before any read or write).
    const uid = context.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required.", {
        errorCode: "UNAUTHENTICATED",
      });
    }

    const uidHash = hashId(uid);

    // 2. Recent-login (re-auth) enforcement — defence-in-depth for an
    //    irreversible operation. SCR-28 Step B re-authenticates the current
    //    number, refreshing the `auth_time` claim; require it to be recent so
    //    a direct callable invocation with a stale (but unexpired) token
    //    cannot bypass the re-auth gate (ADR-0016). `auth_time` is in Unix
    //    SECONDS; a missing claim is treated as not-recently-authenticated.
    const authTimeSec = context.auth?.token?.auth_time;
    if (
      typeof authTimeSec !== "number" ||
      now().getTime() - authTimeSec * 1000 > REAUTH_MAX_AGE_MS
    ) {
      logger.warn("delete_account_reauth_required", {
        event: "delete_account_reauth_required",
        uidHash,
      });
      throw new HttpsError(
        "failed-precondition",
        "Please verify your identity again before deleting your account.",
        {errorCode: "REAUTH_REQUIRED"},
      );
    }

    logger.info("delete_account_cascade_started", {
      event: "delete_account_cascade_started",
      uidHash,
    });

    try {
      // 3. DELETE personal Firestore subtrees. recursiveDelete uses a
      //    BulkWriter under the hood (handles the 500-write WriteBatch cap)
      //    and is a no-op on an absent path, so a re-run converges.
      await db.recursiveDelete(db.collection("activity").doc(uid));
      await db.recursiveDelete(db.collection("_rateLimits").doc(uid));

      // 4. TOMBSTONE users/{uid}: set() without merge REPLACES the document
      //    with the PII-free shell, stripping phoneNumber/photoUrl/
      //    fcmTokens/notificationPrefs/locale. This is the anonymisation
      //    (ADR-0016). Friendships, expenses, settlements and the surviving
      //    member's simplifiedBalances are deliberately left untouched
      //    (Invariant 2). Groups are likewise preserved by omission — the
      //    function never touches groups/{groupId} or group-context
      //    settlements; v1.0 has no live groups, and a future group member
      //    tombstones identically when the Sprint 3 Groups epic lands.
      await db.collection("users").doc(uid).set({
        displayName: TOMBSTONE_DISPLAY_NAME,
        deletedAt: FieldValue.serverTimestamp(),
      });

      // 5. DELETE the personal Storage avatar (idempotent).
      await deleteAvatar(bucket, uid, logger, uidHash);

      // 6. DELETE the Firebase Auth record LAST (idempotent).
      await deleteAuthUser(authAdmin, uid, logger, uidHash);

      logger.info("delete_account_cascade_succeeded", {
        event: "delete_account_cascade_succeeded",
        uidHash,
      });
      return {success: true};
    } catch (err: unknown) {
      if (err instanceof HttpsError) {
        throw err;
      }
      logger.error("delete_account_cascade_failed", {
        event: "delete_account_cascade_failed",
        uidHash,
        errorCode: "INTERNAL",
        errorMessage: redactUid(
          err instanceof Error ? err.message : String(err),
          uid,
          uidHash,
        ),
      });
      throw new HttpsError(
        "internal",
        "Account deletion could not be completed. Please try again.",
        {errorCode: "INTERNAL"},
      );
    }
  };
}
