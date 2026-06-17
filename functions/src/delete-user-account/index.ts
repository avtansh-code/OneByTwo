/**
 * FR-AU-09 Delete Account — Module Index.
 *
 * Exports the `deleteUserAccount` HTTPS Callable Cloud Function.
 * Region-pinned to asia-south1 (Mumbai) per SRS section 7.1 and ADR-0016.
 *
 * @module delete-user-account
 */

import {onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {getStorage} from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import {createDeleteUserAccountHandler} from "./function";

const REGION = "asia-south1";

/**
 * HTTPS Callable Cloud Function that permanently deletes the authenticated
 * caller's account (FR-AU-09) via a synchronous Admin-SDK cascade.
 *
 * Input: none — the subject is the caller's own `request.auth.uid`.
 *
 * Output: `DeleteUserAccountResponse` — `{ success: true }`.
 *
 * Error codes: UNAUTHENTICATED, REAUTH_REQUIRED, INTERNAL. See ADR-0016 and
 * docs/design/07-technical/cloud-functions-error-codes.md section 2.6.
 */
export const deleteUserAccount = onCall({region: REGION}, async (request) => {
  const handler = createDeleteUserAccountHandler({
    db: getFirestore(),
    authAdmin: getAuth(),
    bucket: getStorage().bucket(),
    logger,
  });
  return handler(request.data, {
    auth: request.auth ?
      {
        uid: request.auth.uid,
        // auth_time (Unix seconds) drives the server-side recent-login check
        // so the SCR-28 re-auth gate is enforced beyond the client.
        token: {auth_time: request.auth.token.auth_time},
      } :
      undefined,
  });
});
