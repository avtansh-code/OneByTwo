import 'package:one_by_two/core/errors/failure.dart';

import '../entities/user.dart';

/// Abstract interface for user profile operations.
///
/// Implementations of this repository handle Firestore CRUD operations
/// for user documents in the `users/{userId}` collection.
///
/// All methods that can fail return [Result<T>] for type-safe error
/// handling. Real-time data is exposed via [Stream] for live UI updates.
abstract class UserRepository {
  /// Gets a user by their [uid].
  ///
  /// Performs a single read from Firestore.
  ///
  /// Returns a [Result] containing:
  /// - [Success<User>] with the user entity if found.
  /// - [Failure] with a [NotFoundException] if the document does not exist,
  ///   or a [FirestoreException] if the read fails.
  Future<Result<User>> getUser(String uid);

  /// Watches a user document for real-time updates.
  ///
  /// Returns a [Stream] that emits the [User] entity whenever the
  /// Firestore document at `users/{uid}` changes. Emits `null` if
  /// the document does not exist.
  ///
  /// Uses Firestore `.snapshots()` for offline-first real-time sync.
  Stream<User?> watchUser(String uid);

  /// Creates a new user document in Firestore.
  ///
  /// [user] must have a valid [User.id] matching the Firebase Auth UID.
  ///
  /// Returns a [Result] containing:
  /// - [Success<void>] on success.
  /// - [Failure] with a [FirestoreException] if the write fails.
  Future<Result<void>> createUser(User user);

  /// Updates an existing user document in Firestore.
  ///
  /// Only the changed fields should be written. The [user] entity
  /// must contain the complete desired state.
  ///
  /// Returns a [Result] containing:
  /// - [Success<void>] on success.
  /// - [Failure] with a [FirestoreException] if the write fails.
  Future<Result<void>> updateUser(User user);

  /// Checks if a user document exists for the given [uid].
  ///
  /// Returns a [Result] containing:
  /// - [Success<bool>] — `true` if the document exists, `false` otherwise.
  /// - [Failure] with a [FirestoreException] if the check fails.
  Future<Result<bool>> userExists(String uid);
}
