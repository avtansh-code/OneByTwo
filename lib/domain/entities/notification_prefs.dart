import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_prefs.freezed.dart';

/// Immutable notification preferences for a user.
///
/// Controls which types of push notifications the user receives.
/// All flags default to their most useful values for new users:
/// - Expense, settlement, and reminder notifications are on by default.
/// - Weekly digest is off by default (opt-in).
@freezed
class NotificationPrefs with _$NotificationPrefs {
  /// Creates a [NotificationPrefs] instance.
  const factory NotificationPrefs({
    /// Whether to receive notifications when a new expense is added
    /// or an existing expense is updated in a group.
    @Default(true) bool expenses,

    /// Whether to receive notifications when a settlement is recorded.
    @Default(true) bool settlements,

    /// Whether to receive payment reminders from other users.
    @Default(true) bool reminders,

    /// Whether to receive a weekly summary email/push of balances.
    @Default(false) bool weeklyDigest,
  }) = _NotificationPrefs;
}
