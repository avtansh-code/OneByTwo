// Friendship repository unit tests.
//
// Tests the FriendshipRepository which manages friendship documents
// in Firestore with deterministic document IDs.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

/// Fake Firestore abstraction that records document operations.
///
/// Used to verify the friendship repository writes the correct
/// document ID, shape, and fields without requiring Firebase
/// initialisation.
class FakeFriendshipStore implements FriendshipStore {
  /// All documents written, keyed by document path.
  final Map<String, Map<String, dynamic>> documents = {};

  /// Whether [set] should throw to simulate write failures.
  bool setThrows = false;

  /// The exception to throw when [setThrows] is true.
  Exception setException = Exception('Write failed');

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    if (setThrows) throw setException;
    documents[path] = data;
  }

  @override
  Future<bool> exists(String path) async {
    return documents.containsKey(path);
  }

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    return documents[path];
  }

  @override
  Stream<List<FriendshipDoc>> watchByMember(String userId) =>
      const Stream<List<FriendshipDoc>>.empty();

  @override
  Stream<FriendshipDoc?> watchById(String friendshipId) =>
      const Stream<FriendshipDoc?>.empty();
}

void main() {
  late FakeFriendshipStore fakeStore;
  late FriendshipRepository repository;

  setUp(() {
    fakeStore = FakeFriendshipStore();
    repository = FriendshipRepository(store: fakeStore);
  });

  group('FriendshipRepository.createFriendship', () {
    test('writes to deterministic document ID with sorted UIDs', () async {
      await repository.createFriendship('uid-bbb', 'uid-aaa');

      expect(fakeStore.documents.containsKey('uid-aaa_uid-bbb'), isTrue);
    });

    test('returns the deterministic friendship ID', () async {
      final id = await repository.createFriendship('uid-bbb', 'uid-aaa');

      expect(id, 'uid-aaa_uid-bbb');
    });

    test('document ID is the same regardless of argument order', () async {
      final id1 = await repository.createFriendship('uid-aaa', 'uid-bbb');

      fakeStore.documents.clear();
      final id2 = await repository.createFriendship('uid-bbb', 'uid-aaa');

      expect(id1, equals(id2));
      expect(id1, 'uid-aaa_uid-bbb');
    });

    test('document contains memberIds as sorted array', () async {
      await repository.createFriendship('uid-bbb', 'uid-aaa');

      final doc = fakeStore.documents['uid-aaa_uid-bbb']!;
      expect(doc['memberIds'], ['uid-aaa', 'uid-bbb']);
    });

    test('document contains createdBy set to currentUserId', () async {
      await repository.createFriendship('uid-bbb', 'uid-aaa');

      final doc = fakeStore.documents['uid-aaa_uid-bbb']!;
      expect(doc['createdBy'], 'uid-bbb');
    });

    test('document contains lastActivityAt field', () async {
      await repository.createFriendship('uid-bbb', 'uid-aaa');

      final doc = fakeStore.documents['uid-aaa_uid-bbb']!;
      expect(doc.containsKey('lastActivityAt'), isTrue);
    });

    test('document does NOT contain simplifiedBalances', () async {
      await repository.createFriendship('uid-bbb', 'uid-aaa');

      final doc = fakeStore.documents['uid-aaa_uid-bbb']!;
      expect(
        doc.containsKey('simplifiedBalances'),
        isFalse,
        reason:
            'simplifiedBalances is server-maintained and '
            'must never be written by client code (invariant 2)',
      );
    });

    test('document has exactly memberIds, createdBy, and '
        'lastActivityAt keys', () async {
      await repository.createFriendship('uid-aaa', 'uid-bbb');

      final doc = fakeStore.documents['uid-aaa_uid-bbb']!;
      expect(
        doc.keys.toSet(),
        containsAll(['memberIds', 'createdBy', 'lastActivityAt']),
      );
      // No extra fields beyond the schema.
      expect(doc.keys.length, 3);
    });
  });

  group('FriendshipRepository.friendshipExists', () {
    test('returns true when the deterministic document exists', () async {
      await repository.createFriendship('uid-aaa', 'uid-bbb');

      final exists = await repository.friendshipExists('uid-aaa', 'uid-bbb');

      expect(exists, isTrue);
    });

    test('returns true regardless of argument order', () async {
      await repository.createFriendship('uid-aaa', 'uid-bbb');

      final exists = await repository.friendshipExists('uid-bbb', 'uid-aaa');

      expect(exists, isTrue);
    });

    test('returns false when the document does not exist', () async {
      final exists = await repository.friendshipExists('uid-aaa', 'uid-bbb');

      expect(exists, isFalse);
    });
  });

  group('FriendshipRepository idempotency', () {
    test('creating the same friendship twice does not throw', () async {
      await repository.createFriendship('uid-aaa', 'uid-bbb');

      // Second call should either succeed silently (idempotent set) or
      // detect the existing document and return without error.
      await expectLater(
        repository.createFriendship('uid-aaa', 'uid-bbb'),
        completes,
      );
    });

    test('creating the same friendship twice returns the same ID', () async {
      final id1 = await repository.createFriendship('uid-aaa', 'uid-bbb');
      final id2 = await repository.createFriendship('uid-aaa', 'uid-bbb');

      expect(id1, equals(id2));
    });
  });
}
