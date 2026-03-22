import 'package:flutter/material.dart';

/// Typography styles for the OneByTwo app.
///
/// Amount displays use [FontFeature.tabularFigures] so that digits have
/// uniform width and columns of numbers align correctly.
///
/// All methods accept a [BuildContext] to resolve the current [TextTheme]
/// color from the active theme.
abstract final class AppTypography {
  // ---------------------------------------------------------------------------
  // Amount styles — use tabular figures for column alignment
  // ---------------------------------------------------------------------------

  /// Large amount display (32 px, bold, tabular figures).
  ///
  /// Intended for hero-style balance summaries at the top of screens.
  static TextStyle amountLarge(BuildContext context) {
    return TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Medium amount display (20 px, semi-bold, tabular figures).
  ///
  /// Used for line-item amounts in expense lists and cards.
  static TextStyle amountMedium(BuildContext context) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Small amount display (14 px, medium weight, tabular figures).
  ///
  /// Used for secondary amounts, split details, and inline totals.
  static TextStyle amountSmall(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  // ---------------------------------------------------------------------------
  // General UI styles
  // ---------------------------------------------------------------------------

  /// Section header (14 px, uppercase, wide letter-spacing).
  ///
  /// Used to label grouped list sections (e.g. "RECENT", "THIS MONTH").
  static TextStyle sectionHeader(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Card title (16 px, semi-bold).
  ///
  /// Used as the primary text inside [Card] widgets.
  static TextStyle cardTitle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Body text — default (16 px, regular weight).
  ///
  /// Standard body copy used throughout the app.
  static TextStyle bodyDefault(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Caption text (12 px, regular weight).
  ///
  /// Used for timestamps, helper text, and secondary metadata.
  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
