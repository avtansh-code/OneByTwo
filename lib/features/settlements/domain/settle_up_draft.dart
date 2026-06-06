import 'package:flutter/foundation.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';

/// UI-state draft for the Settle Up bottom sheet (FR-SE-05 / SCR-23).
///
/// Every monetary field is integer paise (Invariant 1). The draft is
/// immutable; the controller produces a new instance via [copyWith] on
/// every setter call.
///
/// The [suggestedAmountPaise] is locked at construction time and used
/// as the upper-bound for [validate]; the user may settle less than the
/// suggestion (partial settlement) but never more, because settling
/// more would surface a confusing negative balance after the trigger
/// folds the settlement into `simplifiedBalances`.
///
/// [note] follows the canonical `null` form ratified in Architect Notes
/// §2.3 — empty and whitespace-only inputs are folded to `null` via
/// [canonicalNote] at the write boundary so the Firestore document
/// always carries either a non-empty string or an explicit null.
@immutable
class SettleUpDraft {
  /// Creates a [SettleUpDraft]. Most call sites should use
  /// [SettleUpDraft.initial] which pre-fills [amountPaise] to
  /// [suggestedAmountPaise].
  const SettleUpDraft({
    required this.suggestedAmountPaise,
    required this.amountPaise,
    required this.date,
    required this.note,
  });

  /// Creates the initial draft for a fresh sheet open. Pre-fills
  /// [amountPaise] to [suggestedAmountPaise] and defaults [date] to
  /// today (the controller passes its clock).
  factory SettleUpDraft.initial({
    required int suggestedAmountPaise,
    required DateTime date,
  }) {
    return SettleUpDraft(
      suggestedAmountPaise: suggestedAmountPaise,
      amountPaise: suggestedAmountPaise,
      date: date,
      note: null,
    );
  }

  /// The simplified-debts suggestion (`|netBalancePaise|`) — locked at
  /// construction time.
  final int suggestedAmountPaise;

  /// The user-edited amount in paise.
  final int amountPaise;

  /// The user-picked settlement date.
  final DateTime date;

  /// The optional free-text note. Maximum 200 characters (client
  /// validator; rules do not enforce a length).
  final String? note;

  /// Returns a new [SettleUpDraft] with the specified fields replaced.
  /// Pass [clearNote] = `true` to explicitly set [note] to null
  /// (passing `note: null` is ambiguous because `null` is also the
  /// "unspecified" sentinel).
  SettleUpDraft copyWith({
    int? amountPaise,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) {
    return SettleUpDraft(
      suggestedAmountPaise: suggestedAmountPaise,
      amountPaise: amountPaise ?? this.amountPaise,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  /// Returns the field-keyed validation errors. An empty map means
  /// "valid to save".
  ///
  /// Field keys: `amount`, `note`.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (amountPaise <= 0) {
      errors['amount'] = 'Amount must be greater than zero.';
    } else if (amountPaise > suggestedAmountPaise) {
      errors['amount'] =
          'Amount cannot exceed the outstanding balance of '
          '${formatInrFromPaise(suggestedAmountPaise)}.';
    }
    if (note != null && note!.length > 200) {
      errors['note'] = 'Note must be 200 characters or fewer.';
    }
    return errors;
  }

  /// `true` when [amountPaise] < [suggestedAmountPaise] (i.e. the user
  /// recorded a partial settlement). Surfaces in the
  /// `settlement_recorded { is_partial: ... }` telemetry parameter.
  bool get isPartial => amountPaise < suggestedAmountPaise;

  /// Returns the canonical form of [note] for the write payload —
  /// trimmed; empty / whitespace-only strings folded to `null`
  /// (§2.3 canonical form).
  String? get canonicalNote {
    final raw = note;
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
