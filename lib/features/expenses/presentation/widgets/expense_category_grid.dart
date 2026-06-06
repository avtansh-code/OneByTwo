import 'package:flutter/material.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';

/// Single-select grid of the eight FR-EX-08 category chips.
///
/// Future extraction note: the per-chip rendering will move to the
/// reusable OBTCategoryChip in a follow-up; PR #38 inlines.
class ExpenseCategoryGrid extends StatelessWidget {
  /// Creates an [ExpenseCategoryGrid].
  const ExpenseCategoryGrid({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Currently selected category, or `null` if none.
  final ExpenseCategory? selected;

  /// Fires when the user taps a chip.
  final ValueChanged<ExpenseCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.values
          .map(
            (cat) => ChoiceChip(
              avatar: Icon(expenseCategoryIcon[cat]),
              label: Text(expenseCategoryLabel[cat]!),
              selected: selected == cat,
              onSelected: (_) => onSelected(cat),
            ),
          )
          .toList(growable: false),
    );
  }
}
