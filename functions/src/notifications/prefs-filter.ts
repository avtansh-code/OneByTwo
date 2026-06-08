/**
 * Per-recipient preference short-circuit for FCM dispatch (FR-AC-03 /
 * notifications.md §2.3).
 *
 * The user's `users/{uid}.notificationPrefs` map controls whether
 * each category of notification is delivered. The categories are:
 *
 *   - `newExpense` → gates `expense_added` / `expense_edited` /
 *     `expense_deleted`.
 *   - `settlement` → gates `settlement_received`.
 *   - `reminder` → gates `reminder`.
 *
 * The `group_invite` type bypasses the filter — invites grant
 * group-access and must always be delivered (per FR-AC-03 AC-19,
 * ratified forward-compat).
 *
 * Missing flags default to TRUE — this mirrors the FR-AU-06 schema
 * default and avoids silently dropping notifications for users whose
 * profile was created before the flag existed.
 *
 * @module notifications/prefs-filter
 */

import type {NotificationType, RecipientPrefs} from "./types";

/**
 * Returns true if a notification of the given `type` should be
 * delivered to a user whose preferences are `prefs`.
 *
 * @param type - The notification's `NotificationType`.
 * @param prefs - The user's preference map, OR `undefined` if the
 *   user doc has no `notificationPrefs` field (treated as
 *   "everything enabled" per the FR-AU-06 default).
 * @returns true if the dispatcher should proceed; false to suppress
 *   silently (the trigger logs `fcm_send_suppressed_by_prefs`).
 */
export function isNotificationAllowed(
  type: NotificationType,
  prefs: RecipientPrefs | undefined,
): boolean {
  // Forward-compat carve-out: group invites are NEVER suppressed by
  // user prefs (they grant access and must be delivered). See AC-19.
  if (type === "group_invite") {
    return true;
  }

  // Missing prefs map → everything allowed.
  if (!prefs) {
    return true;
  }

  switch (type) {
  case "expense_added":
  case "expense_edited":
  case "expense_deleted":
    // Default true when the flag is missing.
    return prefs.newExpense !== false;

  case "settlement_received":
    return prefs.settlement !== false;

  case "reminder":
    return prefs.reminder !== false;

  default: {
    // Exhaustiveness — unreachable. New NotificationType values
    // must be added to this switch.
    const _exhaustive: never = type;
    throw new Error(
      `isNotificationAllowed: unsupported type '${_exhaustive as string}'.`,
    );
  }
  }
}
