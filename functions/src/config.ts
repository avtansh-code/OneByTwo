/**
 * Environment configuration and shared constants.
 *
 * All Cloud Functions in OneByTwo run in asia-south1 (Mumbai).
 * Monetary values are always stored as integers in paise (₹1 = 100 paise).
 */

/** Firebase region for all deployed functions. */
export const REGION = "asia-south1" as const;

/** Common function options applied to all callable functions. */
export const CALLABLE_OPTIONS = {
  region: REGION,
  maxInstances: 100,
} as const;

/** Common function options for Firestore trigger functions. */
export const TRIGGER_OPTIONS = {
  region: REGION,
} as const;

/** Common function options for scheduled functions. */
export const SCHEDULE_OPTIONS = {
  region: REGION,
  timeZone: "Asia/Kolkata",
} as const;
