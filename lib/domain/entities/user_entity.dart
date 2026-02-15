import 'package:meta/meta.dart';

/// Represents a user in the system
/// 
/// This entity is immutable and represents the domain model for a user.
/// It is independent of any data source or framework.
@immutable
class UserEntity {
  const UserEntity({
    required this.uid,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.language = 'en',
  });

  final String uid;
  final String name;
  final String phone;
  final String? avatarUrl;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          phone == other.phone &&
          avatarUrl == other.avatarUrl &&
          language == other.language &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      name.hashCode ^
      phone.hashCode ^
      (avatarUrl?.hashCode ?? 0) ^
      language.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() =>
      'UserEntity(uid: $uid, name: $name, phone: $phone, '
      'avatarUrl: $avatarUrl, language: $language, createdAt: $createdAt, updatedAt: $updatedAt)';
}
