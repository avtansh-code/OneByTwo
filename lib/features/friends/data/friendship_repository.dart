import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/providers/firebase_providers.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

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

  /// Watches every friendship document whose `memberIds` array contains
  /// [userId], ordered by `lastActivityAt` descending. The stream emits
  /// the latest snapshot list whenever the underlying query updates
  /// (real-time delivery — AC-6 of FR-FR-03).
  Stream<List<FriendshipDoc>> watchByMember(String userId);

  /// Watches the single friendship document at [friendshipId] for
  /// real-time updates (FR-FR-04). Emits `null` when the document
  /// does not exist; emits a [FriendshipDoc] for every snapshot update
  /// (e.g., when the `recomputeSimplifiedBalances` Cloud Function
  /// writes a new `simplifiedBalances` value after an expense or
  /// settlement is added or removed).
  Stream<FriendshipDoc?> watchById(String friendshipId);
}

// ---------------------------------------------------------------------------
// Parse-failure observability sink
// ---------------------------------------------------------------------------

/// Function shape used by [FirestoreFriendshipStore] to surface
/// malformed-friendship-document parse failures into production
/// observability.
typedef FriendshipParseFailureSink = void Function(String message);

/// Default observability sink for malformed-friendship-document parse
/// failures. Routes through [developer.log] under the canonical
/// `friendship_parse_failure` event name so silent `simplifiedBalances`
/// corruption (architect note §3 on
/// `docs/sprint-zero/stories/FR-FR-03-friends-list.md`) stays visible
/// in production logs and Crashlytics breadcrumbs (when integrated).
///
/// Use this function as the default for any new code path that parses
/// `simplifiedBalances` server data. Tests inject a custom sink via the
/// [FirestoreFriendshipStore] constructor's `onParseFailure` parameter.
void logFriendshipParseFailure(String message) {
  developer.log(
    message,
    name: 'friendship_parse_failure',
    level: 900, // SEVERE per developer.log convention.
  );
}

// ---------------------------------------------------------------------------
// Production store
// ---------------------------------------------------------------------------

/// Firestore-backed implementation of [FriendshipStore].
class FirestoreFriendshipStore implements FriendshipStore {
  /// Creates a [FirestoreFriendshipStore].
  ///
  /// [onParseFailure] receives a breadcrumb whenever
  /// `FriendshipDoc.fromFirestore` encounters malformed
  /// `simplifiedBalances` data while transforming a snapshot. Defaults
  /// to [logFriendshipParseFailure] so production silently routes
  /// corruption into observability. Tests may inject a callback that
  /// records into an inspectable list.
  const FirestoreFriendshipStore({
    required FirebaseFirestore firestore,
    FriendshipParseFailureSink onParseFailure = logFriendshipParseFailure,
  }) : _firestore = firestore,
       _onParseFailure = onParseFailure;

  final FirebaseFirestore _firestore;
  final FriendshipParseFailureSink _onParseFailure;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('friendships');

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    await _collection.doc(path).set(data);
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final snapshot = await _collection.doc(path).get();
      return snapshot.exists;
    } on FirebaseException catch (e) {
      // The friendships read rule checks `request.auth.uid in
      // resource.data.memberIds`, which raises a Null value error for a
      // document that does not exist, so the rules deny a `get` of a
      // non-existent friendship. A member can always read an existing
      // friendship, so a permission-denied here means the friendship does
      // not exist yet — treat it as not-a-duplicate. This keeps the read
      // rule strict (no social-graph enumeration) while unblocking the
      // add-friend duplicate check.
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final snapshot = await _collection.doc(path).get();
    return snapshot.data();
  }

  @override
  Stream<List<FriendshipDoc>> watchByMember(String userId) {
    return _collection
        .where('memberIds', arrayContains: userId)
        .orderBy('lastActivityAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FriendshipDoc.fromFirestore(
                  id: doc.id,
                  data: doc.data(),
                  onParseFailure: _onParseFailure,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<FriendshipDoc?> watchById(String friendshipId) {
    return _collection.doc(friendshipId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return FriendshipDoc.fromFirestore(
        id: snap.id,
        data: data,
        onParseFailure: _onParseFailure,
      );
    });
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
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    return friendshipId;
  }

  /// Returns whether a friendship exists between the two users.
  Future<bool> friendshipExists(String userId1, String userId2) async {
    final sorted = [userId1, userId2]..sort();
    final friendshipId = '${sorted[0]}_${sorted[1]}';
    return _store.exists(friendshipId);
  }

  /// Watches all friendships the given user is a member of, ordered
  /// by most-recent activity. The stream is the canonical source for
  /// the friends list (FR-FR-03) and propagates real-time updates
  /// straight through from Firestore.
  ///
  /// READ-ONLY: this method never writes to Firestore. The returned
  /// documents include the server-maintained `simplifiedBalances`
  /// field per **invariant 2**.
  Stream<List<FriendshipDoc>> watchFriendships(String currentUserId) {
    return _store.watchByMember(currentUserId);
  }

  /// Watches a single friendship document for real-time updates. Used
  /// by the Friend Detail screen (FR-FR-04) so the balance pill
  /// re-renders when `simplifiedBalances` updates after a server-side
  /// `recomputeSimplifiedBalances` cycle.
  ///
  /// Emits `null` when the document does not exist (e.g., the user is
  /// not a member of this friendship and the security rules block the
  /// read, or the friendship was deleted by the other side).
  ///
  /// READ-ONLY: this method never writes to Firestore.
  Stream<FriendshipDoc?> watchFriendship(String friendshipId) {
    return _store.watchById(friendshipId);
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
