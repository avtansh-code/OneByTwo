import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from docs/design/02-design-system/tokens.md.
///
/// Exposes [light] and [dark] [ThemeData] built from semantic colour,
/// typography, spacing, and radius tokens defined in the design system.
class AppTheme {
  AppTheme._();

  // ── Light colour tokens ──────────────────────────────────────────────

  static const _lightPrimary = Color(0xFF1F4E79);
  static const _lightPrimaryVariant = Color(0xFF2E86AB);
  static const _lightSecondary = Color(0xFFF4A261);
  static const _lightSuccess = Color(0xFF2A9D8F);
  static const _lightDanger = Color(0xFFE76F51);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceVariant = Color(0xFFF2F4F7);
  static const _lightBackground = Color(0xFFF8F9FB);
  static const _lightOnPrimary = Color(0xFFFFFFFF);
  static const _lightOnSecondary = Color(0xFF1A1A1A);
  static const _lightOnSurface = Color(0xFF1A1A1A);
  static const _lightOutline = Color(0xFFC4C9D1);
  static const _lightDivider = Color(0xFFE4E7EC);

  // ── Dark colour tokens ───────────────────────────────────────────────

  static const _darkPrimary = Color(0xFF2E86AB);
  static const _darkPrimaryVariant = Color(0xFF5AAFCE);
  static const _darkSecondary = Color(0xFFF4A261);
  static const _darkSuccess = Color(0xFF3CC0AF);
  static const _darkDanger = Color(0xFFF08B72);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _darkSurfaceVariant = Color(0xFF2A2A2A);
  static const _darkBackground = Color(0xFF121212);
  static const _darkOnPrimary = Color(0xFFFFFFFF);
  static const _darkOnSecondary = Color(0xFF1A1A1A);
  static const _darkOnSurface = Color(0xFFE8E8E8);
  static const _darkOutline = Color(0xFF3D3D3D);
  static const _darkDivider = Color(0xFF2F2F2F);

  // ── Corner radii (tokens.md section 4) ───────────────────────────────

  /// Cards, list tiles, snackbars.
  static const radiusLarge = 16.0;

  /// Bottom sheets, modal dialogs.
  static const radiusXL = 24.0;

  /// Buttons, smaller dialogs.
  static const radiusMedium = 12.0;

  // ── Typography ───────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base) {
    final headingFamily = GoogleFonts.plusJakartaSans().fontFamily;
    final bodyFamily = GoogleFonts.inter().fontFamily;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 40 / 34,
        letterSpacing: -0.25,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 34 / 28,
        letterSpacing: -0.15,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 30 / 24,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 26 / 20,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 24 / 18,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 22 / 16,
        letterSpacing: 0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.1,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 24 / 16,
        letterSpacing: 0.15,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.15,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.2,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.5,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 10,
        height: 12 / 10,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Theme builders ───────────────────────────────────────────────────

  /// Light [ThemeData] built from design tokens.
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: _lightOnPrimary,
      secondary: _lightSecondary,
      onSecondary: _lightOnSecondary,
      error: _lightDanger,
      onError: Colors.white,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      surfaceContainerHighest: _lightSurfaceVariant,
      outline: _lightOutline,
      tertiary: _lightSuccess,
      primaryContainer: _lightPrimaryVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBackground,
      dividerColor: _lightDivider,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
        ),
      ),
    );
  }

  /// Dark [ThemeData] built from design tokens.
  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      secondary: _darkSecondary,
      onSecondary: _darkOnSecondary,
      error: _darkDanger,
      onError: Colors.white,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      surfaceContainerHighest: _darkSurfaceVariant,
      outline: _darkOutline,
      tertiary: _darkSuccess,
      primaryContainer: _darkPrimaryVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,
      dividerColor: _darkDivider,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
        ),
      ),
    );
  }
}
