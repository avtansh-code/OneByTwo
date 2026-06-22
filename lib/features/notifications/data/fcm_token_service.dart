import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/providers/firebase_providers.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/notifications/application/firebase_messaging_provider.dart';

/// Minimal adapter over [FirebaseMessaging] for the two entry points
/// [FcmTokenService] consumes. Fakeable without implementing the
/// platform-only [FirebaseMessaging] members.
abstract class FcmMessagingAdapter {
  /// Returns the device's current FCM token, or `null` if unavailable
  /// (e.g., permission denied, no APNS token yet on iOS).
  Future<String?> getToken();

  /// Fires whenever FCM rotates the device token.
  Stream<String> get onTokenRefresh;
}

/// Production adapter wrapping [FirebaseMessaging.instance].
class FirebaseMessagingFcmAdapter implements FcmMessagingAdapter {
  /// Creates a [FirebaseMessagingFcmAdapter].
  const FirebaseMessagingFcmAdapter(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}

/// Abstraction over Firestore for the FCM-token-write operations
/// [FcmTokenService] performs.
///
/// We do NOT implement [DocumentReference] / [FirebaseFirestore] in
/// tests because both are sealed in the cloud_firestore SDK. The
/// store interface mirrors the existing `SettlementStore` /
/// `ActivityFeedRepository` pattern — production wires through
/// [FirestoreFcmTokenStore]; tests inject a hand-rolled fake.
abstract class FcmTokenStore {
  /// Append [token] to `users/{uid}.fcmTokens` via arrayUnion.
  Future<void> addToken({required String uid, required String token});

  /// Remove [token] from `users/{uid}.fcmTokens` via arrayRemove.
  Future<void> removeToken({required String uid, required String token});

  /// Atomically remove [oldToken] and add [newToken] in a single
  /// batched write so the document never has neither value (AC-2).
  Future<void> replaceTokenAtomically({
    required String uid,
    required String oldToken,
    required String newToken,
  });
}

/// Firestore-backed implementation of [FcmTokenStore].
class FirestoreFcmTokenStore implements FcmTokenStore {
  /// Creates a [FirestoreFcmTokenStore].
  const FirestoreFcmTokenStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> addToken({required String uid, required String token}) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  @override
  Future<void> removeToken({required String uid, required String token}) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  @override
  Future<void> replaceTokenAtomically({
    required String uid,
    required String oldToken,
    required String newToken,
  }) async {
    // Implementation note (FR-AC-03 AC-2 correctness).
    //
    // A previous implementation used `WriteBatch.update(...)` twice on
    // the same document and same field — once with arrayRemove and once
    // with arrayUnion. Firestore's batch semantics collapse multiple
    // updates to the same field within one batch into the LAST write,
    // silently dropping the arrayRemove side. The user's fcmTokens
    // array would accumulate stale tokens until the server-side
    // 410-cleanup path eventually pruned them.
    //
    // The current implementation uses `runTransaction`, which reads
    // the array, applies an explicit read-modify-write via the pure
    // helper [computeRefreshedTokens], and commits the resulting list
    // atomically. The helper is unit-tested in isolation so the
    // array-mutation contract is enforceable without fake_cloud_firestore.
    final docRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final raw = (snap.data()?['fcmTokens'] as List?) ?? const <dynamic>[];
      final current = raw.whereType<String>().toList(growable: false);
      final refreshed = computeRefreshedTokens(
        current: current,
        oldToken: oldToken,
        newToken: newToken,
      );
      tx.update(docRef, {'fcmTokens': refreshed});
    });
  }
}

/// Pure helper that returns the [current] FCM-token list with
/// [oldToken] removed and [newToken] added (deduplicating). The
/// production transaction in [FirestoreFcmTokenStore.replaceTokenAtomically]
/// calls this inside a `runTransaction` read-modify-write.
///
/// Extracted as a top-level function so the array-mutation contract
/// (which the batch-based implementation silently violated) is
/// independently unit-testable without faking Firestore. See
/// `test/features/notifications/data/fcm_token_service_test.dart`.
List<String> computeRefreshedTokens({
  required List<String> current,
  required String oldToken,
  required String newToken,
}) {
  final next = <String>[
    for (final t in current)
      if (t != oldToken) t,
  ];
  if (!next.contains(newToken)) next.add(newToken);
  return next;
}

