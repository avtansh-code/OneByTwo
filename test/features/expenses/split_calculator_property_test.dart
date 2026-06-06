// Split calculator property tests (FR-EX-01 / FR-EX-04).
//
// Property-based tests that mirror the discipline established on the
// server splitter at
// `functions/test/simplified-debts/algorithm.property.test.ts`. These
// tests sample a wide range of inputs and assert structural invariants
// rather than specific values.
//
// Properties asserted:
// 1. `equal` with any totalPaise in [1, 99999999] produces splits whose
//    sum equals totalPaise.
// 2. `exact` with any valid (sum-matching) shares returns identity and
//    the sum still equals totalPaise.
// 3. Determinism — for any input, two invocations return splits with
//    identical ordering and values.
// 4. For any odd totalPaise on the equal method,
//    splits[0].sharePaise == splits[1].sharePaise + 1.
//
// These tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

void main() {
  // Deterministic seed so failures are reproducible.
  final random = Random(42);

  /// Generates a value in `[min, max]` inclusive.
  int sample(int min, int max) => min + random.nextInt(max - min + 1);

  group('property: equal-split sum invariant (FR-EX-04)', () {
    test('sum equals totalPaise for 500 sampled values in [1, 99999999]', () {
      const trials = 500;
      for (var i = 0; i < trials; i++) {
        final total = sample(1, 99999999);
        final result = computeSplits(
          method: SplitMethod.equal,
          totalPaise: total,
          memberUids: const ['uid-current', 'uid-other'],
        );

        final sum = result[0].sharePaise + result[1].sharePaise;
        expect(
          sum,
          total,
          reason:
              'Sum mismatch on trial $i: total=$total, sum=$sum, '
              'splits=[${result[0].sharePaise}, ${result[1].sharePaise}]',
        );
      }
    });
  });

  group('property: extra paise lands on first share for odd totals', () {
    test('splits[0] == splits[1] + 1 for every odd sample', () {
      const trials = 300;
      for (var i = 0; i < trials; i++) {
        var total = sample(1, 99999999);
        if (total.isEven) total += 1;
        if (total > 99999999) total = 99999999; // boundary safety

        final result = computeSplits(
          method: SplitMethod.equal,
          totalPaise: total,
          memberUids: const ['uid-current', 'uid-other'],
        );

        expect(
          result[0].sharePaise,
          equals(result[1].sharePaise + 1),
          reason:
              'Odd total $total should give first share = second + 1; '
              'got ${result[0].sharePaise}, ${result[1].sharePaise}',
        );
      }
    });
  });

  group('property: equal splits are non-negative integers', () {
    test('every share is >= 0 across 300 sampled values', () {
      const trials = 300;
      for (var i = 0; i < trials; i++) {
        final total = sample(1, 99999999);
        final result = computeSplits(
          method: SplitMethod.equal,
          totalPaise: total,
          memberUids: const ['uid-current', 'uid-other'],
        );

        for (final split in result) {
          expect(split.sharePaise, greaterThanOrEqualTo(0));
          expect(split.sharePaise, isA<int>());
        }
      }
    });
  });

  group('property: exact returns identity', () {
    test(
      '100 sampled (total, [a, total-a]) pairs return the input verbatim',
      () {
        const trials = 100;
        for (var i = 0; i < trials; i++) {
          final total = sample(1, 99999999);
          final first = sample(0, total);
          final second = total - first;

          final result = computeSplits(
            method: SplitMethod.exact,
            totalPaise: total,
            memberUids: const ['uid-current', 'uid-other'],
            exactShares: [first, second],
          );

          expect(result[0].sharePaise, first);
          expect(result[1].sharePaise, second);
          expect(result[0].sharePaise + result[1].sharePaise, total);
        }
      },
    );
  });

  group('property: determinism', () {
    test(
      'repeated invocations with identical inputs produce identical outputs',
      () {
        const trials = 100;
        for (var i = 0; i < trials; i++) {
          final total = sample(1, 99999999);
          final r1 = computeSplits(
            method: SplitMethod.equal,
            totalPaise: total,
            memberUids: const ['uid-x', 'uid-y'],
          );
          final r2 = computeSplits(
            method: SplitMethod.equal,
            totalPaise: total,
            memberUids: const ['uid-x', 'uid-y'],
          );

          for (var j = 0; j < r1.length; j++) {
            expect(r1[j].userId, r2[j].userId);
            expect(r1[j].sharePaise, r2[j].sharePaise);
          }
        }
      },
    );
  });

  group('property: caller ordering preserved', () {
    test('splits[i].userId equals memberUids[i] for the equal method', () {
      const trials = 100;
      for (var i = 0; i < trials; i++) {
        final total = sample(1, 99999999);
        // Randomise the member-uid pair each iteration to avoid relying
        // on alphabetical accidents.
        final firstUid = 'uid-${random.nextInt(1 << 20)}';
        final secondUid = 'uid-${random.nextInt(1 << 20)}';
        final members = [firstUid, secondUid];

        final result = computeSplits(
          method: SplitMethod.equal,
          totalPaise: total,
          memberUids: members,
        );

        expect(result[0].userId, firstUid);
        expect(result[1].userId, secondUid);
      }
    });
  });
}
