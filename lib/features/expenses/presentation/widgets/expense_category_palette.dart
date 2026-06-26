import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';

/// Maps a domain [ExpenseCategory] to its Haldi-palette [OBTCategory] hue
/// key (foundation plan section 1.6).
///
/// The domain enum's `travel` maps to the palette's `transport`; every
/// other value maps by name. Mirrors the FR-HD-03 spending palette and the
/// Friends `friendCategoryKey` so the Expenses surfaces (Haldi 21, 22) reuse
/// the single 8-hue source of truth ([OBTColors.category]) rather than
/// hard-coding any category hex at the call site.
OBTCategory expenseCategoryPaletteKey(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.food:
      return OBTCategory.food;
    case ExpenseCategory.travel:
      return OBTCategory.transport;
    case ExpenseCategory.rent:
      return OBTCategory.rent;
    case ExpenseCategory.utilities:
      return OBTCategory.utilities;
    case ExpenseCategory.groceries:
      return OBTCategory.groceries;
    case ExpenseCategory.entertainment:
      return OBTCategory.entertainment;
    case ExpenseCategory.shopping:
      return OBTCategory.shopping;
    case ExpenseCategory.other:
      return OBTCategory.other;
  }
}

/// Decorative rounded category avatar — the Haldi leading tile for the
/// Expense Detail header (Haldi 22): the category glyph in its full hue on
/// a ~12%-opacity bed of the same hue.
///
/// Purely decorative ([ExcludeSemantics]); the surrounding row owns the
/// textual description so a screen reader announces the expense once.
class ExpenseCategoryAvatar extends StatelessWidget {
  /// Creates an [ExpenseCategoryAvatar].
  const ExpenseCategoryAvatar({required this.category, super.key});

  /// The domain category driving the hue and glyph.
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final obtColors =
        Theme.of(context).extension<OBTColors>() ?? OBTColors.light;
    final hue = obtColors.categoryColor(expenseCategoryPaletteKey(category));
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Icon(
          expenseCategoryIcon[category] ?? Icons.receipt_long,
          size: 24,
          color: hue,
        ),
      ),
    );
  }
}
