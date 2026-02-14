import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// Data model for User in Firestore
/// 
/// This model is used for serialization to/from Firestore.
/// Includes JSON serialization annotations for Firestore operations.
@immutable
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.language = 'en',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      language: json['language'] as String? ?? 'en',
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  /// Create from Firestore document snapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'language': language,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() => toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          avatarUrl == other.avatarUrl &&
          language == other.language &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      (avatarUrl?.hashCode ?? 0) ^
      language.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, email: $email, phone: $phone, '
      'avatarUrl: $avatarUrl, language: $language, createdAt: $createdAt, updatedAt: $updatedAt)';
}
