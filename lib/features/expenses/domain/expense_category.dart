import 'package:flutter/material.dart';

/// The eight FR-EX-08 expense categories.
///
/// The Dart enum `.name` is the snake-case identifier that is
/// serialised to the Firestore `category` field (`'food'`, `'travel'`,
/// ...). The rules at `firestore.rules` line 198 only assert that the
/// value is a string; the client enum is the gate.
enum ExpenseCategory {
  /// Food and drink: restaurants, cafés, takeaways.
  food,

  /// Travel: flights, trains, taxis, fuel.
  travel,

  /// Rent and housing.
  rent,

  /// Utilities: electricity, water, internet.
  utilities,

  /// Groceries from supermarkets, kirana stores, and markets.
  groceries,

  /// Entertainment: cinema, events, subscriptions.
  entertainment,

  /// Shopping: clothes, accessories, household items.
  shopping,

  /// Any expense that does not fit the seven specific categories.
  other,
}

/// User-facing label per category. Driven by the SCR-19 chip catalogue
/// (`docs/design/06-screen-specs/19-22-expenses.md`).
const Map<ExpenseCategory, String> expenseCategoryLabel = {
  ExpenseCategory.food: 'Food',
  ExpenseCategory.travel: 'Travel',
  ExpenseCategory.rent: 'Rent',
  ExpenseCategory.utilities: 'Utilities',
  ExpenseCategory.groceries: 'Groceries',
  ExpenseCategory.entertainment: 'Entertainment',
  ExpenseCategory.shopping: 'Shopping',
  ExpenseCategory.other: 'Other',
};

/// Material Icon per category. Architect-ratified single-glyph picks
/// per Architect Notes §2.9 — each icon reads at 24 dp without
/// ambiguity on both light and dark backgrounds.
const Map<ExpenseCategory, IconData> expenseCategoryIcon = {
  ExpenseCategory.food: Icons.restaurant,
  ExpenseCategory.travel: Icons.flight,
  ExpenseCategory.rent: Icons.home,
  ExpenseCategory.utilities: Icons.bolt,
  ExpenseCategory.groceries: Icons.local_grocery_store,
  ExpenseCategory.entertainment: Icons.movie,
  ExpenseCategory.shopping: Icons.shopping_bag,
  ExpenseCategory.other: Icons.more_horiz,
};
