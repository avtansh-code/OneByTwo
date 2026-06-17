import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/expenses/domain/expense_category.dart';

/// The signed-in user's own current-month spend in a single
/// [ExpenseCategory], in integer paise (FR-HD-03).
///
/// "Spend" is the user's **own `sharePaise`** summed over the category's
/// in-window expenses — never the bill total. [totalPaise] is always
/// `> 0`: zero-valued categories are dropped by the aggregator
/// (`aggregateMonthlySpend`) and never reach this value object.
///
/// **Invariant 1 (integer paise).** [totalPaise] is `int`; the only
/// paise-to-rupee conversion is `formatInrFromPaise(int)` at the widget
/// layer. Per-segment percentages are derived ratios computed at render
/// time and are not money.
@immutable
class CategorySpend {
  /// Creates a [CategorySpend].
  const CategorySpend({required this.category, required this.totalPaise});

  /// The expense category this subtotal belongs to.
  final ExpenseCategory category;

  /// The user's own spend in this category, in integer paise (`> 0`).
  final int totalPaise;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategorySpend &&
        other.category == category &&
        other.totalPaise == totalPaise;
  }

  @override
  int get hashCode => Object.hash(category, totalPaise);
}

/// The signed-in user's current-month spend, grouped by
/// [ExpenseCategory] and folded across every friendship (FR-HD-03).
///
/// [categories] holds only the **non-zero** categories, sorted by
/// **descending [CategorySpend.totalPaise]** (ties broken on the
/// `ExpenseCategory.index` for determinism). [monthTotalPaise] equals
/// the sum of the categories' subtotals. When the month total is `0`
/// (no qualifying spend) [categories] is empty and [isEmpty] is `true`,
/// which drives the card's empty sub-state.
///
/// **Invariant 1 (integer paise).** Every subtotal and the month total
/// is an integer paise sum.
@immutable
class MonthlySpendBreakdown {
  /// Creates a [MonthlySpendBreakdown].
  const MonthlySpendBreakdown({
    required this.categories,
    required this.monthTotalPaise,
  });

  /// The non-zero category subtotals, descending by paise (unmodifiable).
  final List<CategorySpend> categories;

  /// The sum of every category subtotal, in integer paise.
  final int monthTotalPaise;

  /// Whether there is no current-month spend (drives the empty card).
  bool get isEmpty => categories.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlySpendBreakdown &&
        listEquals(other.categories, categories) &&
        other.monthTotalPaise == monthTotalPaise;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(categories), monthTotalPaise);
}
