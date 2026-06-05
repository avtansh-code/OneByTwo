// Match-and-invite boundary contract tests.
//
// Asserts the exact format and shape of data crossing architectural
// boundaries, per the pattern established in
// contact_picker_boundary_contract_test.dart.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

/// Fake callable that captures the data passed to the Cloud Function.
class BoundaryCapturingCallable {
  /// Captured call data.
  Map<String, dynamic>? capturedData;

  /// The callable function.
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) async {
    capturedData = data;
    return {'matched': false};
  }
}

/// Fake store that captures the document data written.
class BoundaryCapturingStore implements FriendshipStore {
  /// Captured document path.
  String? capturedPath;

  /// Captured document data.
  Map<String, dynamic>? capturedData;

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    capturedPath = path;
    capturedData = data;
  }

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Map<String, dynamic>?> get(String path) async => null;

  @override
  Stream<List<FriendshipDoc>> watchByMember(String userId) =>
      const Stream<List<FriendshipDoc>>.empty();
}

void main() {
  group('Matching repository boundary contract', () {
    test('lookup call data contains exactly one key: phoneNumber', () async {
      final callable = BoundaryCapturingCallable();
      final repo = MatchingRepository(lookupCallable: callable.call);

      await repo.lookupUser('+919876543210');

      expect(callable.capturedData, isNotNull);
      expect(callable.capturedData!.keys, equals(['phoneNumber']));
    });

    test(
      'phoneNumber value is E.164 format (+91 followed by 10 digits)',
      () async {
        final callable = BoundaryCapturingCallable();
        final repo = MatchingRepository(lookupCallable: callable.call);

        await repo.lookupUser('+919876543210');

        final phone = callable.capturedData!['phoneNumber'] as String;
        expect(phone, startsWith('+91'));
        expect(phone.length, 13); // +91 + 10 digits
        expect(
          RegExp(r'^\+91[6-9]\d{9}$').hasMatch(phone),
          isTrue,
          reason: 'Phone must be E.164 Indian mobile: $phone',
        );
      },
    );

    test('phoneNumber value is a String, not a num or other type', () async {
      final callable = BoundaryCapturingCallable();
      final repo = MatchingRepository(lookupCallable: callable.call);

      await repo.lookupUser('+919876543210');

      expect(callable.capturedData!['phoneNumber'], isA<String>());
    });
  });

  group('Friendship creation boundary contract', () {
    test('document path is deterministic sorted UIDs joined with '
        'underscore', () async {
      final store = BoundaryCapturingStore();
      final repo = FriendshipRepository(store: store);

      await repo.createFriendship('uid-bbb', 'uid-aaa');

      expect(store.capturedPath, 'uid-aaa_uid-bbb');
    });

    test('document has exactly memberIds, createdBy, and '
        'lastActivityAt', () async {
      final store = BoundaryCapturingStore();
      final repo = FriendshipRepository(store: store);

      await repo.createFriendship('uid-bbb', 'uid-aaa');

      expect(store.capturedData, isNotNull);
      expect(
        store.capturedData!.keys.toSet(),
        equals({'memberIds', 'createdBy', 'lastActivityAt'}),
      );
    });

    test('memberIds is a List of exactly two sorted strings', () async {
      final store = BoundaryCapturingStore();
      final repo = FriendshipRepository(store: store);

      await repo.createFriendship('uid-bbb', 'uid-aaa');

      final memberIds = store.capturedData!['memberIds'];
      expect(memberIds, isA<List<String>>());
      expect(memberIds, hasLength(2));
      expect(memberIds, ['uid-aaa', 'uid-bbb']);
    });

    test('createdBy is the currentUserId (first argument)', () async {
      final store = BoundaryCapturingStore();
      final repo = FriendshipRepository(store: store);

      await repo.createFriendship('uid-bbb', 'uid-aaa');

      expect(store.capturedData!['createdBy'], 'uid-bbb');
    });

    test('document does NOT contain simplifiedBalances', () async {
      final store = BoundaryCapturingStore();
      final repo = FriendshipRepository(store: store);

      await repo.createFriendship('uid-aaa', 'uid-bbb');

      expect(
        store.capturedData!.containsKey('simplifiedBalances'),
        isFalse,
        reason:
            'simplifiedBalances is server-maintained and must '
            'never be written by client code (invariant 2)',
      );
    });

    test('document does NOT contain any extra fields', () async {
      final store = BoundaryCapturingStore();
      final repo = FriendshipRepository(store: store);

      await repo.createFriendship('uid-aaa', 'uid-bbb');

      // Exhaustive check: only the three expected keys.
      expect(store.capturedData!.keys.length, 3);
      for (final key in store.capturedData!.keys) {
        expect(
          ['memberIds', 'createdBy', 'lastActivityAt'].contains(key),
          isTrue,
          reason: 'Unexpected field in friendship document: $key',
        );
      }
    });
  });
}
