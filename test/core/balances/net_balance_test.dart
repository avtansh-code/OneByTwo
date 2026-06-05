// Net balance pure-function tests.
//
// Tests the canonical signed-paise reducer for the nested
// `simplifiedBalances` map produced by the
// `recomputeSimplifiedBalances` Cloud Function. The function is the
// READ-side companion to the simplified-debts algorithm in
// `functions/src/simplified-debts/` (PR #12) and must respect
// invariant 1 (integer paise) throughout.
//
// These tests are written BEFORE the implementation exists
// (test-first). They will fail to compile until
// `lib/core/balances/net_balance.dart` is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/balances/net_balance.dart';

void main() {
  const me = 'uid-me';
  const friend = 'uid-friend';
  const stranger = 'uid-stranger';

  group('netBalancePaise — empty / missing input', () {
    test('returns 0 for null map (freshly-created friendship)', () {
      final result = netBalancePaise(
        simplifiedBalances: null,
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 0);
    });

    test('returns 0 for empty map', () {
      final result = netBalancePaise(
        simplifiedBalances: const <String, dynamic>{},
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 0);
    });

    test('returns 0 when the map omits both users', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          'uid-other-pair-a': {'uid-other-pair-b': 5000},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 0);
    });
  });

  group('netBalancePaise — directional cases', () {
    test('only-creditor: friend owes me ⇒ positive paise', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: 12345},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 12345);
    });

    test('only-debtor: I owe friend ⇒ negative paise', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          me: {friend: 9999},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, -9999);
    });

    test('both directions cancel exactly ⇒ 0', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: 500},
          me: {friend: 500},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 0);
    });

    test('both directions ⇒ signed difference (friend owes more)', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: 2000},
          me: {friend: 750},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 1250);
    });

    test('both directions ⇒ signed difference (I owe more)', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: 100},
          me: {friend: 600},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, -500);
    });
  });

  group('netBalancePaise — ignores unrelated entries', () {
    test('three-way map: only the (me, friend) pair contributes', () {
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: 1000, stranger: 99999},
          me: {friend: 400, stranger: 88888},
          stranger: {me: 77777, friend: 66666},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      // Only friend->me (1000) and me->friend (400) count.
      expect(result, 600);
    });
  });

  group('netBalancePaise — boundary / robustness', () {
    test('handles very large balances without overflowing 64-bit int', () {
      // 9 quadrillion paise, well within int64.
      const largePaise = 9000000000000000;
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: largePaise},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, largePaise);
    });

    test('malformed nested value (string where int expected) ⇒ 0 for that '
        'pair, function does not throw', () {
      // The defensive contract: a corrupt value silently contributes 0 from
      // this function. The FriendshipDoc parsing layer is responsible for
      // logging the parse failure; net_balance must never crash on bad data.
      final result = netBalancePaise(
        simplifiedBalances: const {
          friend: {me: 'not-an-int'},
        },
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 0);
    });

    test('malformed outer value (non-map where map expected) ⇒ 0', () {
      final result = netBalancePaise(
        simplifiedBalances: const {friend: 'not-a-map'},
        currentUserId: me,
        otherUserId: friend,
      );
      expect(result, 0);
    });

    test(
      'mixed valid + malformed nested entries: only valid ones contribute',
      () {
        final result = netBalancePaise(
          simplifiedBalances: const {
            friend: {me: 1234, stranger: 'garbage'},
          },
          currentUserId: me,
          otherUserId: friend,
        );
        expect(result, 1234);
      },
    );
  });
}
