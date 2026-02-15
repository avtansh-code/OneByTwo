import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

/// Mapper to convert between UserEntity and UserModel
class UserMapper {
  UserMapper._();

  /// Convert UserModel to UserEntity
  static UserEntity toEntity(UserModel model) {
    return UserEntity(
      uid: model.uid,
      name: model.name,
      phone: model.phone,
      avatarUrl: model.avatarUrl,
      language: model.language,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  /// Convert UserEntity to UserModel
  static UserModel toModel(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      name: entity.name,
      phone: entity.phone,
      avatarUrl: entity.avatarUrl,
      language: entity.language,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert Firebase User to UserEntity
  /// 
  /// This is used for mapping Firebase Auth User directly when
  /// Firestore profile doesn't exist yet (new user)
  static UserEntity fromFirebaseUser(firebase_auth.User firebaseUser) {
    return UserEntity(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      phone: firebaseUser.phoneNumber ?? '',
      avatarUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
