/// Telemetry event-name and parameter-key constants for the FR-PR-03
/// notification-preferences feature (SCR-27).
///
/// Mirrors the contract pre-declared in
/// `docs/design/07-technical/telemetry-plan.md` lines 204-206:
///
///   | `notification_prefs_viewed` | — | — |
///       Notification Preferences screen opened | SCR-27 |
///   | `notification_pref_changed` | `category`, `enabled` |
///       Toggle changed and persisted | SCR-27 |
///   | `notification_pref_error` | `category`, `error_code` |
///       Toggle save fails | SCR-27 |
///
/// PII-guard note (architect §2.5): no event in this family carries a
/// `userId`, `uid`, `friendship_id`, or `friendship_id_hash` parameter.
/// The category enum values are SAFE non-identifying tokens
/// (`newExpense` / `settlement` / `reminder`).
library;

// ---------------------------------------------------------------------------
// Event names — exact strings ratified in telemetry-plan.md:204-206.
// ---------------------------------------------------------------------------

/// Notification Preferences screen opened (single-fire per session
/// per render).
const String notificationPrefsViewedEvent = 'notification_prefs_viewed';

/// A toggle change was successfully persisted via the partial-map
/// `users/{uid}` writer.
const String notificationPrefChangedEvent = 'notification_pref_changed';

/// A toggle change failed to persist (Firestore unavailable, rejected,
/// or unknown). Carries an `error_code` classification.
const String notificationPrefErrorEvent = 'notification_pref_error';

// ---------------------------------------------------------------------------
// Parameter-key constants.
// ---------------------------------------------------------------------------

/// The toggle category. Value is one of
/// [notificationPrefCategoryNewExpense], [notificationPrefCategorySettlement],
/// or [notificationPrefCategoryReminder].
const String notificationPrefCategoryParam = 'category';

/// The new boolean value of the toggle (true = ON, false = OFF).
/// Only present on [notificationPrefChangedEvent].
const String notificationPrefEnabledParam = 'enabled';

/// The classified error string. Only present on
/// [notificationPrefErrorEvent]. Values mirror the existing
/// `expense_telemetry.dart` taxonomy: `firestore-error`, `network`,
/// `unknown`.
const String notificationPrefErrorCodeParam = 'error_code';

// ---------------------------------------------------------------------------
// Category enum values — match the keys on `users.notificationPrefs`.
// ---------------------------------------------------------------------------

/// New-expense notification category.
const String notificationPrefCategoryNewExpense = 'newExpense';

/// Settlement notification category.
const String notificationPrefCategorySettlement = 'settlement';

/// Reminder notification category.
const String notificationPrefCategoryReminder = 'reminder';

/// Group-activity notification category. Defaults to `false` (opt-in):
/// members joining, edits, and changes in shared groups. Optional on
/// `users.notificationPrefs` so legacy three-key documents remain valid.
const String notificationPrefCategoryGroupActivity = 'groupActivity';

// ---------------------------------------------------------------------------
// error_code taxonomy — classified by the controller's _classifyError
// helper before emission.
// ---------------------------------------------------------------------------

/// Firestore-level rejection (rules / type / not-found etc.).
const String notificationPrefErrorCodeFirestore = 'firestore-error';

/// Network unavailable (`unavailable` Firestore code).
const String notificationPrefErrorCodeNetwork = 'network';

/// Catch-all classifier when no other bucket matches.
const String notificationPrefErrorCodeUnknown = 'unknown';
