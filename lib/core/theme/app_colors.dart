import 'package:flutter/material.dart';

/// Custom color extensions for the OneByTwo app.
///
/// Provides semantic colors for money-related UI (owe/owed/settled),
/// sync status indicators, and expense category colors.
///
/// Register this extension on [ThemeData] via `ThemeData.extensions` and
/// access it in widgets with `context.appColors`.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  /// Creates an [AppColorsExtension] with the given semantic colors.
  const AppColorsExtension({
    required this.oweColor,
    required this.oweColorLight,
    required this.owedColor,
    required this.owedColorLight,
    required this.settledColor,
    required this.settledColorLight,
    required this.syncPendingColor,
    required this.syncErrorColor,
    required this.syncSuccessColor,
    required this.categoryColors,
  });

  /// Color for amounts the user **owes** (red shade).
  ///
  /// Used for negative balances and amounts owed to others.
  final Color oweColor;

  /// Light background tint for owe amounts.
  ///
  /// Used as a container/chip background behind [oweColor] text.
  final Color oweColorLight;

  /// Color for amounts the user **is owed** (green shade).
  ///
  /// Used for positive balances and amounts owed to the user.
  final Color owedColor;

  /// Light background tint for owed amounts.
  ///
  /// Used as a container/chip background behind [owedColor] text.
  final Color owedColorLight;

  /// Color for settled / zero balances (neutral gray).
  final Color settledColor;

  /// Light background tint for settled amounts.
  final Color settledColorLight;

  /// Sync status color indicating a pending write (amber).
  final Color syncPendingColor;

  /// Sync status color indicating an error (red).
  final Color syncErrorColor;

  /// Sync status color indicating a successful sync (green).
  final Color syncSuccessColor;

  /// 10 predefined category colors for expense categories.
  ///
  /// Used to visually distinguish expense categories in lists,
  /// chips, and category pickers.
  final List<Color> categoryColors;

  /// Light-mode color values.
  static const light = AppColorsExtension(
    oweColor: Color(0xFFD32F2F),
    oweColorLight: Color(0xFFFFEBEE),
    owedColor: Color(0xFF2E7D32),
    owedColorLight: Color(0xFFE8F5E9),
    settledColor: Color(0xFF757575),
    settledColorLight: Color(0xFFF5F5F5),
    syncPendingColor: Color(0xFFF9A825),
    syncErrorColor: Color(0xFFD32F2F),
    syncSuccessColor: Color(0xFF2E7D32),
    categoryColors: [
      Color(0xFF00897B), // Teal 600
      Color(0xFF5C6BC0), // Indigo 400
      Color(0xFFFF7043), // Deep Orange 400
      Color(0xFF42A5F5), // Blue 400
      Color(0xFFAB47BC), // Purple 400
      Color(0xFFFFCA28), // Amber 400
      Color(0xFF66BB6A), // Green 400
      Color(0xFFEF5350), // Red 400
      Color(0xFF8D6E63), // Brown 400
      Color(0xFF78909C), // Blue Grey 400
    ],
  );

  /// Dark-mode color values.
  ///
  /// Uses lighter shades for readability against dark backgrounds.
  static const dark = AppColorsExtension(
    oweColor: Color(0xFFEF9A9A),
    oweColorLight: Color(0xFF4E1A1A),
    owedColor: Color(0xFFA5D6A7),
    owedColorLight: Color(0xFF1B3A1B),
    settledColor: Color(0xFFBDBDBD),
    settledColorLight: Color(0xFF424242),
    syncPendingColor: Color(0xFFFFD54F),
    syncErrorColor: Color(0xFFEF9A9A),
    syncSuccessColor: Color(0xFFA5D6A7),
    categoryColors: [
      Color(0xFF4DB6AC), // Teal 300
      Color(0xFF9FA8DA), // Indigo 200
      Color(0xFFFFAB91), // Deep Orange 200
      Color(0xFF90CAF9), // Blue 200
      Color(0xFFCE93D8), // Purple 200
      Color(0xFFFFE082), // Amber 200
      Color(0xFFA5D6A7), // Green 200
      Color(0xFFEF9A9A), // Red 200
      Color(0xFFBCAAA4), // Brown 200
      Color(0xFFB0BEC5), // Blue Grey 200
    ],
  );

  @override
  AppColorsExtension copyWith({
    Color? oweColor,
    Color? oweColorLight,
    Color? owedColor,
    Color? owedColorLight,
    Color? settledColor,
    Color? settledColorLight,
    Color? syncPendingColor,
    Color? syncErrorColor,
    Color? syncSuccessColor,
    List<Color>? categoryColors,
  }) {
    return AppColorsExtension(
      oweColor: oweColor ?? this.oweColor,
      oweColorLight: oweColorLight ?? this.oweColorLight,
      owedColor: owedColor ?? this.owedColor,
      owedColorLight: owedColorLight ?? this.owedColorLight,
      settledColor: settledColor ?? this.settledColor,
      settledColorLight: settledColorLight ?? this.settledColorLight,
      syncPendingColor: syncPendingColor ?? this.syncPendingColor,
      syncErrorColor: syncErrorColor ?? this.syncErrorColor,
      syncSuccessColor: syncSuccessColor ?? this.syncSuccessColor,
      categoryColors: categoryColors ?? this.categoryColors,
    );
  }

  @override
  AppColorsExtension lerp(covariant AppColorsExtension? other, double t) {
    if (other == null) return this;
    return AppColorsExtension(
      oweColor: Color.lerp(oweColor, other.oweColor, t)!,
      oweColorLight: Color.lerp(oweColorLight, other.oweColorLight, t)!,
      owedColor: Color.lerp(owedColor, other.owedColor, t)!,
      owedColorLight: Color.lerp(owedColorLight, other.owedColorLight, t)!,
      settledColor: Color.lerp(settledColor, other.settledColor, t)!,
      settledColorLight: Color.lerp(
        settledColorLight,
        other.settledColorLight,
        t,
      )!,
      syncPendingColor: Color.lerp(
        syncPendingColor,
        other.syncPendingColor,
        t,
      )!,
      syncErrorColor: Color.lerp(syncErrorColor, other.syncErrorColor, t)!,
      syncSuccessColor: Color.lerp(
        syncSuccessColor,
        other.syncSuccessColor,
        t,
      )!,
      categoryColors: _lerpColorList(categoryColors, other.categoryColors, t),
    );
  }

  /// Linearly interpolates two [Color] lists element-wise.
  static List<Color> _lerpColorList(List<Color> a, List<Color> b, double t) {
    final length = a.length < b.length ? a.length : b.length;
    return [for (int i = 0; i < length; i++) Color.lerp(a[i], b[i], t)!];
  }
}

/// Convenience extension on [BuildContext] for accessing [AppColorsExtension].
///
/// Usage:
/// ```dart
/// final oweColor = context.appColors.oweColor;
/// ```
extension AppColorsX on BuildContext {
  /// The [AppColorsExtension] from the nearest [Theme].
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
