/// Telemetry for the FR-AU-09 account-deletion flow (SCR-28 Part B).
///
/// All seven events are PII-free and pre-declared in
/// `docs/design/07-technical/telemetry-plan.md` §1.7. Only
/// [failed] carries a parameter (`error_code`), and that value is a
/// non-identifying catalogue code — never the uid or phone number
/// (SRS section 5.4 / line 308).
abstract final class DeleteAccountTelemetry {
  /// User tapped the "Delete Account" row on Profile View (Step A opens).
  static const String started = 'delete_account_started';

  /// User tapped "Continue" on the Step A warning.
  static const String warningContinued = 'delete_account_warning_continued';

  /// User tapped "Cancel" on the Step A warning.
  static const String warningCancelled = 'delete_account_warning_cancelled';

  /// OTP verified in Step B (re-authentication completed).
  static const String reauthCompleted = 'delete_account_reauth_completed';

  /// User tapped "Delete My Account" in Step C (cascade requested).
  static const String confirmed = 'delete_account_confirmed';

  /// The `deleteUserAccount` Cloud Function returned success (Step E).
  static const String completed = 'delete_account_completed';

  /// The `deleteUserAccount` Cloud Function returned an error or timed out.
  static const String failed = 'delete_account_failed';

  /// Parameter key for [failed] — a PII-free catalogue / outcome code.
  static const String paramErrorCode = 'error_code';
}
