/// Telemetry event-name and parameter-key constants for the Home
/// dashboard (SCR-06 / FR-HD-01..04).
///
/// Every payload that would otherwise carry a raw `context_id` (a
/// friendship document ID — the deterministic concatenation of two
/// sorted UIDs) MUST pass the value through `hashFriendshipId` from
/// `lib/core/telemetry/event_id_hash.dart` before emission. Per the
/// parameter-key convention (ADR-0013) the key is suffixed `_hash` to
/// make the hashing visible at the call site (e.g. `context_id_hash`).
/// `net_balance_state`, `context_type`, `amount_paise`,
/// `attempt_number`, and `error_code` are non-identifying values and
/// require no hashing.
///
/// Reference: `docs/design/06-screen-specs/06-08-home-and-search.md`
/// (SCR-06 "Telemetry Events") and SRS section 5.10.
abstract final class HomeTelemetry {
  // ---------------------------------------------------------------
  // Event names.
  // ---------------------------------------------------------------

  /// Dashboard reached a terminal render state (fires exactly once on
  /// the first non-loading frame). Payload: `net_balance_state`.
  static const String viewed = 'home_viewed';

  /// User tapped "Settle Up" on a top-balances tile. Payload:
  /// `context_type`, `context_id_hash`, `amount_paise`.
  static const String settleUpTapped = 'home_settle_up_tapped';

  /// User tapped a top-balances tile (not the Settle Up button).
  /// Payload: `context_type`, `context_id_hash`.
  static const String tileTapped = 'home_tile_tapped';

  /// User tapped the "Add Expense" CTA in the empty state. No payload.
  static const String emptyCtaTapped = 'home_empty_cta_tapped';

  /// User tapped "Retry" in the error state. Payload: `attempt_number`.
  static const String errorRetryTapped = 'home_error_retry_tapped';

  /// User tapped "Contact Support" in the error state. Payload:
  /// `error_code`.
  static const String errorSupportTapped = 'home_error_support_tapped';

  /// FR-HD-03 — the "This Month" spend-breakdown card reached its first
  /// terminal render (populated or empty) on a dashboard mount. Fires
  /// exactly once per mount, never on the loading or error sub-states.
  /// Payload: `category_count`.
  static const String spendingBreakdownViewed =
      'home_spending_breakdown_viewed';

  // ---------------------------------------------------------------
  // Parameter-key constants.
  // ---------------------------------------------------------------

  /// `'positive'` / `'negative'` / `'zero'` / `'loading'` / `'error'`.
  static const String paramNetBalanceState = 'net_balance_state';

  /// `'friend'` for the friendship axis; `'group'` for the Sprint 3
  /// group axis (not rendered in v1.0).
  static const String paramContextType = 'context_type';

  /// Hashed context (friendship) ID — see `hashFriendshipId`. Never the
  /// raw composite UID.
  static const String paramContextIdHash = 'context_id_hash';

  /// Absolute balance amount in integer paise (invariant 1). A money
  /// value, not an identifier — emitted raw.
  static const String paramAmountPaise = 'amount_paise';

  /// 1-based retry attempt counter for the error state.
  static const String paramAttemptNumber = 'attempt_number';

  /// Support-triage error code (always [errorCodeFirestoreRead] today).
  static const String paramErrorCode = 'error_code';

  /// FR-HD-03 — the number of non-zero categories rendered in the
  /// spend-breakdown card (`int`, `0..8`; `0` in the empty sub-state).
  /// A non-identifying small integer — never a uid, friendshipId, or
  /// rupee/paise value (SRS line 308; ADR-0013).
  static const String paramCategoryCount = 'category_count';

  // ---------------------------------------------------------------
  // Enum tokens.
  // ---------------------------------------------------------------

  /// `net_balance_state` token: the user is owed overall (net > 0).
  static const String netBalanceStatePositive = 'positive';

  /// `net_balance_state` token: the user owes overall (net < 0).
  static const String netBalanceStateNegative = 'negative';

  /// `net_balance_state` token: all settled up overall (net == 0).
  static const String netBalanceStateZero = 'zero';

  /// `net_balance_state` token: data still loading.
  static const String netBalanceStateLoading = 'loading';

  /// `net_balance_state` token: the balances read failed.
  static const String netBalanceStateError = 'error';

  /// `context_type` token for the friendship axis.
  static const String contextTypeFriend = 'friend';

  /// `context_type` token for the Sprint 3 group axis.
  static const String contextTypeGroup = 'group';

  /// The SCR-06 error-state support-triage code for a failed balances
  /// read.
  static const String errorCodeFirestoreRead = 'HD-FIRESTORE-READ';

  // ---------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------

  /// Maps a signed net balance in paise to its `net_balance_state`
  /// token. Loading and error states are emitted by the screen
  /// directly (they have no paise value).
  static String netBalanceStateFor(int netPaise) {
    if (netPaise > 0) return netBalanceStatePositive;
    if (netPaise < 0) return netBalanceStateNegative;
    return netBalanceStateZero;
  }
}
