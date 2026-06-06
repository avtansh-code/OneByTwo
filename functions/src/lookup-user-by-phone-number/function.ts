/**
 * Lookup User By Phone Number — Function Boundary (HTTPS Callable Handler)
 *
 * Validates input, enforces rate limits, hashes PII for logging, runs
 * the lookup algorithm, and returns the result to the caller.
 *
 * Error codes follow docs/design/07-technical/cloud-functions-error-codes.md.
 *
 * @module lookup-user-by-phone-number/function
 */

import {HttpsError} from "firebase-functions/v2/https";
import {createHash} from "crypto";
import {FieldValue} from "firebase-admin/firestore";
import {lookupUserByPhoneNumber, LookupResult} from "./algorithm";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Dependencies injected into the handler for testability. */
export interface LookupFunctionDeps {
  db: FirebaseFirestore.Firestore;
  logger: {
    info: (message: string, data?: Record<string, unknown>) => void;
    error: (message: string, data?: Record<string, unknown>) => void;
    warn: (message: string, data?: Record<string, unknown>) => void;
  };
}

// Re-export LookupResult so consumers can import from this module too.
export type {LookupResult};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Indian mobile E.164 pattern: +91 followed by a digit 6-9 then 9 more digits. */
const INDIAN_MOBILE_REGEX = /^\+91[6-9]\d{9}$/;

/** Maximum lookups allowed per rolling 1-hour window. */
const RATE_LIMIT_MAX = 100;

/** Rolling window duration in milliseconds (1 hour). */
const RATE_LIMIT_WINDOW_MS = 3_600_000;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Returns the SHA-256 hex digest of the given value. */
function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

// ---------------------------------------------------------------------------
// Handler factory
// ---------------------------------------------------------------------------

/**
 * Creates the HTTPS Callable handler with injected dependencies.
 *
 * @param deps - Firestore database and logger instances.
 * @returns An async handler function compatible with the onCall wrapper.
 */
export function createLookupHandler(
  deps: LookupFunctionDeps,
): (data: unknown, context: {auth?: {uid: string}}) => Promise<LookupResult> {
  const {db, logger} = deps;

  return async (
    data: unknown,
    context: {auth?: {uid: string}},
  ): Promise<LookupResult> => {
    // ------------------------------------------------------------------
    // 1. Auth check
    // ------------------------------------------------------------------
    const callerUid = context.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Authentication required.", {
        errorCode: "UNAUTHENTICATED",
      });
    }

    // ------------------------------------------------------------------
    // 2. Input validation
    // ------------------------------------------------------------------
    const obj = data as Record<string, unknown> | null | undefined;
    const phoneNumber =
      obj && typeof obj === "object" ? (obj.phoneNumber as unknown) : undefined;

    if (
      typeof phoneNumber !== "string" ||
      !INDIAN_MOBILE_REGEX.test(phoneNumber)
    ) {
      logger.error("lookup_user_by_phone_number_failed", {
        event: "lookup_user_by_phone_number_failed",
        errorCode: "INVALID_INPUT",
      });
      throw new HttpsError("invalid-argument", "Invalid phone number format.", {
        errorCode: "INVALID_INPUT",
      });
    }

    // ------------------------------------------------------------------
    // 3. Rate limiting
    // ------------------------------------------------------------------
    // Architect-canonical 4-segment subcollection doc path
    // (`_rateLimits/{userId}/{category}/counter`) — extends naturally to
    // future rate-limit categories without schema migration. See
    // `.github/shared/decision-log.md` lines 695-765 and
    // `docs/sprint-zero/stories/CHORE-pr45-lookup-rate-limit-and-pr38-cleanup.md`
    // Architect Notes section 2.1 / 2.9.
    const rateLimitDocRef = db.doc(
      `_rateLimits/${callerUid}/lookups/counter`,
    );
    const rateLimitSnap = await rateLimitDocRef.get();

    if (rateLimitSnap.exists) {
      const rlData = rateLimitSnap.data() as {
        count: number;
        windowStart: number;
      };
      const elapsed = Date.now() - rlData.windowStart;

      if (elapsed < RATE_LIMIT_WINDOW_MS) {
        if (rlData.count >= RATE_LIMIT_MAX) {
          logger.error("lookup_user_by_phone_number_failed", {
            event: "lookup_user_by_phone_number_failed",
            errorCode: "RATE_LIMITED",
          });
          throw new HttpsError(
            "resource-exhausted",
            "Rate limit exceeded.",
            {errorCode: "RATE_LIMITED"},
          );
        }
        // Within window, under limit — atomic increment to avoid race.
        await rateLimitDocRef.update({count: FieldValue.increment(1)});
      } else {
        // Window expired — reset.
        await rateLimitDocRef.set({count: 1, windowStart: Date.now()});
      }
    } else {
      // No rate-limit document — initialise.
      await rateLimitDocRef.set({count: 1, windowStart: Date.now()});
    }

    // ------------------------------------------------------------------
    // 4. Log started (hashed PII only)
    // ------------------------------------------------------------------
    logger.info("lookup_user_by_phone_number_started", {
      event: "lookup_user_by_phone_number_started",
      phoneNumberHash: sha256(phoneNumber),
      callerUidHash: sha256(callerUid),
    });

    // ------------------------------------------------------------------
    // 5. Call algorithm
    // ------------------------------------------------------------------
    try {
      const result = await lookupUserByPhoneNumber(phoneNumber, callerUid, {
        db,
      });

      // 6. Log completed
      logger.info("lookup_user_by_phone_number_completed", {
        event: "lookup_user_by_phone_number_completed",
        matched: result.matched,
      });

      return result;
    } catch (err: unknown) {
      // Re-throw HttpsError instances directly.
      if (err instanceof HttpsError) {
        logger.error("lookup_user_by_phone_number_failed", {
          event: "lookup_user_by_phone_number_failed",
          errorCode:
            (
              (err as HttpsError & {details?: {errorCode?: string}})
                .details as {errorCode?: string} | undefined
            )?.errorCode ?? err.code,
        });
        throw err;
      }

      // Catch-all: map to INTERNAL
      logger.error("lookup_user_by_phone_number_failed", {
        event: "lookup_user_by_phone_number_failed",
        errorCode: "INTERNAL",
      });
      throw new HttpsError("internal", "Internal error.", {
        errorCode: "INTERNAL",
      });
    }
  };
}
