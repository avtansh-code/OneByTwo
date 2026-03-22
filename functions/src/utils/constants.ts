/**
 * Application-wide constants for OneByTwo Cloud Functions.
 *
 * Keep in sync with the Dart-side constants in lib/core/constants/.
 */

// ── Money ───────────────────────────────────────────────────────────────────

/** Paise per rupee. All monetary values are integers in paise. */
export const PAISE_PER_RUPEE = 100;

// ── Groups ──────────────────────────────────────────────────────────────────

/** Maximum number of members allowed in a single group. */
export const MAX_GROUP_MEMBERS = 50;

/** Maximum number of groups a single user can belong to. */
export const MAX_GROUPS_PER_USER = 100;

// ── Invites ─────────────────────────────────────────────────────────────────

/** Default number of days before an invite link expires. */
export const DEFAULT_INVITE_EXPIRY_DAYS = 7;

/** Default maximum number of times an invite link can be used. */
export const DEFAULT_MAX_INVITE_USES = 10;

/** Length of generated invite codes. */
export const INVITE_CODE_LENGTH = 8;

// ── Soft Delete Cleanup ─────────────────────────────────────────────────────

/** Days after which soft-deleted documents are permanently hard-deleted. */
export const SOFT_DELETE_CLEANUP_DAYS = 30;

// ── Rate Limiting ───────────────────────────────────────────────────────────

/** Maximum nudge notifications a user can send per day. */
export const MAX_NUDGES_PER_DAY = 3;

/** Rate limit: simplifyDebts — max 10 calls per minute. */
export const RATE_LIMIT_SIMPLIFY_DEBTS = { maxCalls: 10, windowMs: 60_000 };

/** Rate limit: generateInviteLink — max 5 calls per minute. */
export const RATE_LIMIT_GENERATE_INVITE = { maxCalls: 5, windowMs: 60_000 };

/** Rate limit: joinGroupViaInvite — max 10 calls per minute. */
export const RATE_LIMIT_JOIN_INVITE = { maxCalls: 10, windowMs: 60_000 };

/** Rate limit: deleteAccount — max 1 call per day. */
export const RATE_LIMIT_DELETE_ACCOUNT = { maxCalls: 1, windowMs: 86_400_000 };

/** Rate limit: exportData — max 1 call per hour. */
export const RATE_LIMIT_EXPORT_DATA = { maxCalls: 1, windowMs: 3_600_000 };

/** Rate limit: nudgeUser / nudgeFriend — max 3 calls per hour per target. */
export const RATE_LIMIT_NUDGE = { maxCalls: 3, windowMs: 3_600_000 };

/** Rate limit: settleAll — max 5 calls per minute. */
export const RATE_LIMIT_SETTLE_ALL = { maxCalls: 5, windowMs: 60_000 };

/** Rate limit: addFriend — max 20 calls per minute. */
export const RATE_LIMIT_ADD_FRIEND = { maxCalls: 20, windowMs: 60_000 };

/** Rate limit: settleFriend — max 10 calls per minute. */
export const RATE_LIMIT_SETTLE_FRIEND = { maxCalls: 10, windowMs: 60_000 };

// ── Notifications ───────────────────────────────────────────────────────────

/** Maximum FCM tokens stored per user. */
export const MAX_FCM_TOKENS_PER_USER = 5;

// ── Expense Categories ──────────────────────────────────────────────────────

/** Valid expense categories. */
export const EXPENSE_CATEGORIES = [
  "food",
  "transport",
  "groceries",
  "rent",
  "entertainment",
  "utilities",
  "shopping",
  "health",
  "travel",
  "other",
] as const;

export type ExpenseCategory = (typeof EXPENSE_CATEGORIES)[number];

// ── Split Types ─────────────────────────────────────────────────────────────

/** Valid split types for expenses. */
export const SPLIT_TYPES = [
  "equal",
  "exact",
  "percentage",
  "shares",
  "itemized",
] as const;

export type SplitType = (typeof SPLIT_TYPES)[number];

// ── Group Categories ────────────────────────────────────────────────────────

/** Valid group categories. */
export const GROUP_CATEGORIES = [
  "trip",
  "home",
  "couple",
  "event",
  "other",
] as const;

export type GroupCategory = (typeof GROUP_CATEGORIES)[number];

// ── Member Roles ────────────────────────────────────────────────────────────

/** Valid group member roles, in descending order of privilege. */
export const MEMBER_ROLES = ["owner", "admin", "member"] as const;

export type MemberRole = (typeof MEMBER_ROLES)[number];
