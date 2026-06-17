import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_aggregator.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_breakdown.dart';

/// Feature-local injectable clock for the IST month window (FR-HD-03).
///
/// Global and unscoped, so it is NOT listed in
/// [monthlySpendBreakdownProvider]'s `dependencies`. Mirrors the
/// codebase's `DateTime Function()` clock convention: production reads
/// `DateTime.now`; month-boundary tests override it with a fixed instant
/// for determinism (ADR-0017 section 5).
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// FR-HD-03 — the signed-in user's current-month spend, grouped by
/// [CategorySpend] category and folded across **all** friendships.
///
/// A one-shot `FutureProvider` that:
/// 1. awaits the already-resolved [friendsListProvider] (the card lives
///    in the dashboard's populated state, so the friends list is
///    resolved when the card mounts);
/// 2. computes the IST month window from [homeClockProvider];
/// 3. fans out a per-friendship current-month read via
///    `ExpenseRepository.fetchExpensesInMonth` with `Future.wait`; and
/// 4. reduces the fan-out through the pure [aggregateMonthlySpend].
///
/// It declares `dependencies: [friendsListProvider]` — exactly that, to
/// propagate the friends-list provider's per-arm `currentUserIdProvider`
/// scoping — and never reads `currentUserIdProvider` directly: the
/// user's share is derived from the counterparty complement
/// (`FriendListItem.otherUserId`) inside the aggregator (ADR-0017
/// sections 2 and 4).
///
/// **Group axis (Sprint 3 seam).** This folds the friendship axis only;
/// the group axis is a forward-compat stub, exactly as
/// `topBalancesProvider` stubbed groups. No Groups Dart is written here.
///
/// **Retry.** `ref.invalidate(monthlySpendBreakdownProvider)` re-runs the
/// fan-out; because the card sits in the populated state, the fan-out is
/// the only failure source, so invalidating this provider alone is
/// sufficient (the balances axis is undisturbed).
///
/// **Invariants.** Integer paise throughout (Invariant 1); reads
/// `expenses` only and never `simplifiedBalances` (Invariant 2 N/A).
final monthlySpendBreakdownProvider = FutureProvider<MonthlySpendBreakdown>((
  ref,
) async {
  final items = await ref.watch(friendsListProvider.future);
  final window = currentMonthWindowIst(ref.watch(homeClockProvider)());
  final repository = ref.watch(expenseRepositoryProvider);

  final perFriendship = await Future.wait(
    items.map((item) async {
      final expenses = await repository.fetchExpensesInMonth(
        friendshipId: item.friendshipId,
        monthStartUtc: window.startUtc,
      );
      return (otherUserId: item.otherUserId, expenses: expenses);
    }),
  );

  return aggregateMonthlySpend(
    input: perFriendship,
    monthStartUtc: window.startUtc,
    nextMonthStartUtc: window.endUtc,
  );
}, dependencies: [friendsListProvider]);
