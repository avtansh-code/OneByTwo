import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';

/// Design tokens for the "Direction A — Haldi" visual system
/// (`design_handoff_one_by_two/`, ADR-0024).
///
/// Exposes [light] and [dark] [ThemeData] built from the Haldi semantic
/// colour set, the Bricolage Grotesque + Hanken Grotesk type ramp, and the
/// shared radius, shadow and motion tokens. The non-Material tokens (the
/// balance trio, category hues, shadows, etc.) are carried by the
/// [OBTColors] theme extension registered on both themes. The
/// constant-by-constant migration map is
/// `docs/audits/design-conversion/03-foundation-plan.md` sections 1 to 3.
class AppTheme {
  AppTheme._();

  // ── Light colour tokens (Haldi) ──────────────────────────────────────

  static const _lightPrimary = Color(0xFFE0922E);
  static const _lightPrimaryPressed = Color(0xFFC77F22);
  static const _lightSecondary = Color(0xFFC75D3C);
  static const _lightSuccess = Color(0xFF0F7D6B);
  static const _lightDanger = Color(0xFFBC4030);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceVariant = Color(0xFFFFF6E6);
  static const _lightBackground = Color(0xFFFBF6EE);
  static const _lightOnPrimary = Color(0xFF2A211B);
  static const _lightOnSecondary = Color(0xFFFFF7E8);
  static const _lightOnSuccess = Color(0xFFFFFFFF);
  static const _lightOnDanger = Color(0xFFFFFFFF);
  static const _lightOnSurface = Color(0xFF2A211B);
  static const _lightOnSurfaceVariant = Color(0xFF6F6557);
  static const _lightOutline = Color(0xFFE7DDCD);
  static const _lightDivider = Color(0xFFE7DDCD);

  // ── Dark colour tokens (Haldi) ───────────────────────────────────────

  static const _darkPrimary = Color(0xFFEAA24A);
  static const _darkPrimaryPressed = Color(0xFFD08F3C);
  static const _darkSecondary = Color(0xFFE07A55);
  static const _darkSuccess = Color(0xFF34C0A4);
  static const _darkDanger = Color(0xFFF2856B);
  static const _darkSurface = Color(0xFF241D16);
  static const _darkSurfaceVariant = Color(0xFF2E2620);
  static const _darkBackground = Color(0xFF1A1510);
  static const _darkOnPrimary = Color(0xFF1A1510);
  static const _darkOnSecondary = Color(0xFF1A1510);
  static const _darkOnSuccess = Color(0xFF1A1510);
  static const _darkOnDanger = Color(0xFF1A1510);
  static const _darkOnSurface = Color(0xFFF3EBDD);
  static const _darkOnSurfaceVariant = Color(0xFFB9AE9D);
  static const _darkOutline = Color(0xFF3A322A);
  static const _darkDivider = Color(0xFF3A322A);

  // ── Corner radii (foundation plan section 2.1) ───────────────────────

  /// Chips and text inputs (12–14).
  static const radiusChipInput = 12.0;

  /// Buttons (14–16).
  static const radiusButton = 16.0;

  /// Cards, list tiles and the hero card (16–22).
  static const radiusCard = 20.0;

  /// FAB and pill controls (18–19).
  static const radiusPill = 18.0;

  /// Bottom-sheet top corners (26–28).
  static const radiusSheet = 28.0;

  /// Fully-rounded pills, avatars and the balance pill.
  static const radiusFull = 999.0;

  /// Legacy radius — cards, list tiles, snackbars. Retained for screens not
  /// yet converted; new code uses [radiusCard] / [radiusButton].
  static const radiusLarge = 16.0;

  /// Legacy radius — bottom sheets, modal dialogs. New code uses
  /// [radiusSheet].
  static const radiusXL = 24.0;

  /// Legacy radius — buttons, smaller dialogs. New code uses
  /// [radiusChipInput].
  static const radiusMedium = 12.0;

  // ── Motion (foundation plan section 2.3) ─────────────────────────────

  /// Short transition (taps, toggles).
  static const motionDurationShort = Duration(milliseconds: 200);

  /// Default page / sheet transition.
  static const motionDurationMedium = Duration(milliseconds: 280);

  /// Default easing curve.
  static const motionCurve = Curves.easeInOut;

  // ── Typography (Bricolage Grotesque + Hanken Grotesk) ────────────────

  static TextTheme _buildTextTheme(TextTheme base) {
    final headingFamily = GoogleFonts.bricolageGrotesque().fontFamily;
    final bodyFamily = GoogleFonts.hankenGrotesk().fontFamily;
    const tabular = <FontFeature>[FontFeature.tabularFigures()];

    return base.copyWith(
      // Amount-hero (tabular figures).
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 48,
        height: 48 / 48,
        letterSpacing: -0.48,
        fontFeatures: tabular,
      ),
      // H1 large title.
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 38 / 32,
        letterSpacing: -0.32,
      ),
      // H2 screen / sheet title.
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 30 / 24,
        letterSpacing: -0.24,
      ),
      // H3 section.
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w600,
        fontSize: 19,
        height: 26 / 19,
      ),
      // Title / row name.
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 22 / 16,
      ),
      // Title / row name (small).
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        height: 20 / 14,
      ),
      // Amount-row (Bricolage tabular figures).
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 20 / 16,
        fontFeatures: tabular,
      ),
      // Body.
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 22 / 15,
      ),
      // Body (small).
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 18 / 13,
      ),
      // Caption / meta.
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.12,
      ),
      // Button.
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 20 / 16,
        letterSpacing: 0.16,
      ),
      // Overline / kicker (UPPERCASE applied at the call site).
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: 1.32,
      ),
      // Smallest UI.
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: bodyFamily,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Theme builders ───────────────────────────────────────────────────

  /// Light [ThemeData] built from the Haldi tokens.
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: _lightOnPrimary,
      primaryContainer: _lightPrimaryPressed,
      secondary: _lightSecondary,
      onSecondary: _lightOnSecondary,
      tertiary: _lightSuccess,
      onTertiary: _lightOnSuccess,
      error: _lightDanger,
      onError: _lightOnDanger,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      surfaceContainerHighest: _lightSurfaceVariant,
      onSurfaceVariant: _lightOnSurfaceVariant,
      outline: _lightOutline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBackground,
      dividerColor: _lightDivider,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      cardTheme: const CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusCard)),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[OBTColors.light],
    );
  }

  /// Dark [ThemeData] built from the Haldi tokens.
  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      primaryContainer: _darkPrimaryPressed,
      secondary: _darkSecondary,
      onSecondary: _darkOnSecondary,
      tertiary: _darkSuccess,
      onTertiary: _darkOnSuccess,
      error: _darkDanger,
      onError: _darkOnDanger,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      surfaceContainerHighest: _darkSurfaceVariant,
      onSurfaceVariant: _darkOnSurfaceVariant,
      outline: _darkOutline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,
      dividerColor: _darkDivider,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      cardTheme: const CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusCard)),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[OBTColors.dark],
    );
  }
}
