import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/providers/firebase_providers.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';

// ---------------------------------------------------------------------------
// Abstract repository
// ---------------------------------------------------------------------------

/// Abstraction over Firestore for the activity-feed read path, for
/// testability. Production code uses [FirestoreActivityFeedRepository].
// ignore: one_member_abstracts
abstract class ActivityFeedRepository {
  /// Watches the current user's activity items at
  /// `activity/{userId}/items`, ordered by `createdAt` descending.
  ///
  /// Real-time stream — emits a new list on every snapshot. Malformed
  /// documents are dropped (with a structured-log breadcrumb via the
  /// repository's `onParseFailure` sink). READ-ONLY: the activity
  /// collection rules permit server-only writes (FR-EX-07 architect
  /// §2.9; rules block at `match /activity/{userId}/items/{itemId}`).
  Stream<List<ActivityFeedItem>> watchItems(String userId);
}

// ---------------------------------------------------------------------------
// Parse-failure observability sink
// ---------------------------------------------------------------------------

/// Function shape used by [FirestoreActivityFeedRepository] to surface
/// malformed-activity-item parse failures into production observability.
typedef ActivityParseFailureSink = void Function(String message);

/// Default observability sink for malformed-activity-item parse
/// failures. Routes through [developer.log] under the canonical
/// `activity_parse_failure` event name so silent corruption stays
/// visible in production logs and Crashlytics breadcrumbs (when
/// integrated).
void logActivityParseFailure(String message) {
  developer.log(
    message,
    name: 'activity_parse_failure',
    level: 900, // SEVERE per developer.log convention.
  );
}

// ---------------------------------------------------------------------------
// Production repository
// ---------------------------------------------------------------------------

/// Firestore-backed implementation of [ActivityFeedRepository].
class FirestoreActivityFeedRepository implements ActivityFeedRepository {
  /// Creates a [FirestoreActivityFeedRepository].
  ///
  /// [onParseFailure] receives a breadcrumb whenever
  /// `ActivityFeedItem.fromFirestore` drops a malformed document.
  /// Defaults to [logActivityParseFailure] for production routing.
  const FirestoreActivityFeedRepository({
    required FirebaseFirestore firestore,
    ActivityParseFailureSink onParseFailure = logActivityParseFailure,
  }) : _firestore = firestore,
       _onParseFailure = onParseFailure;

  final FirebaseFirestore _firestore;
  final ActivityParseFailureSink _onParseFailure;

  @override
  Stream<List<ActivityFeedItem>> watchItems(String userId) {
    return _firestore
        .collection('activity')
        .doc(userId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List<ActivityFeedItem>.unmodifiable(
            snapshot.docs
                .map(
                  (doc) => ActivityFeedItem.fromFirestore(
                    id: doc.id,
                    data: doc.data(),
                    onParseFailure: _onParseFailure,
                  ),
                )
                .whereType<ActivityFeedItem>(),
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides an [ActivityFeedRepository] backed by Firestore. Override
/// in widget tests with a fake implementation.
final activityFeedRepositoryProvider = Provider<ActivityFeedRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FirestoreActivityFeedRepository(firestore: firestore);
});
