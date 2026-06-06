import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/data/user_repository.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

// ---------------------------------------------------------------------------
// Abstract store
// ---------------------------------------------------------------------------

/// Abstraction over Firestore document operations for settlements.
///
/// PR #42 only exposes the read-side. FR-SE-08 / PR #43 will extend
/// this with `createSettlement(...)`. The store / repository / fake
/// pattern mirrors [`FriendshipStore`](../../friends/data/friendship_repository.dart)
/// and [`ExpenseStore`](../../expenses/data/expense_repository.dart) so
/// the FR-SE-08 diff stays focused on its write logic.
// ignore: one_member_abstracts
abstract class SettlementStore {
  /// Watches settlements scoped to a single context (a friendship or a
  /// group), ordered by `date` descending.
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  });
}

// ---------------------------------------------------------------------------
// Parse-failure observability sink
// ---------------------------------------------------------------------------

/// Function shape used by [FirestoreSettlementStore] to surface
/// malformed-settlement-document parse failures into production
/// observability.
typedef SettlementParseFailureSink = void Function(String message);

/// Default observability sink for malformed-settlement-document parse
/// failures. Routes through [developer.log] under the canonical
/// `settlement_parse_failure` event name so silent corruption stays
/// visible in production logs and Crashlytics breadcrumbs (when
/// integrated).
///
/// Parallels [`logFriendshipParseFailure`](../../friends/data/friendship_repository.dart).
void logSettlementParseFailure(String message) {
  developer.log(
    message,
    name: 'settlement_parse_failure',
    level: 900, // SEVERE per developer.log convention.
  );
}

// ---------------------------------------------------------------------------
// Production store
// ---------------------------------------------------------------------------

/// Firestore-backed implementation of [SettlementStore].
class FirestoreSettlementStore implements SettlementStore {
  /// Creates a [FirestoreSettlementStore].
  ///
  /// [onParseFailure] receives a breadcrumb whenever
  /// [SettlementDoc.fromFirestore] rejects a malformed document.
  /// Defaults to [logSettlementParseFailure] so production silently
  /// routes corruption into observability.
  const FirestoreSettlementStore({
    required FirebaseFirestore firestore,
    SettlementParseFailureSink onParseFailure = logSettlementParseFailure,
  }) : _firestore = firestore,
       _onParseFailure = onParseFailure;

  final FirebaseFirestore _firestore;
  final SettlementParseFailureSink _onParseFailure;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('settlements');

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    return _collection
        .where('contextType', isEqualTo: contextType)
        .where('contextId', isEqualTo: contextId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SettlementDoc.fromFirestore(
                  id: doc.id,
                  data: doc.data(),
                  onParseFailure: _onParseFailure,
                ),
              )
              .whereType<SettlementDoc>()
              .toList(growable: false),
        );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Repository that manages settlement reads. The Friend Detail screen
/// consumes this; FR-SE-08 / PR #43 will pair this with the write path
/// (`createSettlement`).
///
/// READ-ONLY: this class never writes to Firestore. The
/// `verificationStatus` field on returned documents is client-read-only
/// per ARCH-EXT-06.
class SettlementRepository {
  /// Creates a [SettlementRepository].
  const SettlementRepository({required SettlementStore store}) : _store = store;

  final SettlementStore _store;

  /// Watches non-deleted settlements scoped to a single context,
  /// ordered by `date` descending. Soft-deleted entries are excluded
  /// from the projected list.
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) {
    return _store
        .watchByContext(contextType: contextType, contextId: contextId)
        .map(
          (docs) => docs.where((doc) => !doc.deleted).toList(growable: false),
        );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Production binding: wraps a [FirestoreSettlementStore] around the
/// app-wide [firebaseFirestoreProvider]. Tests override this provider
/// with a fake.
final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return SettlementRepository(
    store: FirestoreSettlementStore(firestore: firestore),
  );
});
