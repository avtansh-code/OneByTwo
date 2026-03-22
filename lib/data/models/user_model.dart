import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import 'notification_prefs_model.dart';

part 'user_model.g.dart';

/// Firestore DTO representing a user document at `users/{uid}`.
///
/// This model handles JSON round-trip via `json_serializable` and provides
/// convenience factories for reading Firestore [DocumentSnapshot]s (which use
/// [Timestamp] instead of ISO-8601 strings).
///
/// ## Timestamps
/// Firestore stores timestamps as [Timestamp] objects. The [fromFirestore]
/// factory converts them to ISO-8601 strings before passing to
/// `json_serializable`, which then parses them into [DateTime].
///
/// ## Soft Delete
/// Documents are never hard-deleted. The [isDeleted], [deletedAt], and
/// [deletedBy] fields support the app's soft-delete pattern.
@JsonSerializable(explicitToJson: true)
class UserModel {
  /// Creates a [UserModel] with the given fields.
  const UserModel({
    required this.uid,
    required this.name,
    this.email,
    required this.phone,
    this.avatarUrl,
    this.language = 'en',
    required this.createdAt,
    required this.updatedAt,
    this.fcmTokens = const [],
    this.notificationPrefs = const NotificationPrefsModel(),
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Deserializes a [UserModel] from a JSON map.
  ///
  /// Expects [DateTime] fields to be ISO-8601 strings — use [fromFirestore]
  /// when reading directly from a Firestore [DocumentSnapshot].
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Creates a [UserModel] from a Firestore [DocumentSnapshot].
  ///
  /// Converts Firestore [Timestamp] fields (`createdAt`, `updatedAt`,
  /// `deletedAt`) to ISO-8601 strings so that `json_serializable` can
  /// deserialize them as [DateTime].
  ///
  /// The document ID is used as the [uid] field, overriding any `uid`
  /// value stored inside the document data.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final json = <String, dynamic>{
      ...data,
      'uid': doc.id,
      'createdAt': (data['createdAt'] as Timestamp?)
          ?.toDate()
          .toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp?)
          ?.toDate()
          .toIso8601String(),
      'deletedAt': (data['deletedAt'] as Timestamp?)
          ?.toDate()
          .toIso8601String(),
    };
    return UserModel.fromJson(json);
  }

  /// Firebase Auth UID. Matches the Firestore document ID.
  final String uid;

  /// The user's display name.
  final String name;

  /// The user's email address, if provided.
  final String? email;

  /// The user's phone number in E.164 format (e.g., `+91XXXXXXXXXX`).
  final String phone;

  /// HTTPS URL pointing to the user's avatar image.
  final String? avatarUrl;

  /// The user's preferred language as an IETF tag (`'en'` or `'hi'`).
  final String language;

  /// Timestamp when the user account was created.
  final DateTime createdAt;

  /// Timestamp when the user profile was last updated.
  final DateTime updatedAt;

  /// Firebase Cloud Messaging tokens for push notifications.
  final List<String> fcmTokens;

  /// Nested notification preferences subdocument.
  final NotificationPrefsModel notificationPrefs;

  /// Whether this user has been soft-deleted.
  final bool isDeleted;

  /// Timestamp when the user was soft-deleted. `null` if active.
  final DateTime? deletedAt;

  /// UID of the user or admin who initiated the soft delete.
  final String? deletedBy;

  /// Serializes this model to a JSON map.
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Converts to a Firestore-compatible map.
  ///
  /// When [isNew] is `true` (creating a new document), both `createdAt` and
  /// `updatedAt` are replaced with [FieldValue.serverTimestamp()] so the
  /// server sets the canonical timestamp.
  ///
  /// When [isNew] is `false` (updating), only `updatedAt` is replaced with
  /// a server timestamp and `createdAt` is removed from the map to avoid
  /// overwriting the original creation timestamp.
  ///
  /// The `uid` field is also removed since it is stored as the document ID
  /// rather than as a field inside the document.
  Map<String, dynamic> toFirestore({bool isNew = false}) {
    final json = toJson();
    // uid is the document ID, not a document field.
    json.remove('uid');
    if (isNew) {
      json['createdAt'] = FieldValue.serverTimestamp();
      json['updatedAt'] = FieldValue.serverTimestamp();
    } else {
      json['updatedAt'] = FieldValue.serverTimestamp();
      json.remove('createdAt');
    }
    // Remove null soft-delete fields to keep documents clean.
    if (deletedAt == null) json.remove('deletedAt');
    if (deletedBy == null) json.remove('deletedBy');
    return json;
  }
}
