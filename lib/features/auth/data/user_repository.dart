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
    final data = UserModel.toCreateMap(
      phoneNumber: phoneNumber,
      displayName: displayName,
      photoUrl: photoUrl,
    );
    await _firestore.collection('users').doc(uid).set(data);
  }

  /// Uploads an avatar image to `avatars/{uid}` and returns
  /// the download URL.
  Future<String> uploadAvatar(String uid, String filePath) async {
    final ref = _storage.ref('avatars/$uid');
    await ref.putFile(File(filePath));
    return ref.getDownloadURL();
  }

  /// Updates the profile fields for the user document at
  /// `users/{uid}`.
  ///
  /// Only non-null fields are written. If [removePhoto] is true,
  /// the `photoUrl` field is set to `null` in Firestore.
  /// Always sets `updatedAt` to the server timestamp.
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (removePhoto) {
      updates['photoUrl'] = null;
    } else if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }
    await _firestore.collection('users').doc(uid).update(updates);
  }

  /// Updates the user's notification preferences at
  /// `users/{uid}.notificationPrefs.*` via a dot-path partial-map
  /// Firestore merge.
  ///
  /// Only the keys present in [prefs] are written; untouched keys are
  /// preserved by Firestore's dot-path merge semantics. Always sets
  /// `updatedAt` to the server timestamp. Empty [prefs] is a no-op so
  /// callers can flush an "empty" debounce without issuing a wasted
  /// write.
  ///
  /// Per FR-PR-03 architect §2.2 + AC-23: this writer NEVER touches
  /// `displayName`, `photoUrl`, `fcmTokens`, `locale`, `phoneNumber`,
  /// or `createdAt`. The Firestore security rules enforce the same
  /// invariant server-side (`request.resource.data.diff(...).changedKeys()`).
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {
    if (prefs.isEmpty) return;
    await _firestore.collection('users').doc(uid).update(<String, Object?>{
      for (final entry in prefs.entries)
        'notificationPrefs.${entry.key}': entry.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the user's phone number at `users/{uid}.phoneNumber` after a
  /// successful FR-PR-02 re-verification.
  ///
  /// The caller MUST have already (1) called
  /// `currentUser.updatePhoneNumber(...)` so the new number is the verified
  /// auth phone, and (2) forced an ID-token refresh (`getIdToken(true)`) so
  /// `request.auth.token.phone_number` matches [phoneNumber]. Otherwise the
  /// relaxed `isValidUserUpdate()` rule rejects this write against a stale
  /// token claim (see ADR-0015). Always sets `updatedAt` to the server
  /// timestamp; writes no other field.
  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {
    await _firestore.collection('users').doc(uid).update(<String, Object?>{
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the avatar file at `avatars/{uid}` from
  /// Firebase Storage.
  ///
  /// Ignores `object-not-found` errors, as the avatar may not
  /// exist (e.g., user never uploaded one).
  Future<void> deleteAvatar(String uid) async {
    try {
      await _storage.ref('avatars/$uid').delete();
    } on FirebaseException catch (e) {
      // Ignore "object-not-found" — avatar may not exist.
      if (e.code != 'object-not-found') rethrow;
    }
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
