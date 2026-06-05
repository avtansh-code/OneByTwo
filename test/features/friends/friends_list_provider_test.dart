// FriendsListProvider unit tests.
//
// Tests the Riverpod `StreamProvider<List<FriendListItem>>` that wraps the
// repository's `watchFriendships` stream and projects each `FriendshipDoc`
// into a `FriendListItem` carrying the integer paise net balance and the
// resolved display name + photo URL from the per-uid user-profile family.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

/// Fake repository whose `watchFriendships` returns a controllable stream.
class FakeRepository implements FriendshipRepository {
  final StreamController<List<FriendshipDoc>> controller =
      StreamController<List<FriendshipDoc>>.broadcast();
  String? lastWatchedUid;

  @override
  Stream<List<FriendshipDoc>> watchFriendships(String currentUserId) {
    lastWatchedUid = currentUserId;
    return controller.stream;
  }

  @override
  Future<String> createFriendship(String currentUserId, String otherUserId) {
    throw UnimplementedError('write path not exercised in this test');
  }

  @override
  Future<bool> friendshipExists(String userId1, String userId2) {
    throw UnimplementedError('write path not exercised in this test');
  }
}

UserModel _user({required String displayName, String? photoUrl}) {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: displayName,
    photoUrl: photoUrl,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
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
  late FakeRepository repository;
  late ProviderContainer container;

  /// Map of uid → behaviour when the user profile is fetched.
  final profileBehaviour = <String, Future<UserModel?> Function()>{};

  setUp(() {
    repository = FakeRepository();
    profileBehaviour.clear();
    container = ProviderContainer(
      overrides: [
        friendshipRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue('uid-me'),
        userProfileProvider.overrideWith(
          (ref, uid) => (profileBehaviour[uid] ?? () async => null).call(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repository.controller.close();
  });

  group('friendsListProvider', () {
    test('emits an empty list when the repo emits []', () async {
      final sub = container.listen(
        friendsListProvider,
        (_, __) {},
        fireImmediately: true,
      );

      repository.controller.add(const []);
      await Future<void>.delayed(Duration.zero);

      final value = sub.read();
      expect(value, isA<AsyncData<List<FriendListItem>>>());
      expect(value.value, isEmpty);
    });

    test(
      'projects N docs into N FriendListItems with integer paise balances',
      () async {
        profileBehaviour['uid-aaa'] = () async =>
            _user(displayName: 'Aarav', photoUrl: 'https://x/a.png');
        profileBehaviour['uid-bbb'] = () async => _user(displayName: 'Bina');

        final sub = container.listen(
          friendsListProvider,
          (_, __) {},
          fireImmediately: true,
        );

        repository.controller.add([
          _doc(
            id: 'uid-aaa_uid-me',
            memberIds: ['uid-aaa', 'uid-me'],
            lastActivityAt: DateTime(2026, 1, 2),
            simplifiedBalances: const {
              'uid-aaa': {'uid-me': 1500},
            },
          ),
          _doc(
            id: 'uid-bbb_uid-me',
            memberIds: ['uid-bbb', 'uid-me'],
            lastActivityAt: DateTime(2026),
            simplifiedBalances: const {
              'uid-me': {'uid-bbb': 200},
            },
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final value = sub.read();
        expect(value, isA<AsyncData<List<FriendListItem>>>());
        final items = value.value!;
        expect(items, hasLength(2));

        final aarav = items[0];
        expect(aarav.friendshipId, 'uid-aaa_uid-me');
        expect(aarav.otherUserId, 'uid-aaa');
        expect(aarav.displayName, 'Aarav');
        expect(aarav.photoUrl, 'https://x/a.png');
        expect(aarav.netBalancePaise, 1500);
        expect(
          aarav.netBalancePaise,
          isA<int>(),
          reason: 'invariant 1: netBalancePaise must be int',
        );

        final bina = items[1];
        expect(bina.friendshipId, 'uid-bbb_uid-me');
        expect(bina.otherUserId, 'uid-bbb');
        expect(bina.displayName, 'Bina');
        expect(bina.photoUrl, isNull);
        expect(bina.netBalancePaise, -200);
      },
    );

    test(
      'falls back to "Unknown" when the user profile lookup returns null',
      () async {
        profileBehaviour['uid-aaa'] = () async => null;

        final sub = container.listen(
          friendsListProvider,
          (_, __) {},
          fireImmediately: true,
        );

        repository.controller.add([
          _doc(
            id: 'uid-aaa_uid-me',
            memberIds: ['uid-aaa', 'uid-me'],
            lastActivityAt: DateTime(2026),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final items = sub.read().value!;
        expect(items, hasLength(1));
        expect(items.first.displayName, 'Unknown');
        expect(items.first.photoUrl, isNull);
      },
    );

    test(
      'falls back to "Unknown" when the user profile lookup throws',
      () async {
        profileBehaviour['uid-aaa'] = () async => throw StateError('boom');

        final sub = container.listen(
          friendsListProvider,
          (_, __) {},
          fireImmediately: true,
        );

        repository.controller.add([
          _doc(
            id: 'uid-aaa_uid-me',
            memberIds: ['uid-aaa', 'uid-me'],
            lastActivityAt: DateTime(2026),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final value = sub.read();
        expect(
          value,
          isA<AsyncData<List<FriendListItem>>>(),
          reason: 'profile-lookup error should NOT fail the whole list',
        );
        final items = value.value!;
        expect(items, hasLength(1));
        expect(items.first.displayName, 'Unknown');
      },
    );

    test(
      'propagates a repository stream error as AsyncError on the provider',
      () async {
        final sub = container.listen(
          friendsListProvider,
          (_, __) {},
          fireImmediately: true,
        );

        repository.controller.addError(Exception('Firestore down'));
        await Future<void>.delayed(Duration.zero);

        expect(sub.read(), isA<AsyncError<List<FriendListItem>>>());
      },
    );

    test(
      'asks the repository to watch with the configured currentUserId',
      () async {
        container.listen(friendsListProvider, (_, __) {});
        await Future<void>.delayed(Duration.zero);
        expect(repository.lastWatchedUid, 'uid-me');
      },
    );

    test('drops a friendship doc whose memberIds contains no distinct other '
        'user (defensive: corrupt or self-only doc)', () async {
      profileBehaviour['uid-aaa'] = () async => _user(displayName: 'Aarav');

      final sub = container.listen(
        friendsListProvider,
        (_, __) {},
        fireImmediately: true,
      );

      repository.controller.add([
        // Corrupt doc: single-member list containing only the current user.
        _doc(
          id: 'corrupt-self-only',
          memberIds: const ['uid-me'],
          lastActivityAt: DateTime(2026, 1, 3),
        ),
        // Healthy doc.
        _doc(
          id: 'uid-aaa_uid-me',
          memberIds: const ['uid-aaa', 'uid-me'],
          lastActivityAt: DateTime(2026, 1, 2),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final items = sub.read().value!;
      expect(
        items,
        hasLength(1),
        reason: 'corrupt doc should be dropped, healthy doc kept',
      );
      expect(items.first.friendshipId, 'uid-aaa_uid-me');
      expect(
        items.first.displayName,
        isNot(equals('Unknown')),
        reason: 'the kept row resolves the friend profile, not the dropped one',
      );
      // The dropped row must NEVER appear as a self-row (which would
      // surface the current user's own profile).
      expect(
        items.any((i) => i.otherUserId == 'uid-me'),
        isFalse,
        reason: 'no self row should ever be projected',
      );
    });

    test('drops a friendship doc with empty memberIds', () async {
      final sub = container.listen(
        friendsListProvider,
        (_, __) {},
        fireImmediately: true,
      );

      repository.controller.add([
        _doc(
          id: 'empty-doc',
          memberIds: const [],
          lastActivityAt: DateTime(2026),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final items = sub.read().value!;
      expect(items, isEmpty);
    });
  });
}
