import 'package:flutter/material.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';

/// Maps each domain [ExpenseCategory] to its Haldi-palette [OBTCategory]
/// hue key (DC-05; foundation plan section 1.6).
///
/// The domain enum's `travel` maps to the palette's `transport`; every
/// other value maps by name. The eight Haldi hues live in a single source
/// of truth — `OBTColors.category` — so the FR-HD-03 donut and legend
/// never hard-code a category hex.
const Map<ExpenseCategory, OBTCategory> _haldiCategoryKey =
    <ExpenseCategory, OBTCategory>{
      ExpenseCategory.food: OBTCategory.food,
      ExpenseCategory.travel: OBTCategory.transport,
      ExpenseCategory.rent: OBTCategory.rent,
      ExpenseCategory.utilities: OBTCategory.utilities,
      ExpenseCategory.groceries: OBTCategory.groceries,
      ExpenseCategory.entertainment: OBTCategory.entertainment,
      ExpenseCategory.shopping: OBTCategory.shopping,
      ExpenseCategory.other: OBTCategory.other,
    };

/// Resolves the brightness-aware Haldi swatch/segment colour for
/// [category] for the FR-HD-03 monthly category-breakdown donut and legend
/// (SCR-06; DC-05).
///
/// The hue is sourced from the Haldi 8-hue palette ([OBTColors.category]):
/// the `light` token set for [Brightness.light] and `dark` for
/// [Brightness.dark]. The eight hues are colour-blind-separable and each
/// meets WCAG 2.1 AA (>= 3:1) against the card surface in its theme.
/// Colour is never the sole signal: every segment is also labelled (swatch
/// + icon + label + rupee value + percentage) and announced to the screen
/// reader. Falls back to the `other` hue for an unmapped category
/// (defensive — the map is exhaustive over the eight-value enum).
Color spendingCategoryColor(ExpenseCategory category, Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? OBTColors.dark
      : OBTColors.light;
  return tokens.categoryColor(_haldiCategoryKey[category] ?? OBTCategory.other);
}
