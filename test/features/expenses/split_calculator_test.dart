// Split calculator unit tests (FR-EX-01 / FR-EX-04).
//
// Tests the pure top-level `computeSplits` function that converts an
// integer paise total into per-member share amounts. The calculator is
// the load-bearing piece for invariant 1 (paise integers, no `double`)
// and FR-EX-04 (sum exactly equals total).
//
// These tests are written BEFORE the implementation exists (test-first
// per `docs/copilot_prompts/sprint_2/7.md` Phase 4). They will fail to
// compile until `lib/features/expenses/domain/split_calculator.dart`
// and `lib/features/expenses/domain/split_method.dart` are added.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

void main() {
  group('computeSplits — equal method (even totals)', () {
    test('1000 paise splits 500 / 500', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 1000,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result, hasLength(2));
      expect(result[0].userId, 'uid-a');
      expect(result[0].sharePaise, 500);
      expect(result[1].userId, 'uid-b');
      expect(result[1].sharePaise, 500);
    });

    test('2 paise splits 1 / 1', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 2,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result[0].sharePaise, 1);
      expect(result[1].sharePaise, 1);
    });

    test(
        'the maximum permitted total (99999998 paise, even) splits cleanly',
        () {
      // 99999998 is the largest even value at or below the AC-2 cap.
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 99999998,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result[0].sharePaise, 49999999);
      expect(result[1].sharePaise, 49999999);
    });
  });

  group('computeSplits — equal method (odd totals)', () {
    test('1001 paise splits 501 / 500 (extra paise on first share)', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 1001,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result[0].userId, 'uid-a');
      expect(result[0].sharePaise, 501);
      expect(result[1].userId, 'uid-b');
      expect(result[1].sharePaise, 500);
    });

    test('1 paisa total splits 1 / 0', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 1,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result[0].sharePaise, 1);
      expect(result[1].sharePaise, 0);
    });

    test('the maximum permitted total (99999999 paise, odd) splits with '
        'remainder on first', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 99999999,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result[0].sharePaise, 50000000);
      expect(result[1].sharePaise, 49999999);
    });
  });

  group('computeSplits — equal method preserves caller member ordering', () {
    test('current user first (uid-a, uid-b) lands extra on first', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 101,
        memberUids: const ['uid-a', 'uid-b'],
      );

      expect(result[0].userId, 'uid-a');
      expect(result[0].sharePaise, 51);
      expect(result[1].sharePaise, 50);
    });

    test('current user first (uid-b, uid-a) lands extra on uid-b', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 101,
        memberUids: const ['uid-b', 'uid-a'],
      );

      expect(
        result[0].userId,
        'uid-b',
        reason:
            'splitter must NOT re-sort; caller establishes current-user-first',
      );
      expect(result[0].sharePaise, 51);
      expect(result[1].userId, 'uid-a');
      expect(result[1].sharePaise, 50);
    });
  });

  group('computeSplits — exact method', () {
    test('returns identity for a valid (sum-matching) shares list', () {
      final result = computeSplits(
        method: SplitMethod.exact,
        totalPaise: 1500,
        memberUids: const ['uid-a', 'uid-b'],
        exactShares: const [700, 800],
      );

      expect(result, hasLength(2));
      expect(result[0].userId, 'uid-a');
      expect(result[0].sharePaise, 700);
      expect(result[1].userId, 'uid-b');
      expect(result[1].sharePaise, 800);
    });

    test('accepts a zero share for one member', () {
      final result = computeSplits(
        method: SplitMethod.exact,
        totalPaise: 1000,
        memberUids: const ['uid-a', 'uid-b'],
        exactShares: const [1000, 0],
      );

      expect(result[0].sharePaise, 1000);
      expect(result[1].sharePaise, 0);
    });

    test('throws AssertionError in debug when exact shares do not sum to '
        'totalPaise', () {
      expect(
        () => computeSplits(
          method: SplitMethod.exact,
          totalPaise: 1000,
          memberUids: const ['uid-a', 'uid-b'],
          exactShares: const [400, 500], // sums to 900, not 1000
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError in debug when exact shares length mismatches '
        'memberUids', () {
      expect(
        () => computeSplits(
          method: SplitMethod.exact,
          totalPaise: 1000,
          memberUids: const ['uid-a', 'uid-b'],
          exactShares: const [1000], // wrong length
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('computeSplits — sum invariant (FR-EX-04)', () {
    // For the equal method, no caller-side validation is needed; this
    // group asserts the splitter's own correctness by construction.
    test('equal: splits[0] + splits[1] == totalPaise for representative '
        'amounts', () {
      const amounts = <int>[1, 2, 3, 99, 100, 101, 999, 1000, 1001, 99999999];

      for (final amount in amounts) {
        final result = computeSplits(
          method: SplitMethod.equal,
          totalPaise: amount,
          memberUids: const ['uid-a', 'uid-b'],
        );
        final sum = result[0].sharePaise + result[1].sharePaise;
        expect(
          sum,
          amount,
          reason: 'Sum mismatch for totalPaise=$amount: got $sum',
        );
      }
    });

    test('exact: sum equals totalPaise for representative pairs', () {
      const cases = <(int total, List<int> shares)>[
        (100, [50, 50]),
        (100, [99, 1]),
        (100, [100, 0]),
        (12345, [6173, 6172]),
        (1, [1, 0]),
        (99999999, [50000000, 49999999]),
      ];

      for (final (total, shares) in cases) {
        final result = computeSplits(
          method: SplitMethod.exact,
          totalPaise: total,
          memberUids: const ['uid-a', 'uid-b'],
          exactShares: shares,
        );
        final sum = result[0].sharePaise + result[1].sharePaise;
        expect(sum, total);
      }
    });
  });

  group('computeSplits — type discipline (invariant 1)', () {
    test('every sharePaise is `int` (not double, not num)', () {
      final result = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 999,
        memberUids: const ['uid-a', 'uid-b'],
      );

      for (final split in result) {
        expect(split.sharePaise, isA<int>());
        expect(split.sharePaise, isNot(isA<double>()));
      }
    });
  });

  group('computeSplits — determinism', () {
    test('equal: two invocations with identical args return equal splits', () {
      final r1 = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 12345,
        memberUids: const ['uid-x', 'uid-y'],
      );
      final r2 = computeSplits(
        method: SplitMethod.equal,
        totalPaise: 12345,
        memberUids: const ['uid-x', 'uid-y'],
      );

      expect(r1.length, r2.length);
      for (var i = 0; i < r1.length; i++) {
        expect(r1[i].userId, r2[i].userId);
        expect(r1[i].sharePaise, r2[i].sharePaise);
      }
    });

    test('exact: two invocations with identical args return equal splits', () {
      final r1 = computeSplits(
        method: SplitMethod.exact,
        totalPaise: 1000,
        memberUids: const ['uid-x', 'uid-y'],
        exactShares: const [300, 700],
      );
      final r2 = computeSplits(
        method: SplitMethod.exact,
        totalPaise: 1000,
        memberUids: const ['uid-x', 'uid-y'],
        exactShares: const [300, 700],
      );

      expect(r1.length, r2.length);
      for (var i = 0; i < r1.length; i++) {
        expect(r1[i].userId, r2[i].userId);
        expect(r1[i].sharePaise, r2[i].sharePaise);
      }
    });
  });
}
