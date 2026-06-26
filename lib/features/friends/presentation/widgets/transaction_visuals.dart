import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';

/// Maps a domain [ExpenseCategory] to its Haldi-palette [OBTCategory] hue
/// key (foundation plan section 1.6).
///
/// The domain enum's `travel` maps to the palette's `transport`; every
/// other value maps by name. Mirrors the FR-HD-03 spending palette so the
/// Friends timeline (Haldi 11) and the Friend history (Haldi 12) reuse the
/// single 8-hue source of truth (`OBTColors.category`) rather than
/// hard-coding any category hex at the call site.
OBTCategory friendCategoryKey(ExpenseCategory category) {
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

/// The Haldi leading tile for a transaction row (Phase 3c Friends timeline
/// + history): a rounded-square holding a glyph on a ~12%-opacity bed of
/// [hue], with the glyph itself in the full [hue].
///
/// Purely decorative — the row owns the textual label; the tile is
/// [ExcludeSemantics] so a screen reader announces the transaction once.
class TransactionIconTile extends StatelessWidget {
  /// Creates a [TransactionIconTile].
  const TransactionIconTile({
    required this.icon,
    required this.hue,
    this.size = 40,
    super.key,
  });

  /// The category / settlement glyph.
  final IconData icon;

  /// The full-strength hue; the bed renders it at ~12% opacity.
  final Color hue;

  /// The square edge length in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Icon(icon, size: size * 0.5, color: hue),
      ),
    );
  }
}
