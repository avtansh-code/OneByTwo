import 'package:json_annotation/json_annotation.dart';

part 'notification_prefs_model.g.dart';

/// Firestore DTO for user notification preferences.
///
/// Maps to the `notificationPrefs` subdocument inside a `users/{uid}` document.
/// All fields default to their most useful values for new users:
/// - Expense, settlement, and reminder notifications are **on** by default.
/// - Weekly digest is **off** by default (opt-in).
@JsonSerializable()
class NotificationPrefsModel {
  /// Creates a [NotificationPrefsModel] with optional overrides.
  const NotificationPrefsModel({
    this.expenses = true,
    this.settlements = true,
    this.reminders = true,
    this.weeklyDigest = false,
  });

  /// Deserializes a [NotificationPrefsModel] from a JSON map.
  factory NotificationPrefsModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationPrefsModelFromJson(json);

  /// Whether to receive notifications when expenses are added or updated.
  final bool expenses;

  /// Whether to receive notifications when settlements are recorded.
  final bool settlements;

  /// Whether to receive payment reminder notifications.
  final bool reminders;

  /// Whether to receive a weekly summary of balances.
  final bool weeklyDigest;

  /// Serializes this model to a JSON map.
  Map<String, dynamic> toJson() => _$NotificationPrefsModelToJson(this);
}
