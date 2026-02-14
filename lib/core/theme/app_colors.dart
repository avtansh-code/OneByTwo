import 'package:flutter/material.dart';

/// Custom color extension for the app theme.
/// 
/// Provides semantic colors for financial states and sync states
/// that are not part of the standard Material color scheme.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.oweColor,
    required this.oweColorLight,
    required this.owedColor,
    required this.owedColorLight,
    required this.settledColor,
    required this.settledColorLight,
    required this.syncPendingColor,
    required this.syncPendingColorLight,
    required this.syncErrorColor,
    required this.syncErrorColorLight,
    required this.categoryColors,
  });

  /// Light theme colors
  factory AppColorsExtension.light() {
    return const AppColorsExtension(
      oweColor: Color(0xFFD32F2F), // Red 700
      oweColorLight: Color(0xFFFFCDD2), // Red 100
      owedColor: Color(0xFF388E3C), // Green 700
      owedColorLight: Color(0xFFC8E6C9), // Green 100
      settledColor: Color(0xFF616161), // Grey 700
      settledColorLight: Color(0xFFE0E0E0), // Grey 300
      syncPendingColor: Color(0xFFFFA000), // Amber 700
      syncPendingColorLight: Color(0xFFFFE082), // Amber 200
      syncErrorColor: Color(0xFFD32F2F), // Red 700
      syncErrorColorLight: Color(0xFFFFCDD2), // Red 100
      categoryColors: [
        Color(0xFFE53935), // Red 600 - Food
        Color(0xFF1E88E5), // Blue 600 - Transport
        Color(0xFFFB8C00), // Orange 600 - Entertainment
        Color(0xFF43A047), // Green 600 - Shopping
        Color(0xFF8E24AA), // Purple 600 - Bills
        Color(0xFF00ACC1), // Cyan 600 - Travel
        Color(0xFFFDD835), // Yellow 600 - Health
        Color(0xFF6D4C41), // Brown 600 - Other
      ],
    );
  }

  /// Dark theme colors
  factory AppColorsExtension.dark() {
    return const AppColorsExtension(
      oweColor: Color(0xFFEF5350), // Red 400
      oweColorLight: Color(0xFF5D1F1F), // Dark Red background
      owedColor: Color(0xFF66BB6A), // Green 400
      owedColorLight: Color(0xFF1B3A1C), // Dark Green background
      settledColor: Color(0xFF9E9E9E), // Grey 500
      settledColorLight: Color(0xFF424242), // Grey 800
      syncPendingColor: Color(0xFFFFCA28), // Amber 400
      syncPendingColorLight: Color(0xFF4D3D00), // Dark Amber background
      syncErrorColor: Color(0xFFEF5350), // Red 400
      syncErrorColorLight: Color(0xFF5D1F1F), // Dark Red background
      categoryColors: [
        Color(0xFFE57373), // Red 300 - Food
        Color(0xFF64B5F6), // Blue 300 - Transport
        Color(0xFFFFB74D), // Orange 300 - Entertainment
        Color(0xFF81C784), // Green 300 - Shopping
        Color(0xFFBA68C8), // Purple 300 - Bills
        Color(0xFF4DD0E1), // Cyan 300 - Travel
        Color(0xFFFFF176), // Yellow 300 - Health
        Color(0xFFA1887F), // Brown 300 - Other
      ],
    );
  }

  /// Color for amounts the user owes (red shades)
  final Color oweColor;

  /// Light variant of owe color (for backgrounds)
  final Color oweColorLight;

  /// Color for amounts the user is owed (green shades)
  final Color owedColor;

  /// Light variant of owed color (for backgrounds)
  final Color owedColorLight;

  /// Color for settled/zero balances (neutral)
  final Color settledColor;

  /// Light variant of settled color (for backgrounds)
  final Color settledColorLight;

  /// Color for pending sync state (amber)
  final Color syncPendingColor;

  /// Light variant of pending sync color (for backgrounds)
  final Color syncPendingColorLight;

  /// Color for sync error state (red)
  final Color syncErrorColor;

  /// Light variant of sync error color (for backgrounds)
  final Color syncErrorColorLight;

  /// Colors for expense categories
  final List<Color> categoryColors;

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? oweColor,
    Color? oweColorLight,
    Color? owedColor,
    Color? owedColorLight,
    Color? settledColor,
    Color? settledColorLight,
    Color? syncPendingColor,
    Color? syncPendingColorLight,
    Color? syncErrorColor,
    Color? syncErrorColorLight,
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
      syncPendingColorLight: syncPendingColorLight ?? this.syncPendingColorLight,
      syncErrorColor: syncErrorColor ?? this.syncErrorColor,
      syncErrorColorLight: syncErrorColorLight ?? this.syncErrorColorLight,
      categoryColors: categoryColors ?? this.categoryColors,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) {
      return this;
    }

    return AppColorsExtension(
      oweColor: Color.lerp(oweColor, other.oweColor, t)!,
      oweColorLight: Color.lerp(oweColorLight, other.oweColorLight, t)!,
      owedColor: Color.lerp(owedColor, other.owedColor, t)!,
      owedColorLight: Color.lerp(owedColorLight, other.owedColorLight, t)!,
      settledColor: Color.lerp(settledColor, other.settledColor, t)!,
      settledColorLight: Color.lerp(settledColorLight, other.settledColorLight, t)!,
      syncPendingColor: Color.lerp(syncPendingColor, other.syncPendingColor, t)!,
      syncPendingColorLight: Color.lerp(syncPendingColorLight, other.syncPendingColorLight, t)!,
      syncErrorColor: Color.lerp(syncErrorColor, other.syncErrorColor, t)!,
      syncErrorColorLight: Color.lerp(syncErrorColorLight, other.syncErrorColorLight, t)!,
      categoryColors: List.generate(
        categoryColors.length,
        (index) => Color.lerp(
          categoryColors[index],
          other.categoryColors.length > index ? other.categoryColors[index] : categoryColors[index],
          t,
        )!,
      ),
    );
  }
}

/// Extension to easily access custom colors from BuildContext
extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors {
    return Theme.of(this).extension<AppColorsExtension>()!;
  }
}
