import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Minimal immutable representation of an authenticated user.
///
/// Decoupled from the Firebase [User] object to keep domain logic
/// framework-agnostic. Does not include profile fields (display name,
/// photo URL) -- those belong to the `UserProfile` model in PR #8.
@immutable
class AuthUser {
  /// Creates an [AuthUser].
  const AuthUser({required this.uid, this.phoneNumber, this.isNewUser = false});

  /// Creates an [AuthUser] from a Firebase [UserCredential].
  factory AuthUser.fromUserCredential(UserCredential credential) {
    final user = credential.user!;
    return AuthUser(
      uid: user.uid,
      phoneNumber: user.phoneNumber,
      isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
    );
  }

  /// Creates an [AuthUser] from a Firebase [User].
  factory AuthUser.fromFirebaseUser(User user) =>
      AuthUser(uid: user.uid, phoneNumber: user.phoneNumber);

  /// The unique user identifier (Firestore document key).
  final String uid;

  /// The verified E.164 phone number, or `null` if unavailable.
  final String? phoneNumber;

  /// Whether this is the first sign-in for this user.
  final bool isNewUser;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          phoneNumber == other.phoneNumber &&
          isNewUser == other.isNewUser;

  @override
  int get hashCode => Object.hash(uid, phoneNumber, isNewUser);
}
