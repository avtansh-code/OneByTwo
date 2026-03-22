import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_locale.dart';
import 'notification_prefs.dart';

part 'user.freezed.dart';

/// Immutable domain entity representing an authenticated user in OneByTwo.
///
/// This entity is **pure Dart** — it has no dependency on Flutter, Firebase,
/// or any data/presentation layer. It is the single source of truth for
/// user-related state within the domain layer.
///
/// ## Soft Delete
/// Users are never hard-deleted. Instead, [isDeleted] is set to `true`,
/// [deletedAt] records the timestamp, and [deletedBy] records who initiated
/// the deletion. Cloud Functions handle permanent cleanup after the
/// retention period.
@freezed
class User with _$User {
  /// Creates a [User] entity.
  const factory User({
    /// Firebase Auth UID. Uniquely identifies this user across the app.
    required String id,

    /// The user's display name. Must be non-empty.
    required String name,

    /// The user's email address, if provided. Optional.
    String? email,

    /// The user's phone number in E.164 format (e.g., `+91XXXXXXXXXX`).
    required String phone,

    /// HTTPS URL pointing to the user's avatar image. `null` if not set.
    String? avatarUrl,

    /// The user's preferred app language. Defaults to [AppLocale.en].
    @Default(AppLocale.en) AppLocale language,

    /// Timestamp when the user account was created.
    required DateTime createdAt,

    /// Timestamp when the user profile was last updated.
    required DateTime updatedAt,

    /// List of Firebase Cloud Messaging tokens for push notifications.
    ///
    /// A user may have multiple tokens if they are signed in on
    /// multiple devices. Defaults to an empty list.
    @Default([]) List<String> fcmTokens,

    /// The user's notification preferences. Defaults to [NotificationPrefs()]
    /// which enables expense, settlement, and reminder notifications.
    @Default(NotificationPrefs()) NotificationPrefs notificationPrefs,

    /// Whether this user has been soft-deleted. Defaults to `false`.
    @Default(false) bool isDeleted,

    /// Timestamp when the user was soft-deleted. `null` if not deleted.
    DateTime? deletedAt,

    /// UID of the user or admin who initiated the soft delete.
    /// `null` if not deleted.
    String? deletedBy,
  }) = _User;
}
