/// FR-SE-09 Send Reminder — typed result hierarchy.
///
/// Discriminated union returned by `ReminderRepository.sendReminder`.
/// The success variant lives in `reminder_send_success.dart` via
/// `part`; this file holds the seven error variants that mirror the
/// typed `HttpsError.details.errorCode` values surfaced by the
/// `sendReminderNotification` callable.
library;

part 'reminder_send_success.dart';

/// Sealed base class — every `ReminderRepository.sendReminder`
/// outcome is one of the implementing variants. UI consumers should
/// switch on the runtime type and never instantiate the base class
/// themselves.
sealed class ReminderSendResult {
  /// Creates a [ReminderSendResult].
  const ReminderSendResult();
}

/// The callable rejected the request because a prior send to the
/// same recipient happened within the last 24 hours.
class ReminderSendRateLimited extends ReminderSendResult {
  /// Creates a [ReminderSendRateLimited] with the server-returned
  /// [nextAllowedAt] timestamp.
  const ReminderSendRateLimited({required this.nextAllowedAt});

  /// Earliest UTC time the sender may issue another reminder to the
  /// same recipient.
  final DateTime nextAllowedAt;
}

/// The recipient does not owe the sender per `simplifiedBalances`
/// on the parent context. Race-condition outcome (the friend may
/// have just settled between render and tap).
class ReminderSendRecipientDoesntOwe extends ReminderSendResult {
  /// Creates a [ReminderSendRecipientDoesntOwe].
  const ReminderSendRecipientDoesntOwe();
}

/// The recipient has `notificationPrefs.reminder == false` and has
/// opted out of reminder notifications. The rate-limit is NOT
/// consumed.
class ReminderSendRecipientPrefsDisabled extends ReminderSendResult {
  /// Creates a [ReminderSendRecipientPrefsDisabled].
  const ReminderSendRecipientPrefsDisabled();
}

/// The recipient has no FCM tokens registered (they have not granted
/// push permission). The rate-limit is NOT consumed.
class ReminderSendRecipientNoTokens extends ReminderSendResult {
  /// Creates a [ReminderSendRecipientNoTokens].
  const ReminderSendRecipientNoTokens();
}

/// Catch-all for any other callable failure: network unreachable,
/// `INTERNAL`, `FCM_DISPATCH_FAILED`, `GROUP_CONTEXT_NOT_SUPPORTED`,
/// or a non-callable Dart-side exception. The [errorCode] is the
/// server-side `details.errorCode` when available, or `'UNKNOWN'`
/// for opaque non-callable failures.
class ReminderSendFailed extends ReminderSendResult {
  /// Creates a [ReminderSendFailed].
  ReminderSendFailed(this.errorCode);

  /// Server-side error code (e.g. `'FCM_DISPATCH_FAILED'`, `'INTERNAL'`,
  /// `'GROUP_CONTEXT_NOT_SUPPORTED'`) or `'UNKNOWN'` for opaque
  /// non-callable failures.
  final String errorCode;
}
