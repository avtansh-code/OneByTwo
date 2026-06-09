/// FR-SE-09 Send Reminder — typed success result.
///
/// Returned by `ReminderRepository.sendReminder` when the
/// `sendReminderNotification` callable resolves with `{ success: true,
/// nextAllowedAtIso }`. The `nextAllowedAt` field is the server-
/// computed earliest time at which the same sender may dispatch
/// another reminder to the same recipient (24h after the successful
/// send per SRS §4.6).
part of 'reminder_send_error.dart';

/// The successful variant of [ReminderSendResult].
class ReminderSendSuccess extends ReminderSendResult {
  /// Creates a [ReminderSendSuccess].
  const ReminderSendSuccess({required this.nextAllowedAt});

  /// Earliest UTC time the sender may issue another reminder to the
  /// same recipient. Mirrored to `reminderCooldownProvider` by the
  /// send controller so the OBTSettleUpCard receiving-direction
  /// button is disabled until this time has passed.
  final DateTime nextAllowedAt;
}
