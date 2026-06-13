// FR-PR-04 friend-count derived-provider unit tests.
//
// `friendCountProvider` is the pure read-side projection of
// `friendsListProvider` into its cardinality (`items.length`) for the
// Profile Stats "My Friends" row. It mirrors the upstream async
// lifecycle: AsyncLoading -> AsyncData<int> / AsyncError.
//
// The friends list stream is faked through the repository so these
// tests exercise the real projection pipeline (FriendshipDoc ->
// FriendListItem -> length), mirroring
// `test/features/home/home_balances_providers_test.dart`.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';
import 'package:onebytwo/features/profile/application/friend_count_provider.dart';

class FakeRepository implements FriendshipRepository {
  final StreamController<List<FriendshipDoc>> controller =
      StreamController<List<FriendshipDoc>>.broadcast();

  @override
  Stream<List<FriendshipDoc>> watchFriendships(String currentUserId) {
    return controller.stream;
  }

  @override
  Future<String> createFriendship(String currentUserId, String otherUserId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> friendshipExists(String userId1, String userId2) {
    throw UnimplementedError();
  }

  @override
  Stream<FriendshipDoc?> watchFriendship(String friendshipId) {
    throw UnimplementedError();
  }
}

UserModel _user(String displayName) => UserModel(
  phoneNumber: '+919876543210',
  displayName: displayName,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// A friendship doc where `other` owes `me` [paise] (positive net for
/// the current user) when [paise] > 0, or `me` owes `other` when < 0,
/// or settled up when 0.
FriendshipDoc _doc({
  required String otherUid,
  required int paise,
  DateTime? lastActivityAt,
}) {
  final Map<String, Map<String, int>> balances;
  if (paise > 0) {
    balances = {
      otherUid: {'uid-me': paise},
    };
  } else if (paise < 0) {
    balances = {
      'uid-me': {otherUid: -paise},
    };
  } else {
    balances = const {};
  }
  return FriendshipDoc(
    friendshipId: '${otherUid}_uid-me',
    memberIds: [otherUid, 'uid-me'],
    simplifiedBalances: balances,
    lastActivityAt: lastActivityAt ?? DateTime(2026),
  );
}

void main() {
  late FakeRepository repository;
  late ProviderContainer container;
  final profiles = <String, UserModel?>{};

  setUp(() {
    repository = FakeRepository();
    profiles.clear();
    container = ProviderContainer(
      overrides: [
        friendshipRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue('uid-me'),
        userProfileProvider.overrideWith(
          (ref, uid) async => profiles[uid] ?? _user('Friend $uid'),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repository.controller.close();
  });

  Future<void> emit(List<FriendshipDoc> docs) async {
    repository.controller.add(docs);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('friendCountProvider (FR-PR-04)', () {
    test('is AsyncLoading before the first emission', () {
      container.listen(friendCountProvider, (_, __) {});
      expect(container.read(friendCountProvider), isA<AsyncLoading<int>>());
    });

    test('counts friendships as cardinality, not a balance fold', () async {
      container.listen(friendCountProvider, (_, __) {});
      await emit([
        _doc(otherUid: 'uid-a', paise: 1500),
        // A settled-up (zero-balance) friend still counts — the count
        // is cardinality, not the net-balance fold.
        _doc(otherUid: 'uid-zero', paise: 0),
        _doc(otherUid: 'uid-c', paise: -5000),
      ]);

      final value = container.read(friendCountProvider);
      expect(value, isA<AsyncData<int>>());
      expect(value.value, 3);
      expect(value.value, isA<int>());
    });

    test('is 0 for an empty friends list', () async {
      container.listen(friendCountProvider, (_, __) {});
      await emit(const []);
      expect(container.read(friendCountProvider).value, 0);
    });

    test('propagates a stream error as AsyncError', () async {
      container.listen(friendCountProvider, (_, __) {});
      repository.controller.addError(Exception('Firestore down'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(friendCountProvider), isA<AsyncError<int>>());
    });
  });
}
