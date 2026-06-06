/**
 * One By Two Cloud Functions entry point.
 *
 * All functions are region-pinned to asia-south1 (Mumbai) per SRS section 7.1.
 * This file re-exports every function module.
 *
 * @module index
 */

import {initializeApp} from "firebase-admin/app";
import {onRequest} from "firebase-functions/v2/https";

// Initialise Firebase Admin SDK (idempotent — safe to call once at module load).
initializeApp();

const REGION = "asia-south1";

/**
 * Health-check HTTPS function.
 *
 * Returns a JSON response confirming the functions runtime is operational.
 * Used by CI and monitoring to verify deployment health.
 *
 * @example
 * GET /healthcheck -> { "ok": true, "region": "asia-south1" }
 */
export const healthcheck = onRequest({region: REGION}, (_req, res) => {
  res.status(200).json({ok: true, region: REGION});
});

// Simplified debts recomputation callable
export {recomputeSimplifiedBalances} from "./simplified-debts/index";

// Lookup user by phone number callable
export {lookupUserByPhoneNumber} from "./lookup-user-by-phone-number/index";

// Firestore trigger: recompute simplifiedBalances when an expense is
// created, updated, or deleted under a friendship (FR-SE-03/04).
// First non-callable producer of simplifiedBalances (Invariant 2).
export {onExpenseWriteFriendship} from "./triggers/on-expense-write/index";

// Firestore trigger: recompute simplifiedBalances when a settlement is
// created, updated, or deleted at settlements/{settlementId} (FR-SE-05/06).
// First trigger on a top-level collection. Reads contextType + contextId
// from the document data (the settlements collection is top-level so the
// discriminator is not in the trigger path).
export {onSettlementWrite} from "./triggers/on-settlement-write/index";