/// Client-side FCM token lifecycle helper.
///
/// Responsibilities (FR-AC-03):
///   - `registerToken` — acquire the device token via
///     [FcmMessagingAdapter] and append to `users/{uid}.fcmTokens`.
///     Idempotent at the Firestore layer (arrayUnion deduplicates).
///   - `unregisterToken` — remove a token. Used by the sign-out flow
///     before `FirebaseAuth.signOut()`.
///   - `replaceToken` — single batched arrayRemove + arrayUnion so
///     there is NO window during which the user has no valid token
///     (AC-2).
///   - `startTokenRefreshListener` — subscribes to the messaging
///     adapter's `onTokenRefresh` stream and routes to `replaceToken`.
///   - `stopTokenRefreshListener` — cancels the subscription.
///
/// **Invariant 2 compliance.** This service touches ONLY
/// `users/{uid}.fcmTokens`. ZERO writes to `simplifiedBalances` or any
/// other field. The boundary-contract grep at
/// `test/features/notifications/notifications_boundary_contract_test.dart`
/// enforces this defence-in-depth.
class FcmTokenService {
  /// Creates an [FcmTokenService].
  FcmTokenService({
    required FcmTokenStore store,
    required FcmMessagingAdapter messaging,
  }) : _store = store,
       _messaging = messaging;

  final FcmTokenStore _store;
  final FcmMessagingAdapter _messaging;

  StreamSubscription<String>? _refreshSub;
  String? _currentToken;

  /// The token most recently registered with this service instance.
  /// Used by the sign-out flow to know which token to unregister.
  String? get currentToken => _currentToken;

  /// Acquires the device FCM token and writes it via arrayUnion.
  ///
  /// Returns the token (or `null` if the OS hasn't provisioned one,
  /// e.g., on the permission-denied path — AC-13).
  Future<String?> registerToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return null;
    await _store.addToken(uid: uid, token: token);
    _currentToken = token;
    return token;
  }

  /// Removes [token] from `users/{uid}.fcmTokens` via arrayRemove.
  /// Called BEFORE `FirebaseAuth.signOut()`.
  Future<void> unregisterToken(String uid, String token) async {
    await _store.removeToken(uid: uid, token: token);
    if (_currentToken == token) {
      _currentToken = null;
    }
  }

  /// Atomically replaces [oldToken] with [newToken] via a single
  /// batched write (AC-2). A no-op when `oldToken == newToken`.
  Future<void> replaceToken(
    String uid,
    String oldToken,
    String newToken,
  ) async {
    if (oldToken == newToken) return;
    await _store.replaceTokenAtomically(
      uid: uid,
      oldToken: oldToken,
      newToken: newToken,
    );
    _currentToken = newToken;
  }

  /// Subscribes to the FCM token-refresh stream and routes each new
  /// token through `replaceToken` with the cached previous token.
  ///
  /// Idempotent — calling twice cancels the previous subscription.
  void startTokenRefreshListener(String uid) {
    _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      final old = _currentToken;
      if (old == null) {
        try {
          await _store.addToken(uid: uid, token: newToken);
          _currentToken = newToken;
        } catch (e, st) {
          debugPrint(
            '[FcmTokenService] refresh (no prior) write failed: $e\n$st',
          );
        }
        return;
      }
      try {
        await replaceToken(uid, old, newToken);
      } catch (e, st) {
        // Defence-in-depth — a token-refresh write failure must NOT
        // crash the app. The next send attempt surfaces the refresh
        // via the server-side cleanup-on-410 path.
        debugPrint('[FcmTokenService] token refresh write failed: $e\n$st');
      }
    });
  }

  /// Cancels the active onTokenRefresh subscription.
  Future<void> stopTokenRefreshListener() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
  }
}

/// Riverpod provider for [FcmTokenService].
///
/// Production wiring threads [firebaseFirestoreProvider] and
/// [firebaseMessagingProvider]; tests override directly with a fake
/// implementation.
final fcmTokenServiceProvider = Provider<FcmTokenService>(
  (ref) => FcmTokenService(
    store: FirestoreFcmTokenStore(ref.watch(firebaseFirestoreProvider)),
    messaging: FirebaseMessagingFcmAdapter(
      ref.watch(firebaseMessagingProvider),
    ),
  ),
);
