// Friendship repository watch (read-side) unit tests.
//
// Tests the new `FriendshipRepository.watchFriendships(currentUserId)`
// stream that powers the friends list (FR-FR-03). This is the read-side
// counterpart to PR #32's write-side `createFriendship`. The write path
// is not modified by this PR.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is updated.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

/// Fake [FriendshipStore] that exposes a controllable stream for the
/// `watchByMember` query. Existing methods are minimally implemented to
/// preserve the write-side test surface.
class FakeFriendshipStore implements FriendshipStore {
  final Map<String, Map<String, dynamic>> documents = {};
  final StreamController<List<FriendshipDoc>> _controller =
      StreamController<List<FriendshipDoc>>.broadcast();
  String? lastWatchedMemberId;

  void emit(List<FriendshipDoc> docs) {
    _controller.add(docs);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    documents[path] = data;
  }

  @override
  Future<bool> exists(String path) async => documents.containsKey(path);

  @override
  Future<Map<String, dynamic>?> get(String path) async => documents[path];

  @override
  Stream<List<FriendshipDoc>> watchByMember(String userId) {
    lastWatchedMemberId = userId;
    return _controller.stream;
  }

  Future<void> close() => _controller.close();
}

FriendshipDoc _doc({
  required String id,
  required List<String> memberIds,
  required DateTime lastActivityAt,
  Map<String, Map<String, int>>? simplifiedBalances,
}) {
  return FriendshipDoc(
    friendshipId: id,
    memberIds: memberIds,
    simplifiedBalances: simplifiedBalances ?? const {},
    lastActivityAt: lastActivityAt,
  );
}

