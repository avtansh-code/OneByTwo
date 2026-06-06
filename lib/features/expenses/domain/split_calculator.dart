import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// A single split row — one member's share in integer paise.
///
/// Per **invariant 1** (paise integers), [sharePaise] is `int`; no
/// `double` value is ever computed on the amount path. The splitter
/// returns a `List<Split>` ordered to match the caller's `memberUids`
/// argument (current-user-first by convention).
@immutable
class Split {
  /// Creates a [Split].
  const Split({required this.userId, required this.sharePaise});

  /// The member's UID.
  final String userId;

  /// The member's share of the expense, in paise (`>= 0`).
  final int sharePaise;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Split &&
        other.userId == userId &&
        other.sharePaise == sharePaise;
  }

  @override
  int get hashCode => Object.hash(userId, sharePaise);
}

/// Pure top-level splitter. Computes per-member shares for an expense
/// from a total in integer paise.
///
/// The function is integer-only, deterministic, and side-effect-free.
/// The caller (the Add Expense controller) MUST pre-sort [memberUids]
/// current-user-first; the splitter does NOT re-sort. The returned
/// `splits[i].userId` follows the order of the passed [memberUids],
/// which is the single source of truth for ordering and prevents
/// two-source-of-truth drift between the controller and the splitter.
///
/// Per-method algorithm (friendship has exactly two members; N = 2):
///
/// - [SplitMethod.equal]: `share = totalPaise ~/ 2;
///   remainder = totalPaise % 2;` →
///   `[{memberUids[0]: share + remainder}, {memberUids[1]: share}]`.
///   The extra paise lands on the first share (deterministic;
///   current-user-first). Sum is `totalPaise` by construction.
/// - [SplitMethod.exact]: returns
///   `[{memberUids[0]: exactShares[0]}, {memberUids[1]: exactShares[1]}]`.
///   The controller's validator gates on
///   `exactShares.fold(0, (a, b) => a + b) == totalPaise` BEFORE this
///   function is called; the splitter `assert`s the same invariant as
///   defence in depth (the assertion only fires in debug; the security
///   rules' `sumOfSharesEquals` check is the production safety net).
/// - [SplitMethod.unequal], [SplitMethod.percentage], [SplitMethod.shares]
///   are present in the enum but disabled in FR-EX-01; calling
///   [computeSplits] with one of them throws an [UnimplementedError]
///   (the controller silently no-ops on their selection, so this is
///   only reachable by misuse — defence in depth).
List<Split> computeSplits({
  required SplitMethod method,
  required int totalPaise,
  required List<String> memberUids,
  String? payerUid,
  List<int>? exactShares,
}) {
  assert(memberUids.length == 2, 'FR-EX-01 supports exactly two members');

  switch (method) {
    case SplitMethod.equal:
      final share = totalPaise ~/ 2;
      final remainder = totalPaise % 2;
      return <Split>[
        Split(userId: memberUids[0], sharePaise: share + remainder),
        Split(userId: memberUids[1], sharePaise: share),
      ];

    case SplitMethod.exact:
      assert(
        exactShares != null,
        'exactShares must be supplied for SplitMethod.exact',
      );
      final shares = exactShares!;
      assert(
        shares.length == memberUids.length,
        'exactShares.length must equal memberUids.length '
        '(got ${shares.length} vs ${memberUids.length})',
      );
      final sum = shares.fold<int>(0, (a, b) => a + b);
      assert(
        sum == totalPaise,
        'exactShares must sum to totalPaise (sum=$sum, total=$totalPaise) '
        '— the controller MUST validate before calling computeSplits',
      );
      return <Split>[
        for (var i = 0; i < memberUids.length; i++)
          Split(userId: memberUids[i], sharePaise: shares[i]),
      ];

    case SplitMethod.unequal:
    case SplitMethod.percentage:
    case SplitMethod.shares:
      throw UnimplementedError(
        '${method.name} split method is deferred to a follow-up PR; the '
        'controller treats its selection as a no-op',
      );
  }
}
