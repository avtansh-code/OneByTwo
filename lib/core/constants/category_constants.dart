import 'package:flutter/material.dart';

/// Categories for classifying individual expenses.
///
/// Each category has an associated [icon] for display and a [fallbackLabel]
/// for non-localized contexts. The presentation layer should use [key] to
/// look up localized strings via `AppLocalizations`.
///
/// Example l10n mapping in a widget:
/// ```dart
/// String localizedLabel(AppLocalizations l10n, ExpenseCategory category) =>
///     switch (category) {
///       ExpenseCategory.food => l10n.categoryFood,
///       // ...
///     };
/// ```
enum ExpenseCategory {
  /// Food & Dining — restaurants, cafes, takeout.
  food(Icons.restaurant, 'Food & Dining'),

  /// Transport — fuel, cab rides, public transit.
  transport(Icons.directions_car, 'Transport'),

  /// Groceries — supermarket, kirana store purchases.
  groceries(Icons.shopping_cart, 'Groceries'),

  /// Rent & Housing — rent, maintenance, repairs.
  rent(Icons.home, 'Rent & Housing'),

  /// Entertainment — movies, streaming, events.
  entertainment(Icons.movie, 'Entertainment'),

  /// Utilities — electricity, water, internet, gas.
  utilities(Icons.bolt, 'Utilities'),

  /// Shopping — clothing, electronics, miscellaneous retail.
  shopping(Icons.shopping_bag, 'Shopping'),

  /// Health — hospital, pharmacy, gym.
  health(Icons.local_hospital, 'Health'),

  /// Travel — flights, hotels, holiday expenses.
  travel(Icons.flight, 'Travel'),

  /// Other — uncategorised expenses.
  other(Icons.category, 'Other');

  /// Creates an [ExpenseCategory] with the given [icon] and [fallbackLabel].
  const ExpenseCategory(this.icon, this.fallbackLabel);

  /// The Material Design icon representing this category.
  final IconData icon;

  /// English fallback label for non-localized contexts (e.g., logging).
  ///
  /// Prefer using [key] with localized strings in the presentation layer.
  final String fallbackLabel;

  /// Stable string key for l10n lookup, derived from the enum [name].
  ///
  /// Use this to map to localized strings in the presentation layer.
  String get key => name;
}

/// Categories for classifying groups.
///
/// Each category has an associated [icon] and a [fallbackLabel] for
/// non-localized contexts. The presentation layer should use [key] to
/// look up localized strings via `AppLocalizations`.
///
/// Example l10n mapping in a widget:
/// ```dart
/// String localizedLabel(AppLocalizations l10n, GroupCategory category) =>
///     switch (category) {
///       GroupCategory.trip => l10n.groupCategoryTrip,
///       // ...
///     };
/// ```
enum GroupCategory {
  /// Trip — travel and holiday groups.
  trip(Icons.flight, 'Trip'),

  /// Home — flatmates, household shared expenses.
  home(Icons.home, 'Home'),

  /// Couple — expenses shared between partners.
  couple(Icons.favorite, 'Couple'),

  /// Event — parties, outings, one-time events.
  event(Icons.event, 'Event'),

  /// Other — miscellaneous group types.
  other(Icons.group, 'Other');

  /// Creates a [GroupCategory] with the given [icon] and [fallbackLabel].
  const GroupCategory(this.icon, this.fallbackLabel);

  /// The Material Design icon representing this group category.
  final IconData icon;

  /// English fallback label for non-localized contexts (e.g., logging).
  ///
  /// Prefer using [key] with localized strings in the presentation layer.
  final String fallbackLabel;

  /// Stable string key for l10n lookup, derived from the enum [name].
  ///
  /// Use this to map to localized strings in the presentation layer.
  String get key => name;
}

/// Types of expense splits supported by the app.
///
/// Determines how an expense's total amount is divided among participants.
/// The presentation layer should use [key] to look up localized display
/// names via `AppLocalizations`.
enum SplitType {
  /// Equal split — the total is divided equally among all participants
  /// using the Largest Remainder Method to avoid rounding errors.
  equal('Equal'),

  /// Exact amounts — each participant's share is specified as an exact
  /// amount in paise.
  exact('Exact Amounts'),

  /// Percentage — each participant's share is specified as a percentage
  /// of the total amount.
  percentage('Percentage'),

  /// Shares — each participant is assigned a number of shares, and the
  /// total is divided proportionally.
  shares('Shares'),

  /// Itemized — the expense is broken down into individual items,
  /// each assigned to specific participants.
  itemized('Itemized');

  /// Creates a [SplitType] with the given [fallbackLabel].
  const SplitType(this.fallbackLabel);

  /// English fallback label for non-localized contexts (e.g., logging).
  ///
  /// Prefer using [key] with localized strings in the presentation layer.
  final String fallbackLabel;

  /// Stable string key for l10n lookup, derived from the enum [name].
  ///
  /// Use this to map to localized strings in the presentation layer.
  String get key => name;
}
