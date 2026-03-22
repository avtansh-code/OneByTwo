import 'package:flutter/material.dart';

/// Categories for classifying individual expenses.
///
/// Each category has an associated [icon] for display and a human-readable
/// [label]. These are used in expense creation and filtering.
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

  /// Creates an [ExpenseCategory] with the given [icon] and [label].
  const ExpenseCategory(this.icon, this.label);

  /// The Material Design icon representing this category.
  final IconData icon;

  /// The human-readable display label for this category.
  final String label;
}

/// Categories for classifying groups.
///
/// Each category has an associated [icon] and [label] for display in the
/// group creation and listing screens.
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

  /// Creates a [GroupCategory] with the given [icon] and [label].
  const GroupCategory(this.icon, this.label);

  /// The Material Design icon representing this group category.
  final IconData icon;

  /// The human-readable display label for this group category.
  final String label;
}

/// Types of expense splits supported by the app.
///
/// Determines how an expense's total amount is divided among participants.
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

  /// Creates a [SplitType] with the given [label].
  const SplitType(this.label);

  /// The human-readable display label for this split type.
  final String label;
}
