import 'package:flutter/material.dart';

/// Expense categories that drive the Haldi 8-hue, colour-blind-safe
/// category palette (foundation plan section 1.6).
enum OBTCategory {
  /// Food and drink.
  food,

  /// Transport.
  transport,

  /// Groceries.
  groceries,

  /// Entertainment.
  entertainment,

  /// Rent and housing.
  rent,

  /// Utilities.
  utilities,

  /// Shopping.
  shopping,

  /// Anything that does not fit another category.
  other,
}

/// Haldi design tokens that have no Material [ColorScheme] slot.
///
/// Registered on both [ThemeData.extensions] and read via
/// `Theme.of(context).extension<OBTColors>()`. Every hex value is fixed by
/// `docs/audits/design-conversion/03-foundation-plan.md` (sections 1.4 to
/// 1.6 for colour, section 2.2 for the soft-warm shadow model).
@immutable
class OBTColors extends ThemeExtension<OBTColors> {
  /// Creates an [OBTColors] token set.
  const OBTColors({
    required this.balanceZero,
    required this.balancePositive,
    required this.balanceNegative,
    required this.warning,
    required this.primaryPressed,
    required this.textTertiary,
    required this.link,
    required this.disabledFill,
    required this.disabledText,
    required this.category,
    required this.rowShadow,
    required this.heroShadow,
  });

  /// Neutral "settled up" balance signal.
  final Color balanceZero;

  /// Positive balance signal ("you are owed"); mirrors
  /// [ColorScheme.tertiary] for use by the balance pill (section 1.5).
  final Color balancePositive;

  /// Negative balance signal ("you owe"); mirrors [ColorScheme.error].
  final Color balanceNegative;

  /// Cautions and cooldowns.
  final Color warning;

  /// Pressed-state marigold overlay for primary affordances.
  final Color primaryPressed;

  /// Meta and timestamp text.
  final Color textTertiary;

  /// Text links on tonal surfaces.
  final Color link;

  /// Disabled control fill.
  final Color disabledFill;

  /// Disabled control text.
  final Color disabledText;

  /// Full-strength category hues keyed by [OBTCategory]. Chip and tile
  /// backgrounds use the hue at ~10% opacity; the icon uses the full hue.
  final Map<OBTCategory, Color> category;

  /// Soft warm shadow for rows and list tiles. Empty in dark, where a 1px
  /// [ColorScheme.outline] border is used instead of a shadow.
  final List<BoxShadow> rowShadow;

  /// Soft warm shadow for hero and elevated cards and the FAB.
  final List<BoxShadow> heroShadow;

  /// Returns the full-strength hue for [c], falling back to
  /// [OBTCategory.other] if the key is absent.
  Color categoryColor(OBTCategory c) =>
      category[c] ?? category[OBTCategory.other]!;

  /// Light-theme token set.
  static const OBTColors light = OBTColors(
    balanceZero: Color(0xFF6F6557),
    balancePositive: Color(0xFF0F7D6B),
    balanceNegative: Color(0xFFBC4030),
    warning: Color(0xFFE8A33D),
    primaryPressed: Color(0xFFC77F22),
    textTertiary: Color(0xFF9A8F82),
    link: Color(0xFFA35E16),
    disabledFill: Color(0xFFE4DCCE),
    disabledText: Color(0xFFB8AC9B),
    category: <OBTCategory, Color>{
      OBTCategory.food: Color(0xFFE8762B),
      OBTCategory.transport: Color(0xFF2E78C9),
      OBTCategory.groceries: Color(0xFF4FA13E),
      OBTCategory.entertainment: Color(0xFFB5489B),
      OBTCategory.rent: Color(0xFF6C4FC9),
      OBTCategory.utilities: Color(0xFF1FA39A),
      OBTCategory.shopping: Color(0xFFD94F87),
      OBTCategory.other: Color(0xFF8A7B6B),
    },
    rowShadow: <BoxShadow>[
      BoxShadow(color: Color(0x0D2A211B), blurRadius: 3, offset: Offset(0, 1)),
    ],
    heroShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x4DE0922E),
        blurRadius: 30,
        spreadRadius: -12,
        offset: Offset(0, 12),
      ),
    ],
  );

  /// Dark-theme token set.
  static const OBTColors dark = OBTColors(
    balanceZero: Color(0xFFA99C8C),
    balancePositive: Color(0xFF34C0A4),
    balanceNegative: Color(0xFFF2856B),
    warning: Color(0xFFF2B863),
    primaryPressed: Color(0xFFD08F3C),
    textTertiary: Color(0xFF8A7E6E),
    link: Color(0xFFEAA24A),
    disabledFill: Color(0xFF332B23),
    disabledText: Color(0xFF6B6053),
    category: <OBTCategory, Color>{
      OBTCategory.food: Color(0xFFF59A52),
      OBTCategory.transport: Color(0xFF5B9BE8),
      OBTCategory.groceries: Color(0xFF73C463),
      OBTCategory.entertainment: Color(0xFFD470BC),
      OBTCategory.rent: Color(0xFF9079E6),
      OBTCategory.utilities: Color(0xFF3EC9BF),
      OBTCategory.shopping: Color(0xFFF074A6),
      OBTCategory.other: Color(0xFFA99986),
    },
    rowShadow: <BoxShadow>[],
    heroShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x99000000),
        blurRadius: 22,
        spreadRadius: -10,
        offset: Offset(0, 8),
      ),
    ],
  );

  @override
  OBTColors copyWith({
    Color? balanceZero,
    Color? balancePositive,
    Color? balanceNegative,
    Color? warning,
    Color? primaryPressed,
    Color? textTertiary,
    Color? link,
    Color? disabledFill,
    Color? disabledText,
    Map<OBTCategory, Color>? category,
    List<BoxShadow>? rowShadow,
    List<BoxShadow>? heroShadow,
  }) {
    return OBTColors(
      balanceZero: balanceZero ?? this.balanceZero,
      balancePositive: balancePositive ?? this.balancePositive,
      balanceNegative: balanceNegative ?? this.balanceNegative,
      warning: warning ?? this.warning,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      textTertiary: textTertiary ?? this.textTertiary,
      link: link ?? this.link,
      disabledFill: disabledFill ?? this.disabledFill,
      disabledText: disabledText ?? this.disabledText,
      category: category ?? this.category,
      rowShadow: rowShadow ?? this.rowShadow,
      heroShadow: heroShadow ?? this.heroShadow,
    );
  }

  @override
  OBTColors lerp(covariant ThemeExtension<OBTColors>? other, double t) {
    if (other is! OBTColors) {
      return this;
    }
    return OBTColors(
      balanceZero: Color.lerp(balanceZero, other.balanceZero, t)!,
      balancePositive: Color.lerp(balancePositive, other.balancePositive, t)!,
      balanceNegative: Color.lerp(balanceNegative, other.balanceNegative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      link: Color.lerp(link, other.link, t)!,
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      category: _lerpCategory(category, other.category, t),
      rowShadow: BoxShadow.lerpList(rowShadow, other.rowShadow, t) ?? rowShadow,
      heroShadow:
          BoxShadow.lerpList(heroShadow, other.heroShadow, t) ?? heroShadow,
    );
  }

  static Map<OBTCategory, Color> _lerpCategory(
    Map<OBTCategory, Color> a,
    Map<OBTCategory, Color> b,
    double t,
  ) {
    return <OBTCategory, Color>{
      for (final c in OBTCategory.values) c: Color.lerp(a[c], b[c], t) ?? a[c]!,
    };
  }
}
