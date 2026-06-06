import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/settlements/domain/settle_up_draft.dart';
import 'package:onebytwo/features/settlements/domain/settlement_create_error.dart';

/// Sealed-class hierarchy for the Settle Up bottom sheet (Architect
/// Notes §2.1). UI widgets are pure projections of these states; the
/// controller is the sole owner of telemetry emission and Firestore
/// writes.
@immutable
sealed class SettleUpState {
  /// Creates a [SettleUpState].
  const SettleUpState();
}

/// User is editing the draft. [validationErrors] is empty when the
/// draft is valid; otherwise it carries field-keyed messages
/// (`amount`, `note`).
class SettleUpEditing extends SettleUpState {
  /// Creates a [SettleUpEditing] state.
  const SettleUpEditing({
    required this.draft,
    this.validationErrors = const <String, String>{},
  });

  /// The current draft snapshot.
  final SettleUpDraft draft;

  /// Field-keyed inline validation messages.
  final Map<String, String> validationErrors;

  /// `true` when the draft has no validation errors AND
  /// `draft.validate()` is empty — both conditions are necessary
  /// because [validationErrors] is updated lazily on setter calls.
  bool get isSaveEnabled =>
      validationErrors.isEmpty && draft.validate().isEmpty;
}

/// The Firestore write is in flight. The UI renders a loading spinner
/// on the Save button.
class SettleUpSaving extends SettleUpState {
  /// Creates a [SettleUpSaving] state.
  const SettleUpSaving({required this.draft});

  /// The draft being saved.
  final SettleUpDraft draft;
}

/// The Firestore write succeeded. The UI dismisses the sheet and shows
/// the success snackbar.
class SettleUpSuccess extends SettleUpState {
  /// Creates a [SettleUpSuccess] state.
  const SettleUpSuccess({required this.settlementId, required this.isPartial});

  /// The new settlement document's ID.
  final String settlementId;

  /// Mirrors [SettleUpDraft.isPartial] at the time of the save —
  /// surfaced for the success snackbar copy and for downstream
  /// confirmation-screen telemetry (deferred to a later UX PR).
  final bool isPartial;
}

/// The Firestore write threw. The UI keeps the sheet open and shows
/// the error snackbar; the user may retry from the same state.
class SettleUpError extends SettleUpState {
  /// Creates a [SettleUpError] state.
  const SettleUpError({
    required this.draft,
    required this.errorType,
    required this.message,
  });

  /// The draft that failed to save.
  final SettleUpDraft draft;

  /// Typed error classification per Architect Notes §2.1.
  final SettlementCreateErrorType errorType;

  /// User-facing message (per AC-7 / AC-8).
  final String message;
}
