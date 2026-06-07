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
  // FR-EX-06 edit event constants — Camp B verb-past + state
  // pattern, ratified in architect §2.6. SCR-22 §Telemetry is the
  // screen-level authority for the verb tense (`_saved`, not
  // `_succeeded`); see PM Q5.
  // ---------------------------------------------------------------

  /// Edit-mode controller constructed. Payload: `context_type`,
  /// `friendship_id_hash`, `expense_id_hash`.
  static const String editOpened = 'expense_edit_opened';

  /// User changed a field from its original value (or restored it).
  /// Payload: `field_name`.
  static const String editFieldChanged = 'expense_edit_field_changed';

  /// Edit save succeeded. Payload: `fields_changed` (comma-separated
  /// keys), `split_method`, `friendship_id_hash`, `expense_id_hash`.
  static const String editSaved = 'expense_edit_saved';

  /// Edit save failed. Payload: `error_code`, `friendship_id_hash`,
  /// `expense_id_hash`.
  static const String editFailed = 'expense_edit_failed';

  /// User dismissed the edit sheet without saving. Payload:
  /// `had_changes`, `time_spent_ms`, `friendship_id_hash`,
  /// `expense_id_hash`.
  static const String editAbandoned = 'expense_edit_abandoned';

  // ---------------------------------------------------------------
  // FR-EX-06 delete event constants.
  // ---------------------------------------------------------------

  /// User tapped the Delete action; the confirmation dialog opens.
  /// Payload: `context_type`, `friendship_id_hash`,
  /// `expense_id_hash`.
  static const String deleteInitiated = 'expense_delete_initiated';

  /// User confirmed the delete; the soft-delete write succeeded.
  /// Payload: `amount_paise`, `participant_count`,
  /// `friendship_id_hash`, `expense_id_hash`.
  static const String deleteConfirmed = 'expense_delete_confirmed';

  /// User dismissed the confirmation dialog. Payload:
  /// `friendship_id_hash`, `expense_id_hash`.
  static const String deleteCancelled = 'expense_delete_cancelled';

  /// Soft-delete write failed. Payload: `error_code`,
  /// `friendship_id_hash`, `expense_id_hash`.
  static const String deleteFailed = 'expense_delete_failed';

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

  /// `'equal'` / `'exact'` (the methods enabled in FR-EX-01).
  static const String paramSplitMethod = 'split_method';

  /// Always 2 in FR-EX-01 (the friendship is two-person by definition).
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
  // FR-EX-05 receipt event constants (architect §2.6). SCR-21
  // §Telemetry Events lines 357-362 is the source of truth.
  // ---------------------------------------------------------------

  /// Step 3 (receipt + confirm) becomes visible. Payload:
  /// `has_receipt_from_edit` (bool — true when edit-mode opens
  /// Step 3 with an existing `receiptUrl`).
  static const String step3Opened = 'expense_step3_opened';

  /// User attached a receipt image. Payload: `source`
  /// (`'camera'` / `'gallery'`), `file_size_bytes`.
  static const String receiptAttached = 'expense_receipt_attached';

  /// User removed an attached receipt. Payload: empty.
  static const String receiptRemoved = 'expense_receipt_removed';

  /// User dismissed the sheet from Step 3. Payload:
  /// `had_receipt` (bool), `time_spent_ms` (int — time since
  /// Step 3 opened, NOT since Step 1).
  static const String step3Abandoned = 'expense_step3_abandoned';

  // ---------------------------------------------------------------
  // FR-EX-06 parameter-key additions (architect §2.6).
  // ---------------------------------------------------------------

  /// Name of the field the user just changed (e.g. `'amountPaise'`,
  /// `'description'`). Used by [editFieldChanged].
  static const String paramFieldName = 'field_name';

  /// Comma-separated list of changed field names. Used by
  /// [editSaved] (FA-friendly because the dashboards group on
  /// string values directly).
  static const String paramFieldsChanged = 'fields_changed';

  /// `true` when the user dismissed an edit sheet with at least one
  /// field changed. Used by [editAbandoned].
  static const String paramHadChanges = 'had_changes';

  /// Raw paise integer. Per-action telemetry, not bucketed (only
  /// used by [deleteConfirmed]; the funnel events bucket via
  /// `amount_range`).
  static const String paramAmountPaise = 'amount_paise';

  /// Typed error code name (e.g. `'permissionDenied'`, `'network'`).
  /// Used by [editFailed] and [deleteFailed].
  static const String paramErrorCode = 'error_code';

  // ---------------------------------------------------------------
  // FR-EX-05 parameter-key additions (architect §2.6).
  // ---------------------------------------------------------------

  /// `'camera'` / `'gallery'` — where the receipt came from.
  /// Used by [receiptAttached].
  static const String paramSource = 'source';

  /// Raw byte count of the picked file (pre-upload). Used by
  /// [receiptAttached].
  static const String paramFileSizeBytes = 'file_size_bytes';

  /// `true` when the edit-mode bottom sheet's Step 3 opens with an
  /// existing `receiptUrl`. Used by [step3Opened].
  static const String paramHasReceiptFromEdit = 'has_receipt_from_edit';

  /// Raw byte count of the receipt uploaded with a successful save.
  /// Only present on [saveSucceeded] when `has_receipt: true`.
  static const String paramReceiptSizeBytes = 'receipt_size_bytes';

  /// `true` when the user dismissed Step 3 with a receipt attached.
  /// Used by [step3Abandoned].
  static const String paramHadReceipt = 'had_receipt';

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
