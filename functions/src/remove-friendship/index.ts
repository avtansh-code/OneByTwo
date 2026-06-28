/**
 * FR-FR-05 Remove Friend — Module Index.
 *
 * Exports the `removeFriendship` HTTPS Callable Cloud Function.
 * Region-pinned to asia-south1 (Mumbai) per SRS section 7.1 and ADR-0016.
 *
 * @module remove-friendship
 */

import {onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createRemoveFriendshipHandler} from "./function";

const REGION = "asia-south1";

/**
 * HTTPS Callable Cloud Function that removes a friendship the authenticated
 * caller belongs to (FR-FR-05) via an Admin-SDK `recursiveDelete`.
 *
 * Input: `{ friendshipId: string }` — the deterministic `{uidA}_{uidB}` ID.
 *
 * Output: `RemoveFriendshipResponse` — `{ success: true }`.
 *
 * Preconditions: the caller must be a member of the friendship and the
 * friendship must be fully settled (no non-zero `simplifiedBalances` entry —
 * READ only, Invariant 2). On success the friendship document and its
 * `expenses` subtree are recursively deleted under the Admin SDK (clients
 * have NO delete path — `firestore.rules` keeps `allow delete: if false`).
 *
 * Error codes: UNAUTHENTICATED, INVALID_INPUT, FRIENDSHIP_NOT_FOUND,
 * NOT_A_MEMBER, FRIENDSHIP_NOT_SETTLED, INTERNAL. See
 * docs/design/07-technical/cloud-functions-error-codes.md.
 */
export const removeFriendship = onCall({region: REGION}, async (request) => {
  const handler = createRemoveFriendshipHandler({
    db: getFirestore(),
    logger,
  });
  return handler(request.data, {
    auth: request.auth ? {uid: request.auth.uid} : undefined,
  });
});
