/// Telemetry event-name and parameter-key constants for the settle-up
/// feature.
///
/// Every payload that carries `friendship_id` or `settlement_id` MUST
/// pass the raw value through `hashFriendshipId` / `hashId` from
/// `lib/core/telemetry/event_id_hash.dart` before emission. The
/// parameter-key convention (ADR-0013) is to append `_hash` to make
/// the hashing visible at the call site.
///
/// Reference: `docs/design/07-technical/telemetry-plan.md` §1.6
/// (Settle Up events).
abstract final class SettleUpTelemetry {
  // ---------------------------------------------------------------
  // Event names
  // ---------------------------------------------------------------

  /// User tapped the OBTSettleUpCard CTA. Payload: `source`,
  /// `friendship_id_hash`.
  static const String settleUpTapped = 'settle_up_tapped';

  /// Bottom sheet body first paint. Payload: `context_type`, `source`,
  /// `friendship_id_hash`.
  static const String screenViewed = 'settle_up_screen_viewed';

  /// Save succeeded — the settlement document was written. Payload:
  /// `context_type`, `amount_range`, `is_partial`, `friendship_id_hash`,
  /// `settlement_id_hash`.
  static const String settlementRecorded = 'settlement_recorded';

  /// Save failed — Firestore rejected the write. Payload:
  /// `error_code`, `context_type`, `friendship_id_hash`.
  static const String errorEvent = 'settle_up_error';

  /// User tapped Save while the form was invalid. Payload: `field`,
  /// `reason`.
  static const String validationFailed = 'settle_up_validation_failed';

  // ---------------------------------------------------------------
  // Parameter-key constants.
  // ---------------------------------------------------------------

  /// `'friendship'` for FR-SE-05; `'group'` for FR-GR-04 (not in scope).
  static const String paramContextType = 'context_type';

  /// `'friend_detail'` for PR #43; `'home_dashboard'` and
  /// `'group_detail'` for future PRs.
  static const String paramSource = 'source';

  /// Hashed friendship-id (see `hashFriendshipId`).
  static const String paramFriendshipIdHash = 'friendship_id_hash';

  /// Hashed settlement-id (see `hashId`).
  static const String paramSettlementIdHash = 'settlement_id_hash';

  /// Bucketed amount band — see [amountRangeFor].
  static const String paramAmountRange = 'amount_range';

  /// `true` when amountPaise < suggestedAmountPaise (partial
  /// settlement).
  static const String paramIsPartial = 'is_partial';

  /// `'permission_denied'` / `'network'` / `'balance_changed'` /
  /// `'invalid_amount'` / `'unknown'`.
  static const String paramErrorCode = 'error_code';

  /// `'amount'` / `'note'` — the field that failed validation.
  static const String paramField = 'field';

  /// Free-text reason for the validation failure.
  static const String paramReason = 'reason';

  // ---------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------

  /// Maps a paise integer to the 4-bucket band per telemetry-plan.md
  /// §2.1 (shared with `ExpenseTelemetry.amountRangeFor` — same bands
  /// so cross-feature analytics joins behave).
  static String amountRangeFor(int paise) {
    if (paise < 50000) return 'under_500';
    if (paise < 500000) return '500_5000';
    if (paise < 2500000) return '5000_25000';
    return 'over_25000';
  }
}
