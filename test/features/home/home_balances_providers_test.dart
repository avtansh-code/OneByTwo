// Home dashboard derived-provider unit tests (FR-HD-01 / FR-HD-02).
//
// Verifies the two pure read-side reducers composed over
// `friendsListProvider`:
//
// - `overallNetBalanceProvider` — the signed sum of every friendship's
//   net balance (FR-HD-01). Integer paise throughout (invariant 1).
// - `topBalancesProvider` — friendships sorted by descending absolute
//   balance, zero balances excluded, capped at 5, stable tie-break on
//   the upstream order (FR-HD-02).
//
// Both providers mirror the upstream async lifecycle: AsyncLoading →
// AsyncData / AsyncError. The friends list stream is faked through the
// repository so these tests exercise the real projection pipeline.

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
import 'package:onebytwo/features/home/application/home_balances_providers.dart';

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
/// the current user) when [paise] > 0, or `me` owes `other` when < 0.
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

  group('overallNetBalanceProvider (FR-HD-01)', () {
    test('is AsyncLoading before the first emission', () {
      container.listen(overallNetBalanceProvider, (_, __) {});
      final value = container.read(overallNetBalanceProvider);
      expect(value, isA<AsyncLoading<int>>());
    });

    test('sums signed net balances across friendships', () async {
      container.listen(overallNetBalanceProvider, (_, __) {});
      await emit([
        _doc(otherUid: 'uid-a', paise: 1500),
        _doc(otherUid: 'uid-b', paise: -200),
        _doc(otherUid: 'uid-c', paise: 5000),
      ]);

      final value = container.read(overallNetBalanceProvider);
      expect(value, isA<AsyncData<int>>());
      expect(value.value, 1500 - 200 + 5000);
      expect(value.value, isA<int>());
    });

    test('is zero when all balances cancel out', () async {
      container.listen(overallNetBalanceProvider, (_, __) {});
      await emit([
        _doc(otherUid: 'uid-a', paise: 1000),
        _doc(otherUid: 'uid-b', paise: -1000),
      ]);

      expect(container.read(overallNetBalanceProvider).value, 0);
    });

    test('is zero for an empty friends list', () async {
      container.listen(overallNetBalanceProvider, (_, __) {});
      await emit(const []);
      expect(container.read(overallNetBalanceProvider).value, 0);
    });

    test('propagates a stream error as AsyncError', () async {
      container.listen(overallNetBalanceProvider, (_, __) {});
      repository.controller.addError(Exception('Firestore down'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(overallNetBalanceProvider), isA<AsyncError<int>>());
    });
  });

  group('topBalancesProvider (FR-HD-02)', () {
    test('sorts by descending absolute balance', () async {
      container.listen(topBalancesProvider, (_, __) {});
      await emit([
        _doc(otherUid: 'uid-small', paise: 100),
        _doc(otherUid: 'uid-big', paise: -9000),
        _doc(otherUid: 'uid-mid', paise: 3000),
      ]);

      final items = container.read(topBalancesProvider).value!;
      expect(items.map((i) => i.otherUserId).toList(), [
        'uid-big',
        'uid-mid',
        'uid-small',
      ]);
    });

    test('excludes settled-up (zero-balance) friendships', () async {
      container.listen(topBalancesProvider, (_, __) {});
      await emit([
        _doc(otherUid: 'uid-a', paise: 1000),
        _doc(otherUid: 'uid-zero', paise: 0),
        _doc(otherUid: 'uid-b', paise: -500),
      ]);

      final items = container.read(topBalancesProvider).value!;
      expect(items, hasLength(2));
      expect(items.any((i) => i.otherUserId == 'uid-zero'), isFalse);
    });

    test('caps the list at 5 rows', () async {
      container.listen(topBalancesProvider, (_, __) {});
      await emit([
        for (var i = 0; i < 8; i++)
          _doc(otherUid: 'uid-$i', paise: (i + 1) * 100),
      ]);

      final items = container.read(topBalancesProvider).value!;
      expect(items, hasLength(topBalancesCap));
      // The five largest are uid-7..uid-3 (800..400 paise).
      expect(items.first.otherUserId, 'uid-7');
      expect(items.last.otherUserId, 'uid-3');
    });

    test('breaks ties stably on the upstream order '
        '(lastActivityAt desc)', () async {
      // Upstream order is whatever the repository emits; the friends
      // provider preserves it. Two equal-magnitude balances must retain
      // that order.
      container.listen(topBalancesProvider, (_, __) {});
      await emit([
        _doc(
          otherUid: 'uid-recent',
          paise: 2000,
          lastActivityAt: DateTime(2026, 2),
        ),
        _doc(
          otherUid: 'uid-older',
          paise: -2000,
          lastActivityAt: DateTime(2026),
        ),
      ]);

      final items = container.read(topBalancesProvider).value!;
      expect(
        items.map((i) => i.otherUserId).toList(),
        ['uid-recent', 'uid-older'],
        reason: 'equal |balance| keeps the upstream (first-emitted) order',
      );
    });

    test('returns an empty list when every friendship is settled', () async {
      container.listen(topBalancesProvider, (_, __) {});
      await emit([
        _doc(otherUid: 'uid-a', paise: 0),
        _doc(otherUid: 'uid-b', paise: 0),
      ]);

      expect(container.read(topBalancesProvider).value, isEmpty);
    });

    test('is AsyncLoading before the first emission', () {
      container.listen(topBalancesProvider, (_, __) {});
      expect(
        container.read(topBalancesProvider),
        isA<AsyncLoading<List<FriendListItem>>>(),
      );
    });

    test('propagates a stream error as AsyncError', () async {
      container.listen(topBalancesProvider, (_, __) {});
      repository.controller.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(topBalancesProvider),
        isA<AsyncError<List<FriendListItem>>>(),
      );
    });

    test('returned list is unmodifiable', () async {
      container.listen(topBalancesProvider, (_, __) {});
      await emit([_doc(otherUid: 'uid-a', paise: 1000)]);
      final items = container.read(topBalancesProvider).value!;
      expect(() => items.add(items.first), throwsUnsupportedError);
    });
  });
}
