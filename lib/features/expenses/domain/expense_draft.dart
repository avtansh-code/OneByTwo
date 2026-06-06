import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// UI-state draft for the Add Expense bottom sheet.
///
/// Every monetary field is integer paise (invariant 1). The draft is
/// immutable; the controller produces a new instance via [copyWith] on
/// each setter call.
///
/// `notes` is in the draft for future use (FR-EX-01 mentions optional
/// notes per SCR-19) but is NOT written to Firestore in PR #38 — the
/// `has_notes` telemetry parameter is `false` for every PR #38 save.
@immutable
class ExpenseDraft {
  /// Creates an [ExpenseDraft].
  const ExpenseDraft({
    this.amountPaise = 0,
    this.description = '',
    this.category,
    this.date,
    this.splitMethod = SplitMethod.equal,
    this.payerId,
    this.exactShares = const <int>[],
  });

  /// The amount in paise. Caller (controller setter) enforces the
  /// AC-2 cap; the draft stores whatever the input emits.
  final int amountPaise;

  /// The trimmed description text.
  final String description;

  /// The selected category; `null` means none yet.
  final ExpenseCategory? category;

  /// The selected expense date; `null` means the controller has not
  /// initialised it (the controller defaults to "today" on construction).
  final DateTime? date;

  /// The current split method. Defaults to [SplitMethod.equal].
  final SplitMethod splitMethod;

  /// The current payer's UID; `null` means the controller has not
  /// initialised it (the controller defaults to the current user on
  /// construction).
  final String? payerId;

  /// The per-member shares for [SplitMethod.exact]; empty for the
  /// equal method (the splitter computes those by construction).
  final List<int> exactShares;

  /// Returns a new [ExpenseDraft] with the specified fields replaced.
  /// All other fields retain their current values.
  ExpenseDraft copyWith({
    int? amountPaise,
    String? description,
    ExpenseCategory? category,
    DateTime? date,
    SplitMethod? splitMethod,
    String? payerId,
    List<int>? exactShares,
  }) {
    return ExpenseDraft(
      amountPaise: amountPaise ?? this.amountPaise,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      splitMethod: splitMethod ?? this.splitMethod,
      payerId: payerId ?? this.payerId,
      exactShares: exactShares ?? this.exactShares,
    );
  }

  /// Returns true when every required step-1 field has a non-empty
  /// value (amount > 0, trimmed description non-empty, category set,
  /// date present and not in the future).
  bool get isStep1Complete {
    if (amountPaise <= 0) return false;
    if (description.trim().isEmpty) return false;
    if (category == null) return false;
    if (date == null) return false;
    return true;
  }

  /// Returns the count of step-1 fields the user has populated. Used
  /// by the abandonment telemetry parameter `fields_filled_count`.
  int get filledFieldCount {
    var n = 0;
    if (amountPaise > 0) n++;
    if (description.trim().isNotEmpty) n++;
    if (category != null) n++;
    return n;
  }
}
