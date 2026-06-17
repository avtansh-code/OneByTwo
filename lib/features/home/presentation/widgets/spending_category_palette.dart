import 'package:flutter/material.dart';

import 'package:onebytwo/features/expenses/domain/expense_category.dart';

/// Feature-local, brightness-aware colour palette for the FR-HD-03
/// monthly category-breakdown donut and legend (SCR-06; `tokens.md`
/// section 1.3 "Expense Category Palette").
///
/// One colour per [ExpenseCategory], transcribed 1:1 from the design
/// tokens. The eight hues are colour-blind-separable and each meets
/// WCAG 2.1 AA (>= 3:1) against the card surface in its theme — light
/// fills on `#FFFFFF`, dark fills on `#1E1E1E`. Colour is never the sole
/// signal: every segment is also labelled (swatch + icon + label +
/// rupee value + percentage) and announced to the screen reader.
///
/// Consistent with `tokens.md`, the palette is **not** a
/// `ThemeExtension`; it lives alongside the feature that consumes it,
/// mirroring how `AppTheme` holds its semantic colours as static consts.
abstract final class SpendingCategoryPalette {
  /// Light-theme segment + swatch colours (tokens.md section 1.3.1).
  static const Map<ExpenseCategory, Color> light = {
    ExpenseCategory.food: Color(0xFFB23A48),
    ExpenseCategory.travel: Color(0xFF3556A0),
    ExpenseCategory.rent: Color(0xFF7E57A8),
    ExpenseCategory.utilities: Color(0xFF0E7C86),
    ExpenseCategory.groceries: Color(0xFF46974A),
    ExpenseCategory.entertainment: Color(0xFFB33C8A),
    ExpenseCategory.shopping: Color(0xFFA86E1C),
    ExpenseCategory.other: Color(0xFF71717A),
  };

  /// Dark-theme segment + swatch colours (tokens.md section 1.3.2).
  static const Map<ExpenseCategory, Color> dark = {
    ExpenseCategory.food: Color(0xFFE8788A),
    ExpenseCategory.travel: Color(0xFF7B9CE0),
    ExpenseCategory.rent: Color(0xFFB79BE0),
    ExpenseCategory.utilities: Color(0xFF34B3BE),
    ExpenseCategory.groceries: Color(0xFF5CB85C),
    ExpenseCategory.entertainment: Color(0xFFD773B4),
    ExpenseCategory.shopping: Color(0xFFE0A73E),
    ExpenseCategory.other: Color(0xFFA1A1AA),
  };
}

/// Resolves the segment/swatch colour for [category] in [brightness],
/// selecting the dark map for [Brightness.dark] and the light map
/// otherwise. Falls back to the `other` colour for an unmapped category
/// (defensive — the map is exhaustive over the eight-value enum).
Color spendingCategoryColor(ExpenseCategory category, Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? SpendingCategoryPalette.dark
      : SpendingCategoryPalette.light;
  return palette[category] ?? palette[ExpenseCategory.other]!;
}
