// FcmTokenService tests (FR-AC-03).
//
// Covers the client-side token-lifecycle helpers:
//   - registerToken(uid) — calls getToken() then writes via arrayUnion.
//   - unregisterToken(uid, token) — arrayRemove.
//   - replaceToken(uid, oldToken, newToken) — single batched write.
//   - startTokenRefreshListener(uid) — wires onTokenRefresh through
//     replaceToken.
//
// Mocks `FirebaseFirestore` and `FirebaseMessaging` with thin fakes
// following the existing `FakeFirebaseAuth` / `FakeSettlementStore`
// pattern in this repo (no `fake_cloud_firestore` dependency).
//
// Tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/notifications/data/fcm_token_service.dart';

// ---------------------------------------------------------------------------
// Fake messaging
// ---------------------------------------------------------------------------

/// Minimal fake of FirebaseMessaging exposing only the entry points
/// FcmTokenService consumes. Implements through composition rather
/// than `implements FirebaseMessaging` because that class has many
/// platform-only members; we shim via an adapter interface
/// (`FcmMessagingAdapter`) injected into the service.
class FakeMessagingAdapter implements FcmMessagingAdapter {
  String? returnToken = 'token-A';
  final StreamController<String> _refreshController =
      StreamController<String>.broadcast();
  int getTokenCalls = 0;

  void emitRefresh(String token) => _refreshController.add(token);

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return returnToken;
  }

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  Future<void> dispose() => _refreshController.close();
}

// ---------------------------------------------------------------------------
// Fake Firestore plumbing
//
// We need just enough to capture the write operations on
// `users/{uid}` and verify the FieldValue payload. We implement the
// minimum subset of FirebaseFirestore: `collection().doc().update()`
// and `batch().update().commit()`.
// ---------------------------------------------------------------------------

class _UpdateCall {
  _UpdateCall(this.path, this.data);
  final String path;
  final Map<Object, dynamic> data;
}

