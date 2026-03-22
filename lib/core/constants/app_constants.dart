/// App-wide constants for OneByTwo.
///
/// All configuration values that are used across the application should be
/// defined here. This class cannot be instantiated or extended.
abstract final class AppConstants {
  /// The display name of the application.
  static const String appName = 'One By Two';

  /// The current application version string.
  static const String appVersion = '0.1.0';

  // ── Soft Delete ──────────────────────────────────────────────────────

  /// Duration in seconds for the undo snackbar after a soft delete.
  static const int undoDeleteDurationSeconds = 30;

  // ── Group Limits ─────────────────────────────────────────────────────

  /// Maximum number of members allowed in a single group.
  static const int maxGroupMembers = 50;

  /// Maximum character length for a group name.
  static const int maxGroupNameLength = 50;

  /// Maximum number of expenses allowed per group.
  static const int maxExpensesPerGroup = 10000;

  // ── Expense Limits ───────────────────────────────────────────────────

  /// Maximum character length for an expense description.
  static const int maxExpenseDescriptionLength = 100;

  /// Maximum character length for expense or settlement notes.
  static const int maxNotesLength = 500;

  // ── Auth / OTP ───────────────────────────────────────────────────────

  /// Default country calling code for Indian phone numbers.
  static const String defaultCountryCode = '+91';

  /// Expected length of the one-time password.
  static const int otpLength = 6;

  /// Minimum delay in seconds before allowing OTP resend.
  static const int otpResendDelaySeconds = 30;

  // ── Currency ─────────────────────────────────────────────────────────

  /// The Indian Rupee symbol used for display formatting.
  static const String currencySymbol = '₹';

  /// Number of paise in one rupee (1 ₹ = 100 paise).
  ///
  /// All monetary values in the app are stored as [int] paise.
  /// For example, ₹100.50 is represented as `10050`.
  static const int paisePrecision = 100;

  // ── Firebase ─────────────────────────────────────────────────────────

  /// The Google Cloud region used for Cloud Functions and Firestore.
  static const String firebaseRegion = 'asia-south1';
}
