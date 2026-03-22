import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:one_by_two/core/constants/firestore_paths.dart';
import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/data/models/user_model.dart';

/// Data source that wraps Firestore operations for the `users/{uid}` collection.
///
/// All Firestore interactions for user documents go through this class.
/// Paths are sourced from [FirestorePaths] — no hardcoded strings.
///
/// Firestore exceptions are caught and re-thrown as [FirestoreException]
/// for consistent error handling upstream.
class UserFirestoreSource {
  /// Creates a [UserFirestoreSource] backed by the given [FirebaseFirestore].
  UserFirestoreSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Reference to the top-level `users` collection.
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestorePaths.users);

  /// Gets a user document by [uid].
  ///
  /// Returns the [UserModel] if the document exists, or `null` if it does not.
  ///
  /// Throws [FirestoreException] if the Firestore read fails.
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to get user document',
        code: e.code,
      );
    }
  }

  /// Watches a user document at `users/{uid}` for real-time updates.
  ///
  /// Returns a [Stream] that emits the [UserModel] whenever the document
  /// changes, or `null` if the document does not exist.
  ///
  /// Uses Firestore `.snapshots()` for offline-first real-time sync.
  Stream<UserModel?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Creates a new user document at `users/{user.uid}`.
  ///
  /// Uses [UserModel.toFirestore] with `isNew: true` so that `createdAt`
  /// and `updatedAt` are set to server timestamps.
  ///
  /// Throws [FirestoreException] if the write fails.
  Future<void> createUser(UserModel user) async {
    try {
      await _usersRef.doc(user.uid).set(user.toFirestore(isNew: true));
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to create user document',
        code: e.code,
      );
    }
  }

  /// Updates an existing user document at `users/{user.uid}`.
  ///
  /// Uses [UserModel.toFirestore] with `isNew: false` so that only
  /// `updatedAt` is refreshed and the original `createdAt` is preserved.
  ///
  /// Throws [FirestoreException] if the write fails.
  Future<void> updateUser(UserModel user) async {
    try {
      await _usersRef.doc(user.uid).update(user.toFirestore());
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to update user document',
        code: e.code,
      );
    }
  }

  /// Checks whether a user document exists for the given [uid].
  ///
  /// Returns `true` if the document exists, `false` otherwise.
  ///
  /// Throws [FirestoreException] if the Firestore read fails.
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to check user existence',
        code: e.code,
      );
    }
  }
}