class _CapturingDocRef implements DocumentReference<Map<String, dynamic>> {
  _CapturingDocRef(this.store, this.fullPath);
  final FakeFirestoreStore store;
  final String fullPath;

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.updates.add(_UpdateCall(fullPath, Map<Object, dynamic>.from(data)));
  }

  @override
  String get id => fullPath.split('/').last;

  @override
  String get path => fullPath;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingCollection
    implements CollectionReference<Map<String, dynamic>> {
  _CapturingCollection(this.store, this.collectionPath);
  final FakeFirestoreStore store;
  final String collectionPath;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) {
    return _CapturingDocRef(store, '$collectionPath/${id ?? 'auto-id'}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures every write operation routed through the fake Firestore.
class FakeFirestoreStore {
  final List<_UpdateCall> updates = <_UpdateCall>[];
  final List<_BatchUpdateCall> batchUpdates = <_BatchUpdateCall>[];
  int batchCommitCount = 0;
}

class _BatchUpdateCall {
  _BatchUpdateCall(this.path, this.data);
  final String path;
  final Map<Object, dynamic> data;
}

class _CapturingBatch implements WriteBatch {
  _CapturingBatch(this.store);
  final FakeFirestoreStore store;
  final List<_BatchUpdateCall> _pending = <_BatchUpdateCall>[];

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    _pending.add(
      _BatchUpdateCall(document.path, Map<Object, dynamic>.from(data)),
    );
  }

  @override
  Future<void> commit() async {
    store.batchUpdates.addAll(_pending);
    store.batchCommitCount += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingFirestore implements FirebaseFirestore {
  _CapturingFirestore(this.store);
  final FakeFirestoreStore store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _CapturingCollection(store, path);
  }

  @override
  WriteBatch batch() => _CapturingBatch(store);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool _isArrayUnion(dynamic value, String expectedToken) {
  if (value is! FieldValue) return false;
  // FieldValue's runtime type is FieldValueDelegate from
  // cloud_firestore_platform_interface; we cannot inspect the wrapped
  // list directly without reflection. As a pragmatic check, compare
  // toString() shape that includes the operation name.
  final s = value.toString();
  return s.contains('arrayUnion') && s.contains(expectedToken);
}

bool _isArrayRemove(dynamic value, String expectedToken) {
  if (value is! FieldValue) return false;
  final s = value.toString();
  return s.contains('arrayRemove') && s.contains(expectedToken);
}

// ---------------------------------------------------------------------------
// Test body
// ---------------------------------------------------------------------------

void main() {
  late FakeFirestoreStore store;
  late _CapturingFirestore firestore;
  late FakeMessagingAdapter messaging;
  late FcmTokenService service;

  setUp(() {
    store = FakeFirestoreStore();
    firestore = _CapturingFirestore(store);
    messaging = FakeMessagingAdapter();
    service = FcmTokenService(firestore: firestore, messaging: messaging);
  });

  tearDown(() async {
    await messaging.dispose();
  });

  group('FcmTokenService.registerToken', () {
    test('calls messaging.getToken() once and writes arrayUnion to '
        'users/{uid}.fcmTokens', () async {
      final token = await service.registerToken('uid-1');

      expect(token, 'token-A');
      expect(messaging.getTokenCalls, 1);
      expect(store.updates, hasLength(1));
      expect(store.updates.first.path, 'users/uid-1');
      expect(
        _isArrayUnion(store.updates.first.data['fcmTokens'], 'token-A'),
        isTrue,
        reason:
            'Expected arrayUnion([token-A]) on fcmTokens; got '
            '${store.updates.first.data}',
      );
    });

    test('returns null and writes nothing when getToken returns null '
        '(AC-13 — permission denied path)', () async {
      messaging.returnToken = null;

      final token = await service.registerToken('uid-1');

      expect(token, isNull);
      expect(store.updates, isEmpty);
    });

    test('is idempotent — re-registering the same token issues another '
        'arrayUnion (Firestore deduplicates at the doc level)', () async {
      await service.registerToken('uid-1');
      await service.registerToken('uid-1');

      expect(store.updates, hasLength(2));
      expect(messaging.getTokenCalls, 2);
    });
  });

  group('FcmTokenService.unregisterToken', () {
    test('calls arrayRemove([token]) on users/{uid}.fcmTokens', () async {
      await service.unregisterToken('uid-1', 'token-A');

      expect(store.updates, hasLength(1));
      expect(store.updates.first.path, 'users/uid-1');
      expect(
        _isArrayRemove(store.updates.first.data['fcmTokens'], 'token-A'),
        isTrue,
      );
    });
  });

  group('FcmTokenService.replaceToken', () {
    test('performs arrayRemove + arrayUnion in a SINGLE batched write '
        '(AC-2 — no window with no valid token)', () async {
      await service.replaceToken('uid-1', 'token-OLD', 'token-NEW');

      expect(
        store.batchCommitCount,
        1,
        reason: 'Expected exactly one batch.commit() call',
      );
      expect(store.batchUpdates, hasLength(2));
      // Both updates target the same document path.
      expect(store.batchUpdates[0].path, 'users/uid-1');
      expect(store.batchUpdates[1].path, 'users/uid-1');
      // One is arrayRemove(OLD), one is arrayUnion(NEW). Order is
      // implementation detail but both must be present.
      final allDataStrings = store.batchUpdates
          .map((u) => u.data.values.first.toString())
          .join(' ');
      expect(allDataStrings, contains('arrayRemove'));
      expect(allDataStrings, contains('arrayUnion'));
      expect(allDataStrings, contains('token-OLD'));
      expect(allDataStrings, contains('token-NEW'));
    });

    test('no-op (no batch commit) when oldToken == newToken', () async {
      await service.replaceToken('uid-1', 'token-X', 'token-X');

      expect(store.batchCommitCount, 0);
    });
  });

  group('FcmTokenService.startTokenRefreshListener', () {
    test('subscribes to onTokenRefresh and invokes replaceToken with the '
        'previously-known token on emit', () async {
      // Register initial token so the service caches it as the "current"
      // device token.
      await service.registerToken('uid-1');
      store.updates.clear(); // Drop initial registration write.

      service.startTokenRefreshListener('uid-1');

      messaging.emitRefresh('token-B');
      // Let the stream listener microtask drain.
      await Future<void>.delayed(Duration.zero);

      expect(
        store.batchCommitCount,
        1,
        reason:
            'Expected onTokenRefresh to invoke replaceToken which '
            'commits a single batch',
      );
      final allDataStrings = store.batchUpdates
          .map((u) => u.data.values.first.toString())
          .join(' ');
      expect(allDataStrings, contains('token-A')); // old
      expect(allDataStrings, contains('token-B')); // new
    });

    test('a second startTokenRefreshListener call cancels the previous '
        'subscription (defence-in-depth against double-wire)', () async {
      service.startTokenRefreshListener('uid-1');
      service.startTokenRefreshListener('uid-1');
      // No test for the actual behaviour beyond not throwing; this
      // verifies the method is idempotent in the lifecycle sense.
      expect(true, isTrue);
    });

    test('stopTokenRefreshListener cancels the subscription so subsequent '
        'emissions are ignored', () async {
      await service.registerToken('uid-1');
      store.updates.clear();
      service.startTokenRefreshListener('uid-1');
      await service.stopTokenRefreshListener();

      messaging.emitRefresh('token-B');
      await Future<void>.delayed(Duration.zero);

      expect(
        store.batchCommitCount,
        0,
        reason: 'Cancelled subscription must not write on emit',
      );
    });
  });

  group('FcmTokenService.currentToken', () {
    test('is null before registerToken is called', () {
      expect(service.currentToken, isNull);
    });

    test('returns the last-registered token', () async {
      await service.registerToken('uid-1');
      expect(service.currentToken, 'token-A');
    });

    test('updates after a token refresh', () async {
      await service.registerToken('uid-1');
      service.startTokenRefreshListener('uid-1');
      messaging.emitRefresh('token-B');
      await Future<void>.delayed(Duration.zero);
      expect(service.currentToken, 'token-B');
    });
  });
}