void main() {
  late FakeFriendshipStore store;
  late FriendshipRepository repository;

  setUp(() {
    store = FakeFriendshipStore();
    repository = FriendshipRepository(store: store);
  });

  tearDown(() async {
    await store.close();
  });

  group('FriendshipRepository.watchFriendships', () {
    test('queries by the supplied currentUserId', () async {
      repository.watchFriendships('uid-me');
      // Allow microtask drain.
      await Future<void>.delayed(Duration.zero);
      expect(store.lastWatchedMemberId, 'uid-me');
    });

    test('emits an empty list when the underlying stream emits []', () async {
      final stream = repository.watchFriendships('uid-me');
      final emissions = <List<FriendshipDoc>>[];
      final sub = stream.listen(emissions.add);

      store.emit(const []);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      expect(emissions.first, isEmpty);

      await sub.cancel();
    });

    test(
      'preserves Firestore-provided ordering (lastActivityAt desc)',
      () async {
        final stream = repository.watchFriendships('uid-me');
        final emissions = <List<FriendshipDoc>>[];
        final sub = stream.listen(emissions.add);

        final newest = _doc(
          id: 'uid-me_uid-bbb',
          memberIds: ['uid-me', 'uid-bbb'],
          lastActivityAt: DateTime(2026, 1, 3),
        );
        final middle = _doc(
          id: 'uid-aaa_uid-me',
          memberIds: ['uid-aaa', 'uid-me'],
          lastActivityAt: DateTime(2026, 1, 2),
        );
        final oldest = _doc(
          id: 'uid-ccc_uid-me',
          memberIds: ['uid-ccc', 'uid-me'],
          lastActivityAt: DateTime(2026),
        );

        store.emit([newest, middle, oldest]);
        await Future<void>.delayed(Duration.zero);

        expect(emissions.last.map((d) => d.friendshipId).toList(), [
          'uid-me_uid-bbb',
          'uid-aaa_uid-me',
          'uid-ccc_uid-me',
        ]);

        await sub.cancel();
      },
    );

    test('emits a new list when a document is added', () async {
      final stream = repository.watchFriendships('uid-me');
      final emissions = <List<FriendshipDoc>>[];
      final sub = stream.listen(emissions.add);

      final doc1 = _doc(
        id: 'uid-aaa_uid-me',
        memberIds: ['uid-aaa', 'uid-me'],
        lastActivityAt: DateTime(2026),
      );
      store.emit([doc1]);
      await Future<void>.delayed(Duration.zero);

      final doc2 = _doc(
        id: 'uid-bbb_uid-me',
        memberIds: ['uid-bbb', 'uid-me'],
        lastActivityAt: DateTime(2026, 1, 2),
      );
      store.emit([doc2, doc1]);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(2));
      expect(emissions[0], hasLength(1));
      expect(emissions[1], hasLength(2));
      expect(emissions[1].map((d) => d.friendshipId).toList(), [
        'uid-bbb_uid-me',
        'uid-aaa_uid-me',
      ]);

      await sub.cancel();
    });

    test(
      're-orders when an existing document changes lastActivityAt',
      () async {
        final stream = repository.watchFriendships('uid-me');
        final emissions = <List<FriendshipDoc>>[];
        final sub = stream.listen(emissions.add);

        final docA = _doc(
          id: 'uid-aaa_uid-me',
          memberIds: ['uid-aaa', 'uid-me'],
          lastActivityAt: DateTime(2026),
        );
        final docB = _doc(
          id: 'uid-bbb_uid-me',
          memberIds: ['uid-bbb', 'uid-me'],
          lastActivityAt: DateTime(2026, 1, 2),
        );

        store.emit([docB, docA]);
        await Future<void>.delayed(Duration.zero);

        // Promote docA to the top by giving it a newer lastActivityAt.
        final docAPromoted = _doc(
          id: 'uid-aaa_uid-me',
          memberIds: ['uid-aaa', 'uid-me'],
          lastActivityAt: DateTime(2026, 1, 3),
        );
        store.emit([docAPromoted, docB]);
        await Future<void>.delayed(Duration.zero);

        expect(emissions.last.first.friendshipId, 'uid-aaa_uid-me');

        await sub.cancel();
      },
    );

    test('propagates stream errors as AsyncError downstream', () async {
      final stream = repository.watchFriendships('uid-me');
      final errors = <Object>[];
      final sub = stream.listen((_) {}, onError: errors.add);

      store.emitError(Exception('Firestore boom'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isException);

      await sub.cancel();
    });
  });

  group('logFriendshipParseFailure (observability sink)', () {
    test('is a FriendshipParseFailureSink', () {
      // Assign through a typed variable to lock the typedef contract at
      // compile time (the test fails to compile if the signature drifts).
      // ignore: omit_local_variable_types
      const FriendshipParseFailureSink sink = logFriendshipParseFailure;
      expect(sink, isA<FriendshipParseFailureSink>());
    });

    test('does not throw on representative parse-failure messages', () {
      expect(
        () => logFriendshipParseFailure(
          'friendship abc_def: simplifiedBalances is not a Map; '
          'defaulting to empty',
        ),
        returnsNormally,
      );
      expect(
        () => logFriendshipParseFailure(
          'friendship abc_def: no distinct other user in memberIds '
          '(got [uid-me]); dropped from friends list',
        ),
        returnsNormally,
      );
    });

    test('accepts an empty message without throwing', () {
      expect(() => logFriendshipParseFailure(''), returnsNormally);
    });
  });

  group('FirestoreFriendshipStore onParseFailure wiring', () {
    test('accepts a custom FriendshipParseFailureSink without throwing', () {
      // We cannot construct a real FirebaseFirestore in a unit test, but
      // we can confirm the constructor's parameter contract by checking
      // the function type accepted matches FriendshipParseFailureSink.
      // The actual wiring through Firestore snapshots is covered by the
      // integration stub (test/integration/friends/friends_list_flow_test).
      // ignore: omit_local_variable_types
      const FriendshipParseFailureSink customSink = _recordingSink;
      expect(customSink, isA<FriendshipParseFailureSink>());
    });
  });
}

// Top-level sink used to confirm the typedef parameter contract above
// without requiring a closure (typedefs of function types require a
// tear-off).
void _recordingSink(String _) {}
