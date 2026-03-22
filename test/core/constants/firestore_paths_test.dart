import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/constants/firestore_paths.dart';

void main() {
  group('FirestorePaths', () {
    // ── Top-level collection constants ──────────────────────────────────

    group('collection constants', () {
      test('users should be "users"', () {
        expect(FirestorePaths.users, equals('users'));
      });

      test('groups should be "groups"', () {
        expect(FirestorePaths.groups, equals('groups'));
      });

      test('friends should be "friends"', () {
        expect(FirestorePaths.friends, equals('friends'));
      });

      test('invites should be "invites"', () {
        expect(FirestorePaths.invites, equals('invites'));
      });

      test('userGroups should be "userGroups"', () {
        expect(FirestorePaths.userGroups, equals('userGroups'));
      });

      test('userFriends should be "userFriends"', () {
        expect(FirestorePaths.userFriends, equals('userFriends'));
      });
    });

    // ── Subcollection name constants ────────────────────────────────────

    group('subcollection constants', () {
      test('members should be "members"', () {
        expect(FirestorePaths.members, equals('members'));
      });

      test('expenses should be "expenses"', () {
        expect(FirestorePaths.expenses, equals('expenses'));
      });

      test('settlements should be "settlements"', () {
        expect(FirestorePaths.settlements, equals('settlements'));
      });

      test('balances should be "balances"', () {
        expect(FirestorePaths.balances, equals('balances'));
      });

      test('activity should be "activity"', () {
        expect(FirestorePaths.activity, equals('activity'));
      });

      test('notifications should be "notifications"', () {
        expect(FirestorePaths.notifications, equals('notifications'));
      });

      test('drafts should be "drafts"', () {
        expect(FirestorePaths.drafts, equals('drafts'));
      });

      test('splits should be "splits"', () {
        expect(FirestorePaths.splits, equals('splits'));
      });

      test('payers should be "payers"', () {
        expect(FirestorePaths.payers, equals('payers'));
      });

      test('items should be "items"', () {
        expect(FirestorePaths.items, equals('items'));
      });

      test('attachments should be "attachments"', () {
        expect(FirestorePaths.attachments, equals('attachments'));
      });
    });

    // ── User paths ──────────────────────────────────────────────────────

    group('user paths', () {
      test('userDoc should return users/{userId}', () {
        expect(FirestorePaths.userDoc('user-1'), equals('users/user-1'));
      });

      test('userNotifications should return users/{userId}/notifications', () {
        expect(
          FirestorePaths.userNotifications('user-1'),
          equals('users/user-1/notifications'),
        );
      });

      test('userDrafts should return users/{userId}/drafts', () {
        expect(
          FirestorePaths.userDrafts('user-1'),
          equals('users/user-1/drafts'),
        );
      });
    });

    // ── Group paths ─────────────────────────────────────────────────────

    group('group paths', () {
      test('groupDoc should return groups/{groupId}', () {
        expect(FirestorePaths.groupDoc('g1'), equals('groups/g1'));
      });

      test('groupMembers should return groups/{groupId}/members', () {
        expect(FirestorePaths.groupMembers('g1'), equals('groups/g1/members'));
      });

      test('groupExpenses should return groups/{groupId}/expenses', () {
        expect(
          FirestorePaths.groupExpenses('g1'),
          equals('groups/g1/expenses'),
        );
      });

      test('groupSettlements should return groups/{groupId}/settlements', () {
        expect(
          FirestorePaths.groupSettlements('g1'),
          equals('groups/g1/settlements'),
        );
      });

      test('groupBalances should return groups/{groupId}/balances', () {
        expect(
          FirestorePaths.groupBalances('g1'),
          equals('groups/g1/balances'),
        );
      });

      test('groupActivity should return groups/{groupId}/activity', () {
        expect(
          FirestorePaths.groupActivity('g1'),
          equals('groups/g1/activity'),
        );
      });
    });

    // ── Friend paths ────────────────────────────────────────────────────

    group('friend paths', () {
      test('friendDoc should return friends/{friendPairId}', () {
        expect(
          FirestorePaths.friendDoc('alice_bob'),
          equals('friends/alice_bob'),
        );
      });

      test('friendExpenses should return friends/{pairId}/expenses', () {
        expect(
          FirestorePaths.friendExpenses('alice_bob'),
          equals('friends/alice_bob/expenses'),
        );
      });

      test('friendSettlements should return friends/{pairId}/settlements', () {
        expect(
          FirestorePaths.friendSettlements('alice_bob'),
          equals('friends/alice_bob/settlements'),
        );
      });

      test('friendBalance should return friends/{pairId}/balance', () {
        expect(
          FirestorePaths.friendBalance('alice_bob'),
          equals('friends/alice_bob/balance'),
        );
      });

      test('friendBalanceDoc should return friends/{pairId}/balance/net', () {
        expect(
          FirestorePaths.friendBalanceDoc('alice_bob'),
          equals('friends/alice_bob/balance/net'),
        );
      });

      test('friendActivity should return friends/{pairId}/activity', () {
        expect(
          FirestorePaths.friendActivity('alice_bob'),
          equals('friends/alice_bob/activity'),
        );
      });
    });

    // ── friendPairId ────────────────────────────────────────────────────

    group('friendPairId', () {
      test('should produce canonical order: alphabetically sorted', () {
        expect(
          FirestorePaths.friendPairId('bob', 'alice'),
          equals('alice_bob'),
        );
      });

      test('should produce same result regardless of argument order', () {
        final ab = FirestorePaths.friendPairId('alice', 'bob');
        final ba = FirestorePaths.friendPairId('bob', 'alice');
        expect(ab, equals(ba));
      });

      test('should produce a_b when a < b', () {
        expect(
          FirestorePaths.friendPairId('alice', 'bob'),
          equals('alice_bob'),
        );
      });

      test('should handle same-prefix IDs correctly', () {
        expect(
          FirestorePaths.friendPairId('user-10', 'user-2'),
          equals('user-10_user-2'),
        );
      });

      test('should handle identical user IDs', () {
        expect(
          FirestorePaths.friendPairId('user-1', 'user-1'),
          equals('user-1_user-1'),
        );
      });

      test('should separate IDs with underscore', () {
        final pairId = FirestorePaths.friendPairId('x', 'y');
        expect(pairId, contains('_'));
        expect(pairId.split('_').length, equals(2));
      });
    });
  });
}
