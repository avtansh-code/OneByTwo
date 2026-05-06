import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/data/user_repository.dart';

// ---------------------------------------------------------------------------
// Abstract store
// ---------------------------------------------------------------------------

/// Abstraction over Firestore document operations for testability.
abstract class FriendshipStore {
  /// Writes [data] to the document at [path].
  Future<void> set(String path, Map<String, dynamic> data);

  /// Returns whether a document exists at [path].
  Future<bool> exists(String path);

  /// Returns the document data at [path], or null if it does not exist.
  Future<Map<String, dynamic>?> get(String path);
}

// ---------------------------------------------------------------------------
// Production store
// ---------------------------------------------------------------------------

/// Firestore-backed implementation of [FriendshipStore].
class FirestoreFriendshipStore implements FriendshipStore {
  /// Creates a [FirestoreFriendshipStore].
  const FirestoreFriendshipStore({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('friendships');

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    await _collection.doc(path).set(data);
  }

  @override
  Future<bool> exists(String path) async {
    final snapshot = await _collection.doc(path).get();
    return snapshot.exists;
  }

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final snapshot = await _collection.doc(path).get();
    return snapshot.data();
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Repository that manages friendship documents with deterministic IDs.
///
/// The document ID is formed by sorting the two user UIDs
/// lexicographically and joining them with an underscore.
class FriendshipRepository {
  /// Creates a [FriendshipRepository].
  const FriendshipRepository({required FriendshipStore store}) : _store = store;

  final FriendshipStore _store;

  /// Creates a friendship between [currentUserId] and [otherUserId].
  ///
  /// Returns the deterministic friendship ID. The operation is
  /// idempotent: calling it twice with the same arguments overwrites
  /// the document with the same data and returns the same ID.
  Future<String> createFriendship(
    String currentUserId,
    String otherUserId,
  ) async {
    final sorted = [currentUserId, otherUserId]..sort();
    final friendshipId = '${sorted[0]}_${sorted[1]}';

    // Exactly 3 fields. No simplifiedBalances (invariant 2).
    await _store.set(friendshipId, {
      'memberIds': sorted,
      'createdBy': currentUserId,
      'lastActivityAt': DateTime.now().toIso8601String(),
    });

    return friendshipId;
  }

  /// Returns whether a friendship exists between the two users.
  Future<bool> friendshipExists(String userId1, String userId2) async {
    final sorted = [userId1, userId2]..sort();
    final friendshipId = '${sorted[0]}_${sorted[1]}';
    return _store.exists(friendshipId);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides a [FriendshipRepository] backed by Firestore.
final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FriendshipRepository(
    store: FirestoreFriendshipStore(firestore: firestore),
  );
});
