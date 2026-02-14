import 'package:flutter/material.dart';

/// Typography styles for the One By Two app.
/// 
/// Provides specialized text styles for amounts, headers, and body text.
class AppTypography {
  AppTypography._();

  /// Large amount display - for big amount displays (e.g., total balance)
  /// Example: ₹1,234.56
  static TextStyle amountLarge(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [
        FontFeature.tabularFigures(), // Use tabular (fixed-width) figures
      ],
    );
  }

  /// Medium amount display - for list item amounts
  /// Example: ₹123.45
  static TextStyle amountMedium(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontFeatures: const [
        FontFeature.tabularFigures(),
      ],
    );
  }

  /// Small amount display - for secondary amounts
  /// Example: ₹12.34
  static TextStyle amountSmall(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [
        FontFeature.tabularFigures(),
      ],
    );
  }

  /// Section header style
  /// Example: "Recent Expenses", "Members"
  static TextStyle sectionHeader(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Card title style
  /// Example: Card headers in lists
  static TextStyle cardTitle(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Card subtitle style
  /// Example: Secondary text in cards
  static TextStyle cardSubtitle(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Default body text style
  /// Example: Regular text content
  static TextStyle bodyDefault(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.5,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Small body text style
  /// Example: Helper text, footnotes
  static TextStyle bodySmall(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Button text style
  /// Example: Text in buttons
  static TextStyle buttonText(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: color ?? Theme.of(context).colorScheme.onPrimary,
    );
  }

  /// Label text style
  /// Example: Form labels, chip labels
  static TextStyle label(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Empty state title
  /// Example: "No expenses yet"
  static TextStyle emptyStateTitle(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Empty state subtitle
  /// Example: Explanatory text in empty states
  static TextStyle emptyStateSubtitle(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.4,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Error text style
  /// Example: Error messages
  static TextStyle errorText(BuildContext context, {Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.25,
      color: color ?? Theme.of(context).colorScheme.error,
    );
  }
}
