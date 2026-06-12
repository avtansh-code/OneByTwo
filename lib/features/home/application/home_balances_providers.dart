import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';

/// Maximum number of rows the Home dashboard "Top Balances" section
/// renders (FR-HD-02 — "top 5 friends/groups by absolute simplified
/// balance"). There is no "View all" affordance on the dashboard in
/// v1.0; users open the Friends tab for the full list.
const int topBalancesCap = 5;

/// FR-HD-01 — the user's **overall net simplified balance** in signed
/// integer paise, folded across every friendship.
///
/// Pure read-side reducer over [friendsListProvider]: the sum of each
/// `FriendListItem.netBalancePaise`. Positive ⇒ the user is owed
/// overall; negative ⇒ the user owes overall; zero ⇒ all settled up
/// (even when individual friendships carry non-zero balances that
/// cancel out — see [topBalancesProvider]).
///
/// **Invariant 1 (integer paise).** The fold accumulates `int` values
/// and never produces a `double`. The widget layer converts to INR
/// exclusively via `formatInrFromPaise()`.
///
/// **Invariant 2 (`simplifiedBalances` server-maintained).** This is a
/// READ-ONLY projection. It composes the existing friends-list stream
/// and never writes the field.
///
/// The provider mirrors the upstream [friendsListProvider] async
/// lifecycle: `AsyncLoading` while the first Firestore snapshot
/// resolves, `AsyncError` if the snapshot stream fails, otherwise
/// `AsyncData<int>`. It declares `dependencies: [friendsListProvider]`
/// to propagate that provider's scoping — `friendsListProvider` is
/// itself scoped on the per-arm `currentUserIdProvider` override bound
/// by the authenticated shell (`lib/main.dart`), so any provider that
/// watches it must list it as a dependency.
final overallNetBalanceProvider = Provider<AsyncValue<int>>((ref) {
  final friendsAsync = ref.watch(friendsListProvider);
  return friendsAsync.whenData(
    (items) => items.fold<int>(0, (sum, item) => sum + item.netBalancePaise),
  );
}, dependencies: [friendsListProvider]);

/// FR-HD-02 — the **top friendships by absolute simplified balance**,
/// capped at [topBalancesCap], for the Home dashboard "Top Balances"
/// section.
///
/// Pure read-side projection over [friendsListProvider]:
/// 1. **Zero-exclusion.** Settled-up friendships (`netBalancePaise == 0`)
///    are dropped — only friendships with an outstanding balance surface.
/// 2. **Absolute-value sort, descending.** Largest `|netBalancePaise|`
///    first, so the most significant balances lead regardless of
///    direction (owed vs owing).
/// 3. **Stable tie-break.** The sort is stable over the upstream order,
///    which `friendsListProvider` already emits as `lastActivityAt`
///    descending (the Firestore composite-index order). Equal absolute
///    balances therefore retain the most-recently-active-first ordering
///    the SCR-06 spec prescribes, deterministically.
/// 4. **Cap.** At most [topBalancesCap] rows.
///
/// **Group axis (Sprint 3 seam).** FR-HD-02 reads "friends/groups", but
/// Groups are not implemented in v1.0 (`lib/features/groups/` is
/// README-only). This projection is friendship-only; the Group Detail
/// work in Sprint 3 slots a second source into the same "Top Balances"
/// section without changing this provider's contract.
///
/// **Invariants 1 and 2.** Same as [overallNetBalanceProvider]:
/// integer-paise throughout, READ-ONLY over `simplifiedBalances`.
final topBalancesProvider = Provider<AsyncValue<List<FriendListItem>>>((ref) {
  final friendsAsync = ref.watch(friendsListProvider);
  return friendsAsync.whenData((items) {
    final withBalance = items
        .where((item) => item.netBalancePaise != 0)
        .toList(growable: false);

    // Stable sort by descending absolute balance. `List.sort` is not
    // guaranteed stable in Dart, so we decorate with the original index
    // and use it as the tie-breaker — this preserves the upstream
    // `lastActivityAt`-descending order on equal absolute balances
    // (SCR-06 Edge Case 2).
    final decorated = withBalance.asMap().entries.toList(growable: false)
      ..sort((a, b) {
        final byAbs = b.value.netBalancePaise.abs().compareTo(
          a.value.netBalancePaise.abs(),
        );
        if (byAbs != 0) return byAbs;
        return a.key.compareTo(b.key);
      });

    final sorted = [for (final entry in decorated) entry.value];
    return List<FriendListItem>.unmodifiable(sorted.take(topBalancesCap));
  });
}, dependencies: [friendsListProvider]);
