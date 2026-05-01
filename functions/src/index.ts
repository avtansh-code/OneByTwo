/**
 * One By Two Cloud Functions entry point.
 *
 * All functions are region-pinned to asia-south1 (Mumbai) per SRS section 7.1.
 * This file re-exports every function module.
 *
 * @module index
 */

import {onRequest} from "firebase-functions/v2/https";

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
