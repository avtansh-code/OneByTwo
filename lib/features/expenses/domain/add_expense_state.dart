import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/expenses/domain/expense_create_error.dart';
import 'package:onebytwo/features/expenses/domain/expense_draft.dart';

/// Sealed-class hierarchy for the Add Expense bottom sheet
/// (Architect Notes §2.2). UI widgets are pure projections of these
/// states; the controller is the sole owner of telemetry emission and
/// Firestore writes.
@immutable
sealed class AddExpenseState {
  /// Creates an [AddExpenseState].
  const AddExpenseState();
}

/// User is editing the draft on the given [step] (1 or 2).
class Editing extends AddExpenseState {
  /// Creates an [Editing] state.
  const Editing({
    required this.step,
    required this.draft,
    this.validationErrors = const <String, String>{},
  });

  /// The current step index (1 or 2 in FR-EX-01).
  final int step;

  /// The current draft snapshot.
  final ExpenseDraft draft;

  /// Field-keyed inline validation messages (`amount`, `description`,
  /// `date`, `splits`). Empty when the draft is valid for the current
  /// step.
  final Map<String, String> validationErrors;
}

/// The Firestore write is in flight. The UI renders a loading spinner
/// on the Save button.
class Saving extends AddExpenseState {
  /// Creates a [Saving] state.
  const Saving({required this.draft});

  /// The draft being saved.
  final ExpenseDraft draft;
}

/// The Firestore write succeeded. The UI dismisses the sheet and shows
/// the "Expense added." snackbar.
class Success extends AddExpenseState {
  /// Creates a [Success] state.
  const Success({required this.expenseId});

  /// The new expense document's ID.
  final String expenseId;
}

/// The Firestore write threw. The UI restores the Save button and
/// shows the danger snackbar; the user may retry from the same state.
class AddExpenseError extends AddExpenseState {
  /// Creates an [AddExpenseError] state.
  const AddExpenseError({
    required this.draft,
    required this.errorType,
    required this.message,
  });

  /// The draft that failed to save.
  final ExpenseDraft draft;

  /// Typed error classification per Architect Notes §2.4.
  final ExpenseCreateErrorType errorType;

  /// User-facing message ("Couldn't add the expense. Try again." per
  /// SCR-19 / SCR-20).
  final String message;
}
