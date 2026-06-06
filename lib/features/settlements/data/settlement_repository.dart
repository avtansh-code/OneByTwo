import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/data/user_repository.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/settlements/domain/settlement_create_error.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

// Re-export the typed error from the domain layer so callers may
// import either path. The architect notes group the error type with
// the repository file; the domain location is the canonical
// definition.
export 'package:onebytwo/features/settlements/domain/settlement_create_error.dart';

// ---------------------------------------------------------------------------
// Abstract store
// ---------------------------------------------------------------------------

/// Abstraction over Firestore document operations for settlements.
///
/// FR-FR-04 (PR #42) shipped the read-side `watchByContext`. FR-SE-05
/// (PR #43) adds the write-side `createSettlement` — the first client
/// producer of top-level `settlements/{settlementId}` documents.
abstract class SettlementStore {
  /// Watches settlements scoped to a single context (a friendship or a
  /// group), ordered by `date` descending.
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  });

  /// Persists [data] to `settlements/{auto-id}` and returns the
  /// generated document ID. Implementations MUST NOT mutate [data].
  /// The map is produced by [SettlementDoc.toCreateMap] and satisfies
  /// every predicate in `firestore.rules` lines 379–489.
  Future<String> createSettlement({required Map<String, dynamic> data});
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

  @override
  Future<String> createSettlement({
    required Map<String, dynamic> data,
  }) async {
    final ref = await _collection.add(data);
    return ref.id;
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Repository that manages settlement reads and writes.
///
/// FR-FR-04 (PR #42) shipped the read-side. FR-SE-05 (PR #43) adds the
/// write-side `createSettlement(...)` which is the first client
/// producer of top-level `settlements/{settlementId}` documents.
///
/// **Invariant 2 (`simplifiedBalances` server-maintained).** This
/// repository writes ONLY to the top-level `settlements` collection.
/// `simplifiedBalances` on the parent friendship / group document is
/// folded by the `onSettlementWrite` trigger (PR #37) in a single
/// transaction; this client never touches that field.
///
/// `verificationStatus` is client-read-only per ARCH-EXT-06; the
/// write payload always carries `'unverified'`.
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

  /// Persists [doc] to `settlements/{auto-id}` and returns the
  /// generated document ID. Translates [FirebaseException]s into
  /// [SettlementCreateError] with a typed [SettlementCreateErrorType]
  /// so the controller never has to interpret raw Firebase codes.
  ///
  /// The write payload is produced by [SettlementDoc.toCreateMap] and
  /// satisfies every predicate in `firestore.rules` lines 379–489.
  Future<String> createSettlement({required SettlementDoc doc}) async {
    try {
      return await _store.createSettlement(data: doc.toCreateMap());
    } on FirebaseException catch (e, st) {
      throw SettlementCreateError(
        type: _mapFirebaseCode(e.code),
        underlying: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw SettlementCreateError(
        type: SettlementCreateErrorType.unknown,
        underlying: e,
        stackTrace: st,
      );
    }
  }

  SettlementCreateErrorType _mapFirebaseCode(String code) {
    switch (code) {
      case 'permission-denied':
        return SettlementCreateErrorType.permissionDenied;
      case 'unavailable':
        return SettlementCreateErrorType.network;
      default:
        return SettlementCreateErrorType.unknown;
    }
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
