import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/domain/user_model.dart';

/// Provides a [FirebaseFirestore] instance for dependency injection.
///
/// Override in tests to inject a fake or mock instance.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Provides a [FirebaseStorage] instance for dependency injection.
///
/// Override in tests to inject a fake or mock instance.
final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

/// Repository for user profile operations against Firestore and
/// Firebase Storage.
///
/// See `docs/design/07-technical/firestore-schema.md` for the
/// `users/{userId}` document schema and Storage layout for avatars.
class UserRepository {
  /// Creates a [UserRepository].
  const UserRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _firestore = firestore,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Reads the user document for [uid].
  ///
  /// Returns `null` if the document does not exist.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Creates a user document at `users/{uid}`.
  ///
  /// Uses [FieldValue.serverTimestamp] for `createdAt` and
  /// `updatedAt` via [UserModel.toCreateMap].
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(
          UserModel.toCreateMap(
            phoneNumber: phoneNumber,
            displayName: displayName,
            photoUrl: photoUrl,
          ),
        );
  }

  /// Uploads an avatar image to `avatars/{uid}` and returns
  /// the download URL.
  Future<String> uploadAvatar(String uid, String filePath) async {
    final ref = _storage.ref('avatars/$uid');
    await ref.putFile(File(filePath));
    return ref.getDownloadURL();
  }
}

/// Riverpod provider for [UserRepository].
///
/// Override in tests with a fake implementation to avoid
/// Firebase initialisation.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  ),
);
