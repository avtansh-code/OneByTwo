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

// FR-SE-09 send-reminder callable. First downstream consumer of the
// FR-AC-03 FCM module via a callable Cloud Function path. Reads
// simplifiedBalances for the precondition check (Invariant 2: read-
// only); writes to `_rateLimits/{senderUid}/sends/{recipientUid}` for
// the per-friend 24-hour rate limit and to `activity/{recipientUid}/
// items/{auto}` for the in-app activity row.
export {sendReminderNotification} from "./send-reminder-notification/index";

// FR-AU-09 permanently delete account callable (SCR-28 Part B). The first
// cascade-delete fan-out function and the first admin.auth().deleteUser(...).
// Runs entirely under the Admin SDK (clients have NO delete path). DELETES
// personal records (activity/{uid}, _rateLimits/{uid}, Storage avatars/{uid},
// the Auth record LAST), TOMBSTONES users/{uid} into a PII-free
// { displayName: 'Deleted User', deletedAt } shell, and PRESERVES shared
// friendships/expenses/settlements untouched — the surviving member's
// simplifiedBalances is never recomputed or stripped (Invariant 2). See
// ADR-0016.
export {deleteUserAccount} from "./delete-user-account/index";

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
