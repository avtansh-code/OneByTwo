import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_breakdown.dart';

/// India Standard Time (`Asia/Kolkata`) is a fixed `+05:30` offset with
/// no daylight saving, so the month boundary needs no `timezone`/`intl`
/// initialisation — a constant [Duration] suffices (ADR-0017 section 3).
const Duration _istShift = Duration(hours: 5, minutes: 30);

/// One friendship's fan-out input for [aggregateMonthlySpend]: the
/// counterparty's UID plus that friendship's fetched current-month
/// expenses. The user's own share is the complement of the
/// `otherUserId`'s splits (ADR-0017 section 2), so the aggregator never
/// needs to read `currentUserIdProvider`.
typedef FriendshipExpenses = ({String otherUserId, List<ExpenseDoc> expenses});

/// Computes the current calendar month window **in IST**, returned as
/// absolute UTC instants (FR-HD-03, SRS section 5.9; ADR-0017 section 3).
///
/// - `startUtc` is the first instant of the IST month.
/// - `endUtc` is the first instant of the **next** IST month; Dart rolls
///   month 13 into the next January, so December is handled.
///
/// For a [now] in June 2026 this yields
/// `startUtc = 2026-05-31T18:30:00Z` (= `2026-06-01T00:00:00+05:30`) and
/// `endUtc = 2026-06-30T18:30:00Z`.
({DateTime startUtc, DateTime endUtc}) currentMonthWindowIst(DateTime now) {
  final istNow = now.toUtc().add(_istShift);
  final year = istNow.year;
  final month = istNow.month;
  final startUtc = DateTime.utc(year, month).subtract(_istShift);
  final endUtc = DateTime.utc(year, month + 1).subtract(_istShift);
  return (startUtc: startUtc, endUtc: endUtc);
}

/// Folds the per-friendship fan-out into a [MonthlySpendBreakdown]
/// (FR-HD-03; ADR-0017 sections 2 and 4).
///
/// For each expense, the user's spend is the sum of `split.sharePaise`
/// over the splits whose `userId != otherUserId` — the counterparty
/// complement, which the Security Rules' `areSplitMembers` guarantee is
/// the user's own split. An expense the user is not a split member of
/// contributes `0`.
///
/// An expense is included iff its `date` is in the half-open window
/// `[monthStartUtc, nextMonthStartUtc)` — `DateTime.isBefore` compares
/// absolute instants regardless of the `isUtc` flag, so no manual
/// normalisation is needed. Soft-deleted expenses never reach the
/// reducer: they are excluded by the repository's `deleted == false`
/// query filter (ADR-0017 section 5).
///
/// Non-zero category subtotals are sorted by descending paise (ties
/// broken on `ExpenseCategory.index`); the month total is their sum.
/// All arithmetic is integer paise (Invariant 1).
MonthlySpendBreakdown aggregateMonthlySpend({
  required Iterable<FriendshipExpenses> input,
  required DateTime monthStartUtc,
  required DateTime nextMonthStartUtc,
}) {
  final totals = <ExpenseCategory, int>{};

  for (final friendship in input) {
    for (final expense in friendship.expenses) {
      if (expense.date.isBefore(monthStartUtc)) continue;
      if (!expense.date.isBefore(nextMonthStartUtc)) continue;
      final share = _userSharePaise(expense, friendship.otherUserId);
      if (share == 0) continue;
      totals.update(
        expense.category,
        (current) => current + share,
        ifAbsent: () => share,
      );
    }
  }

  final categories =
      <CategorySpend>[
        for (final entry in totals.entries)
          if (entry.value != 0)
            CategorySpend(category: entry.key, totalPaise: entry.value),
      ]..sort((a, b) {
        final byPaise = b.totalPaise.compareTo(a.totalPaise);
        if (byPaise != 0) return byPaise;
        return a.category.index.compareTo(b.category.index);
      });

  final monthTotalPaise = categories.fold<int>(
    0,
    (sum, spend) => sum + spend.totalPaise,
  );

  return MonthlySpendBreakdown(
    categories: List<CategorySpend>.unmodifiable(categories),
    monthTotalPaise: monthTotalPaise,
  );
}

/// Sums the user's own share of [expense] in integer paise — every
/// split whose `userId` is **not** the [otherUserId] counterparty. Zero
/// when the user is not a split member.
int _userSharePaise(ExpenseDoc expense, String otherUserId) {
  var share = 0;
  for (final split in expense.splits) {
    if (split.userId != otherUserId) {
      share += split.sharePaise;
    }
  }
  return share;
}
