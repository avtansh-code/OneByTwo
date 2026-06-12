/// Telemetry event-name and parameter-key constants for the settlement
/// history screen (SCR-24).
///
/// Both events are pre-declared in
/// `docs/design/07-technical/telemetry-plan.md` §1.3. NEITHER event
/// carries a `context_id` parameter: for the friendship axis the
/// `contextId` is a UID-composite (`{uidA}_{uidB}`) that must not be
/// emitted raw per ADR-0013. `context_type` is a safe non-identifying
/// enum token, `item_count` is a non-PII integer, and `error_code` is a
/// safe Firebase error-code enum — so no hashing is required here.
///
/// Reference: `docs/design/06-screen-specs/23-28-settle-activity-profile.md`
/// §SCR-24.
abstract final class SettlementHistoryTelemetry {
  // ---------------------------------------------------------------
  // Event names.
  // ---------------------------------------------------------------

  /// Settlement history screen loaded with resolved data (fires exactly
  /// once on the first `AsyncData` frame). Payload: `context_type`,
  /// `item_count`.
  static const String viewedEvent = 'settlement_history_viewed';

  /// Settlement history data fetch failed (fires exactly once on the
  /// first `AsyncError` frame). Payload: `error_code`, `context_type`.
  static const String errorEvent = 'settlement_history_error';

  // ---------------------------------------------------------------
  // Parameter-key constants.
  // ---------------------------------------------------------------

  /// `'friendship'` for the friendship axis; `'group'` for the Sprint 3
  /// group axis.
  static const String paramContextType = 'context_type';

  /// Number of settlement rows rendered (post 50-item cap).
  static const String paramItemCount = 'item_count';

  /// Mapped error code (`'permission-denied'` / `'unavailable'` / the
  /// raw `FirebaseException.code` / `'unknown'`).
  static const String paramErrorCode = 'error_code';

  // ---------------------------------------------------------------
  // Context-type enum tokens.
  // ---------------------------------------------------------------

  /// Friendship-axis context-type token.
  static const String contextTypeFriendship = 'friendship';

  /// Group-axis context-type token (Sprint 3 Groups epic).
  static const String contextTypeGroup = 'group';
}
