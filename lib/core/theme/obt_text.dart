import 'package:flutter/material.dart';

/// Shared text-style helpers for monetary amounts.
///
/// Amounts always render in Bricolage Grotesque with tabular figures so
/// digits stay column-aligned everywhere (foundation plan section 3.3).
/// These helpers restyle the *display* only: the value must still be
/// produced by `formatInrFromPaise()` (the sole paise-to-rupee boundary),
/// so they introduce no `paise / 100` arithmetic and never convert paise
/// to rupees themselves (Invariant 1).
class OBTText {
  OBTText._();

  static const List<FontFeature> _tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Bricolage tabular style for inline and row amounts (the `titleSmall`
  /// amount-row slot). Colour is inherited from the ambient text style.
  static TextStyle amount(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall ?? const TextStyle();
    return base.copyWith(fontFeatures: _tabularFigures);
  }

  /// Bricolage tabular style for the compact balance-pill amount — the
  /// one-line `[icon] [amount]` chip (Phase2 Components "Balance pills":
  /// Bricolage Grotesque 700, 13px, tabular figures). Sized down from the
  /// `titleSmall` amount-row slot with a 1.0 line height so the chip stays
  /// a single tight line; colour is set by the caller (the balance hue).
  static TextStyle amountPill(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall ?? const TextStyle();
    return base.copyWith(
      fontSize: 13,
      height: 1,
      fontFeatures: _tabularFigures,
    );
  }

  /// Bricolage tabular style for a focal amount that sits between a row
  /// amount and the hero figure — the settle-up card suggestion and similar
  /// mid-emphasis money (the `displayMedium` 32px amount-focal slot, issue
  /// #128 §B). Colour is inherited from the ambient text style.
  static TextStyle amountFocal(BuildContext context) {
    final base = Theme.of(context).textTheme.displayMedium ?? const TextStyle();
    return base.copyWith(fontFeatures: _tabularFigures);
  }

  /// Bricolage tabular style for the hero net-balance amount (the
  /// `displayLarge` amount-hero slot).
  static TextStyle amountHero(BuildContext context) {
    final base = Theme.of(context).textTheme.displayLarge ?? const TextStyle();
    return base.copyWith(fontFeatures: _tabularFigures);
  }
}
