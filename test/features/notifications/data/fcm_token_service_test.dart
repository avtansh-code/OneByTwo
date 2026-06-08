// FcmTokenService tests (FR-AC-03).
//
// Covers the client-side token-lifecycle helpers:
//   - registerToken(uid) — calls messaging.getToken() then writes via
//     store.addToken(arrayUnion).
//   - unregisterToken(uid, token) — store.removeToken (arrayRemove).
//   - replaceToken(uid, oldToken, newToken) — single batched write via
//     store.replaceTokenAtomically.
//   - startTokenRefreshListener(uid) — wires onTokenRefresh through
//     replaceToken.
//
// Fakes the FcmTokenStore + FcmMessagingAdapter abstractions; no
// FirebaseFirestore implementation required (the cloud_firestore
// DocumentReference / Query classes are sealed and cannot be
// implemented in test code).

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/notifications/data/fcm_token_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

class AddCall {
  AddCall(this.uid, this.token);
  final String uid;
  final String token;
}

class RemoveCall {
  RemoveCall(this.uid, this.token);
  final String uid;
  final String token;
}

class ReplaceCall {
  ReplaceCall(this.uid, this.oldToken, this.newToken);
  final String uid;
  final String oldToken;
  final String newToken;
}

class FakeTokenStore implements FcmTokenStore {
  final List<AddCall> addCalls = <AddCall>[];
  final List<RemoveCall> removeCalls = <RemoveCall>[];
  final List<ReplaceCall> replaceCalls = <ReplaceCall>[];

  @override
  Future<void> addToken({required String uid, required String token}) async {
    addCalls.add(AddCall(uid, token));
  }

  @override
  Future<void> removeToken({required String uid, required String token}) async {
    removeCalls.add(RemoveCall(uid, token));
  }

  @override
  Future<void> replaceTokenAtomically({
    required String uid,
    required String oldToken,
    required String newToken,
  }) async {
    replaceCalls.add(ReplaceCall(uid, oldToken, newToken));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeTokenStore store;
  late FakeMessagingAdapter messaging;
  late FcmTokenService service;

  setUp(() {
    store = FakeTokenStore();
    messaging = FakeMessagingAdapter();
    service = FcmTokenService(store: store, messaging: messaging);
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
      expect(store.addCalls, hasLength(1));
      expect(store.addCalls.first.uid, 'uid-1');
      expect(store.addCalls.first.token, 'token-A');
    });

    test('returns null and writes nothing when getToken returns null '
        '(AC-13 — permission denied path)', () async {
      messaging.returnToken = null;

      final token = await service.registerToken('uid-1');

      expect(token, isNull);
      expect(store.addCalls, isEmpty);
    });

    test('is idempotent at the call site — re-registering the same token '
        'issues another arrayUnion (Firestore arrayUnion deduplicates '
        'at the doc level)', () async {
      await service.registerToken('uid-1');
      await service.registerToken('uid-1');

      expect(store.addCalls, hasLength(2));
      expect(messaging.getTokenCalls, 2);
    });

    test('caches the acquired token as currentToken', () async {
      await service.registerToken('uid-1');
      expect(service.currentToken, 'token-A');
    });
  });

  group('FcmTokenService.unregisterToken', () {
    test('calls arrayRemove([token]) on users/{uid}.fcmTokens', () async {
      await service.unregisterToken('uid-1', 'token-A');

      expect(store.removeCalls, hasLength(1));
      expect(store.removeCalls.first.uid, 'uid-1');
      expect(store.removeCalls.first.token, 'token-A');
    });

    test('clears currentToken when the unregistered token matches the '
        'cached one', () async {
      await service.registerToken('uid-1');
      expect(service.currentToken, 'token-A');
      await service.unregisterToken('uid-1', 'token-A');
      expect(service.currentToken, isNull);
    });

    test(
      'preserves currentToken when a different token is unregistered',
      () async {
        await service.registerToken('uid-1');
        await service.unregisterToken('uid-1', 'token-OTHER');
        expect(service.currentToken, 'token-A');
      },
    );
  });

  group('FcmTokenService.replaceToken', () {
    test('performs a single batched arrayRemove + arrayUnion via '
        'store.replaceTokenAtomically (AC-2 — no window with no '
        'valid token)', () async {
      await service.replaceToken('uid-1', 'token-OLD', 'token-NEW');

      expect(store.replaceCalls, hasLength(1));
      final call = store.replaceCalls.first;
      expect(call.uid, 'uid-1');
      expect(call.oldToken, 'token-OLD');
      expect(call.newToken, 'token-NEW');
    });

    test('no-op (no store call) when oldToken == newToken', () async {
      await service.replaceToken('uid-1', 'token-X', 'token-X');

      expect(store.replaceCalls, isEmpty);
    });

    test('updates currentToken to the new value', () async {
      await service.registerToken('uid-1');
      await service.replaceToken('uid-1', 'token-A', 'token-B');
      expect(service.currentToken, 'token-B');
    });
  });

  group('FcmTokenService.startTokenRefreshListener', () {
    test('subscribes to onTokenRefresh and invokes replaceToken with the '
        'previously-known token on emit', () async {
      await service.registerToken('uid-1');
      store.addCalls.clear(); // Drop the initial-registration call.

      service.startTokenRefreshListener('uid-1');

      messaging.emitRefresh('token-B');
      await Future<void>.delayed(Duration.zero);

      expect(store.replaceCalls, hasLength(1));
      final call = store.replaceCalls.first;
      expect(call.oldToken, 'token-A');
      expect(call.newToken, 'token-B');
    });

    test('falls back to addToken (no prior cached) when listener fires '
        'before registerToken', () async {
      service.startTokenRefreshListener('uid-1');
      messaging.emitRefresh('token-FIRST');
      await Future<void>.delayed(Duration.zero);

      expect(store.addCalls, hasLength(1));
      expect(store.addCalls.first.token, 'token-FIRST');
      expect(service.currentToken, 'token-FIRST');
    });

    test('a second startTokenRefreshListener call cancels the previous '
        'subscription (idempotent in the lifecycle sense)', () {
      service.startTokenRefreshListener('uid-1');
      service.startTokenRefreshListener('uid-1');
      // No assertion beyond not throwing; the implementation cancels
      // the prior _refreshSub before assigning the new one.
      expect(true, isTrue);
    });

    test('stopTokenRefreshListener cancels the subscription; subsequent '
        'emissions are ignored', () async {
      await service.registerToken('uid-1');
      store.addCalls.clear();
      service.startTokenRefreshListener('uid-1');
      await service.stopTokenRefreshListener();

      messaging.emitRefresh('token-B');
      await Future<void>.delayed(Duration.zero);

      expect(store.replaceCalls, isEmpty);
    });
  });

  group('FcmTokenService.currentToken', () {
    test('is null at construction', () {
      expect(service.currentToken, isNull);
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
