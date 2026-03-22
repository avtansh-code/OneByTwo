import 'package:one_by_two/data/models/notification_prefs_model.dart';
import 'package:one_by_two/data/models/user_model.dart';
import 'package:one_by_two/domain/entities/app_locale.dart';
import 'package:one_by_two/domain/entities/notification_prefs.dart';
import 'package:one_by_two/domain/entities/user.dart';

/// Maps between the domain [User] entity and the data-layer [UserModel] DTO.
///
/// This mapper isolates the domain layer from Firestore-specific model details.
/// All conversions between [AppLocale] ↔ [String] and
/// [NotificationPrefs] ↔ [NotificationPrefsModel] are handled here.
class UserMapper {
  const UserMapper._();

  /// Converts a [UserModel] DTO to a domain [User] entity.
  ///
  /// The [UserModel.language] string is parsed to an [AppLocale] enum value.
  /// If the string does not match any known locale, [AppLocale.en] is used
  /// as the default.
  static User toEntity(UserModel model) {
    return User(
      id: model.uid,
      name: model.name,
      email: model.email,
      phone: model.phone,
      avatarUrl: model.avatarUrl,
      language: _parseLocale(model.language),
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      fcmTokens: model.fcmTokens,
      notificationPrefs: _prefsToEntity(model.notificationPrefs),
      isDeleted: model.isDeleted,
      deletedAt: model.deletedAt,
      deletedBy: model.deletedBy,
    );
  }

  /// Converts a domain [User] entity to a [UserModel] DTO.
  ///
  /// The [User.language] enum is serialized to its name string (e.g., `'en'`).
  static UserModel toModel(User entity) {
    return UserModel(
      uid: entity.id,
      name: entity.name,
      email: entity.email,
      phone: entity.phone,
      avatarUrl: entity.avatarUrl,
      language: entity.language.name,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      fcmTokens: entity.fcmTokens,
      notificationPrefs: _prefsToModel(entity.notificationPrefs),
      isDeleted: entity.isDeleted,
      deletedAt: entity.deletedAt,
      deletedBy: entity.deletedBy,
    );
  }

  /// Parses a language string to an [AppLocale] enum value.
  ///
  /// Falls back to [AppLocale.en] if the string is not recognized.
  static AppLocale _parseLocale(String language) {
    return AppLocale.values.asNameMap()[language] ?? AppLocale.en;
  }

  /// Converts a [NotificationPrefsModel] to a domain [NotificationPrefs].
  static NotificationPrefs _prefsToEntity(NotificationPrefsModel model) {
    return NotificationPrefs(
      expenses: model.expenses,
      settlements: model.settlements,
      reminders: model.reminders,
      weeklyDigest: model.weeklyDigest,
    );
  }

  /// Converts a domain [NotificationPrefs] to a [NotificationPrefsModel].
  static NotificationPrefsModel _prefsToModel(NotificationPrefs prefs) {
    return NotificationPrefsModel(
      expenses: prefs.expenses,
      settlements: prefs.settlements,
      reminders: prefs.reminders,
      weeklyDigest: prefs.weeklyDigest,
    );
  }
}
