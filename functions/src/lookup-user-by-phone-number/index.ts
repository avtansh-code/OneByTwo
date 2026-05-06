/**
 * Lookup User By Phone Number — Module Index
 *
 * Exports the `lookupUserByPhoneNumber` HTTPS Callable Cloud Function.
 * Region-pinned to asia-south1 (Mumbai) per SRS section 7.1.
 *
 * @module lookup-user-by-phone-number
 */

import {onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createLookupHandler} from "./function";

const REGION = "asia-south1";

/**
 * HTTPS Callable Cloud Function that looks up a user by their phone number.
 *
 * Input: `{ phoneNumber: string }` — E.164 Indian mobile number (+91...).
 *
 * Output: `{ matched: false }` or
 *   `{ matched: true, displayName: string, photoUrl: string | null, otherUserId: string }`
 *
 * Error codes: UNAUTHENTICATED, INVALID_INPUT, RATE_LIMITED, INTERNAL.
 */
export const lookupUserByPhoneNumber = onCall(
  {region: REGION},
  async (request) => {
    const handler = createLookupHandler({
      db: getFirestore(),
      logger,
    });
    return handler(request.data, {
      auth: request.auth ? {uid: request.auth.uid} : undefined,
    });
  },
);
