/// Telemetry event-name and parameter-key constants for the expense
/// feature.
///
/// Camp B naming (chore #25 ratified in Architect Notes §2.0):
/// successful saves emit `expense_save_succeeded`; failures emit
/// `expense_save_failed`. The other event names follow the lifecycle
/// pattern established by the friends and onboarding features.
///
/// Every payload that carries `friendship_id` or `expense_id` MUST
/// pass the raw value through `hashFriendshipId` / `hashId` from
/// `lib/core/telemetry/event_id_hash.dart` before emission. The
/// parameter-key convention (ADR-0013) is to append `_hash` to make
/// the hashing visible at the call site.
///
/// Reference: `docs/design/07-technical/telemetry-plan.md` §2.1.
abstract final class ExpenseTelemetry {
  // ---------------------------------------------------------------
  // Event names (FR-EX-01 only — Edit / Delete / Receipt events are
  // not enumerated here; they will be added by the respective
  // follow-up stories).
  // ---------------------------------------------------------------

  /// Step 1 opened from a friendship FAB. Payload: `context_type`,
  /// `entry_point`, `friendship_id_hash`.
  static const String step1Opened = 'expense_step1_opened';

  /// User picked a category chip. Payload: `category`.
  static const String categorySelected = 'expense_category_selected';

  /// Step 1 → Step 2 transition. Payload: `amount_range`, `category`,
  /// `has_notes`.
  static const String step1Completed = 'expense_step1_completed';

  /// Sheet dismissed from Step 1. Payload: `fields_filled_count`,
  /// `time_spent_ms`.
  static const String step1Abandoned = 'expense_step1_abandoned';

  /// Step 2 entered. Payload: `split_method`, `participant_count`.
  static const String step2Opened = 'expense_step2_opened';

  /// User switched split method. Payload: `from_method`, `to_method`.
  static const String splitMethodChanged = 'expense_split_method_changed';

  /// User toggled payer. Payload: `payer_is_self`.
  static const String payerChanged = 'expense_payer_changed';

  /// Step 2 → save initiated. Payload: `split_method`,
  /// `participant_count`, `payer_is_self`.
  static const String step2Completed = 'expense_step2_completed';

  /// Validation of an exact-split entry failed. Payload:
  /// `split_method`, `direction` (`under` or `over`).
  static const String splitValidationFailed = 'expense_split_validation_failed';

  /// Sheet dismissed from Step 2. Payload: `split_method`,
  /// `time_spent_ms`.
  static const String step2Abandoned = 'expense_step2_abandoned';

  /// Save success — Camp B name. Payload: `context_type`,
  /// `amount_range`, `category`, `split_method`, `participant_count`,
  /// `has_receipt`, `has_notes`, `is_offline`, `friendship_id_hash`,
  /// `expense_id_hash`.
  static const String saveSucceeded = 'expense_save_succeeded';

  /// Save failure — Camp B name. Payload: `error_type`, `is_offline`,
  /// `friendship_id_hash`.
  static const String saveFailed = 'expense_save_failed';

  // ---------------------------------------------------------------
  // Parameter-key constants.
  // ---------------------------------------------------------------

  /// `'friendship'` for FR-EX-01 (group context is FR-EX-02).
  static const String paramContextType = 'context_type';

  /// e.g. `'friend_detail_fab'`.
  static const String paramEntryPoint = 'entry_point';

  /// Hashed friendship-id (see `hashFriendshipId`).
  static const String paramFriendshipIdHash = 'friendship_id_hash';

  /// Hashed expense-id (see `hashId`).
  static const String paramExpenseIdHash = 'expense_id_hash';

  /// Bucketed amount band — see [amountRangeFor].
  static const String paramAmountRange = 'amount_range';

  /// Category slug — `'food'`, `'travel'`, etc.
  static const String paramCategory = 'category';

  /// `true` if the description / notes field is non-empty (FR-EX-01:
  /// always `false` because the notes field is deferred to FR-EX-04).
  static const String paramHasNotes = 'has_notes';

  /// `true` if a receipt was attached (FR-EX-05; always `false` in
  /// FR-EX-01).
  static const String paramHasReceipt = 'has_receipt';

  /// Count of Step 1 fields filled when the sheet was dismissed.
  static const String paramFieldsFilledCount = 'fields_filled_count';

  /// Wall-clock duration the sheet was open, in milliseconds.
  static const String paramTimeSpentMs = 'time_spent_ms';

  /// `'equal'` / `'exact'` (PR #38).
  static const String paramSplitMethod = 'split_method';

  /// Always 2 in PR #38 (the friendship is two-person by definition).
  static const String paramParticipantCount = 'participant_count';

  /// `true` if the payer is the current user; `false` otherwise.
  static const String paramPayerIsSelf = 'payer_is_self';

  /// Previous value for the split-method change event.
  static const String paramFromMethod = 'from_method';

  /// New value for the split-method change event.
  static const String paramToMethod = 'to_method';

  /// `'under'` if exact splits sum to less than the total; `'over'`
  /// otherwise.
  static const String paramDirection = 'direction';

  /// `permission_denied` / `network` / `unknown`.
  static const String paramErrorType = 'error_type';

  /// `true` if the device is offline at save time.
  static const String paramIsOffline = 'is_offline';

  // ---------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------

  /// Maps a paise integer to the 4-bucket band per telemetry-plan.md
  /// §2.1. NOTE: 4 buckets, not the 6 the source prompt described —
  /// the canonical telemetry plan has been updated to the bands
  /// below. Any future expansion (e.g. splitting the `over_25000`
  /// bucket into `25k_1L` / `over_1L`) needs a telemetry-plan ADR.
  static String amountRangeFor(int paise) {
    if (paise < 50000) return 'under_500';
    if (paise < 500000) return '500_5000';
    if (paise < 2500000) return '5000_25000';
    return 'over_25000';
  }
}
