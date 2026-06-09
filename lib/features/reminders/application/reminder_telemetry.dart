/// Telemetry event-name and parameter-key constants for the FR-SE-09
/// send-reminder feature.
///
/// Every payload that carries a `friendship_id`-derived value MUST
/// pass the raw value through `hashFriendshipId` from
/// `lib/core/telemetry/event_id_hash.dart` before emission. The
/// parameter-key convention (ADR-0013) is to append `_hash` to make
/// the hashing visible at the call site.
///
/// Reference: `docs/sprint-zero/stories/FR-SE-09-send-reminder.md`
/// Telemetry Contract section (seven client events).
abstract final class ReminderTelemetry {
  // -----------------------------------------------------------------
  // Event names — mirror of the server-side `reminder_send_*` family
  // (FR-SE-09 architect notes Telemetry Contract).
  // -----------------------------------------------------------------

  /// User tapped the "Send Reminder" CTA on the OBTSettleUpCard
  /// receiving-direction variant. Fires before the callable is
  /// invoked. Payload: `friendship_id_hash`.
  static const String tapped = 'reminder_send_tapped';

  /// Callable returned success and the rate-limit window was opened.
  /// Payload: `friendship_id_hash`.
  static const String succeeded = 'reminder_send_succeeded';

  /// Callable returned `RATE_LIMITED`. Payload: `friendship_id_hash`,
  /// `next_allowed_in_seconds`.
  static const String rateLimited = 'reminder_send_rate_limited';

  /// Callable returned `RECIPIENT_PREFS_DISABLED`. Payload:
  /// `friendship_id_hash`.
  static const String recipientPrefsDisabled =
      'reminder_send_recipient_prefs_disabled';

  /// Callable returned `RECIPIENT_NO_TOKENS`. Payload:
  /// `friendship_id_hash`.
  static const String recipientNoTokens = 'reminder_send_recipient_no_tokens';

  /// Callable returned `RECIPIENT_DOESNT_OWE` — race-condition where
  /// `simplifiedBalances` drifted between render and tap. Payload:
  /// `friendship_id_hash`.
  static const String recipientDoesntOwe = 'reminder_send_recipient_doesnt_owe';

  /// Catch-all for `FCM_DISPATCH_FAILED`, `INTERNAL`,
  /// `GROUP_CONTEXT_NOT_SUPPORTED`, or non-callable network failures.
  /// Payload: `friendship_id_hash`, `error_code`.
  static const String failed = 'reminder_send_failed';

  // -----------------------------------------------------------------
  // Parameter-key constants
  // -----------------------------------------------------------------

  /// Hashed friendship-id (see `hashFriendshipId`). PII guard per
  /// ADR-0013.
  static const String paramFriendshipIdHash = 'friendship_id_hash';

  /// Seconds until the next allowed reminder send (positive integer).
  /// Only present on [rateLimited].
  static const String paramNextAllowedInSeconds = 'next_allowed_in_seconds';

  /// The server-side `details.errorCode` (or `'UNKNOWN'`). Only
  /// present on [failed].
  static const String paramErrorCode = 'error_code';
}
