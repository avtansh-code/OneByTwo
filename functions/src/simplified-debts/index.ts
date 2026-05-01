/**
 * Simplified Debts — Module Index
 *
 * Exports the `recomputeSimplifiedBalances` HTTPS Callable Cloud Function.
 * Region-pinned to asia-south1 (Mumbai) per SRS section 7.1.
 *
 * @module simplified-debts
 */

import {onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createHandler} from "./function";

const REGION = "asia-south1";

/**
 * HTTPS Callable Cloud Function that recomputes the simplified debts
 * for a friendship or group context.
 *
 * Input: `{ contextType: 'friendship' | 'group', contextId: string }`
 *
 * Output: `{ ok: true, transfers: Transfer[], simplifiedBalances: SimplifiedBalancesMap, computedAt: string }`
 *
 * Error codes: see docs/design/07-technical/cloud-functions-error-codes.md
 */
export const recomputeSimplifiedBalances = onCall(
  {region: REGION},
  async (request) => {
    const handler = createHandler({
      db: getFirestore(),
      logger,
    });
    return handler(request.data);
  },
);
