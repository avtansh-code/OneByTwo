import 'package:flutter/material.dart';

import 'package:onebytwo/core/widgets/inputs/obt_category_chip.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/expense_category_palette.dart';

/// Single-select grid of the eight FR-EX-08 category chips, rendered with
/// the shared Haldi [OBTCategoryChip] (Haldi 21): a full-hue category icon
/// on a ~10%-opacity bed of the `OBTColors.category` 8-hue palette, keyed
/// off the domain [ExpenseCategory] via [expenseCategoryPaletteKey]. No
/// category hex is hard-coded at the call site.
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
    // Constrain each chip to the available width so a long label
    // (e.g. "Entertainment") wraps within the chip at large dynamic type
    // rather than overflowing the row (no overflow at 2.0x / 320 dp).
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExpenseCategory.values
              .map(
                (cat) => ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: OBTCategoryChip(
                    category: expenseCategoryPaletteKey(cat),
                    icon: expenseCategoryIcon[cat]!,
                    label: expenseCategoryLabel[cat]!,
                    selected: selected == cat,
                    onSelected: (_) => onSelected(cat),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
