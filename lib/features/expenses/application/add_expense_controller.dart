import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/expense_draft.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// AC-2 cap (paise). Mirrors `OBTAmountInput._kMaxPaise`. Kept here so
/// the controller can validate amounts that originated outside the
/// reusable input (e.g. paste-into-Firestore tooling, future deep-link
/// drafts).
const int _kMaxPaise = 999999999;

/// Maximum description length per AC-3 / SCR-19.
const int _kMaxDescriptionChars = 100;

/// Validation error message constants (use the screen-spec wording).
const String _kMsgAmountOverCap = 'Amount cannot exceed ₹99,99,999.99.';
const String _kMsgDescriptionTooLong =
    'Description must be under 100 characters.';
const String _kMsgDateFuture = 'Date cannot be in the future.';
const String _kMsgSaveFailure = "Couldn't add the expense. Try again.";
const String _kMsgEditFailure = 'Could not save changes. Try again.';
const String _kMsgDeleteFailure = "Couldn't delete the expense. Try again.";

/// Driver for the two-step Add Expense bottom sheet.
///
/// Riverpod 2.x [StateNotifier] that mirrors the
/// `MatchAndInviteController` precedent: sealed-state hierarchy, one
/// `_emit*` helper per telemetry event, repository + analytics
/// injected via constructor. UI widgets are pure projections.
///
/// Architect Notes §2.2, §2.5 — the controller takes ONLY the
/// friendship and user identifiers, the repository, the analytics
/// service, and the clock. It does NOT depend on `userProfileProvider`
/// or `friendsListProvider`; payer labels in the UI use the
/// placeholder strings "You" / "Friend".
class AddExpenseController extends StateNotifier<AddExpenseState> {
  /// Creates an [AddExpenseController].
  ///
  /// In **create mode** ([initialExpense] == null), the constructor
  /// fires `expense_step1_opened` synchronously — the existing
  /// FR-EX-01 behaviour. In **edit mode** ([initialExpense] != null),
  /// the constructor pre-fills the draft from the supplied document,
  /// captures the original snapshot for the changed-field diff, and
  /// fires `expense_edit_opened` instead.
  AddExpenseController({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required ExpenseRepository repository,
    required AnalyticsService analytics,
    DateTime Function()? clock,
    this.initialExpense,
    this.initialExpenseId,
  }) : _repository = repository,
       _analytics = analytics,
       _clock = clock ?? DateTime.now,
       super(
         _initialState(initialExpense, clock ?? DateTime.now, currentUserUid),
       ) {
    _step1OpenedAt = _clock();
    if (isEditMode) {
      _originalSnapshot = _snapshotFromDoc(initialExpense!);
      _emitEditOpened();
    } else {
      _originalSnapshot = null;
      _emitStep1Opened();
    }
  }

  /// The friendship document ID — `uid-a_uid-b` sorted lexicographically.
  final String friendshipId;

  /// The authenticated user's UID.
  final String currentUserUid;

  /// The friend's UID (the other party to the friendship).
  final String otherUserUid;

  /// Source-of-truth expense document when the sheet is hosted in
  /// edit mode. Null in create mode.
  final ExpenseDoc? initialExpense;

  /// Firestore document ID of [initialExpense]. Null in create mode.
  final String? initialExpenseId;

  /// True when the controller is in edit mode.
  bool get isEditMode => initialExpense != null;

  final ExpenseRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _clock;

  /// Wall-clock timestamp when Step 1 was opened, used to compute
  /// `time_spent_ms` for the abandonment events.
  late DateTime _step1OpenedAt;

  /// Wall-clock timestamp when Step 2 was entered.
  DateTime? _step2OpenedAt;

  /// Snapshot of the original (read-from-Firestore) field values
  /// captured at construction time. Used by [_markChanged] to
  /// compute the diff against the current draft. Null in create
  /// mode.
  late final _OriginalSnapshot? _originalSnapshot;

  /// Set of fields that have been changed from the original. Only
  /// populated in edit mode. Read by the host widget to (a) disable
  /// the Save CTA when empty (no-op guard) and (b) render the
  /// changed-field indicator on Step 2 rows.
  final Set<String> _changedFields = <String>{};

  /// Unmodifiable view of [_changedFields] for the host widget.
  Set<String> get changedFields => Set<String>.unmodifiable(_changedFields);

  // ---------------------------------------------------------------
  // Initial-state helpers
  // ---------------------------------------------------------------

  static AddExpenseState _initialState(
    ExpenseDoc? initial,
    DateTime Function() clock,
    String currentUid,
  ) {
    if (initial == null) {
      return Editing(
        step: 1,
        draft: ExpenseDraft(date: clock(), payerId: currentUid),
      );
    }
    return Editing(
      step: 1,
      draft: ExpenseDraft(
        amountPaise: initial.amountPaise,
        description: initial.description,
        category: initial.category,
        date: initial.date,
        splitMethod: initial.splitMethod,
        payerId: initial.payerId,
        exactShares: initial.splitMethod == SplitMethod.exact
            ? initial.splits.map((s) => s.sharePaise).toList(growable: false)
            : const <int>[],
      ),
    );
  }

  static _OriginalSnapshot _snapshotFromDoc(ExpenseDoc doc) {
    return _OriginalSnapshot(
      amountPaise: doc.amountPaise,
      description: doc.description,
      category: doc.category,
      date: doc.date,
      payerId: doc.payerId,
      splits: List<Split>.unmodifiable(doc.splits),
      splitMethod: doc.splitMethod,
    );
  }

  // ---------------------------------------------------------------
  // Step 1 setters
  // ---------------------------------------------------------------

  /// Updates the draft amount (paise). Surfaces a validation error
  /// when the value exceeds the AC-2 cap.
  void setAmount(int paise) {
    final s = state;
    if (s is! Editing) return;
    final newDraft = s.draft.copyWith(amountPaise: paise);
    final errors = Map<String, String>.from(s.validationErrors);
    if (paise > _kMaxPaise) {
      errors['amount'] = _kMsgAmountOverCap;
    } else {
      errors.remove('amount');
    }
    state = Editing(step: s.step, draft: newDraft, validationErrors: errors);
    _markChanged(ExpenseDoc.fieldAmountPaise, paise);
  }

  /// Updates the draft description (trimmed). Surfaces validation
  /// errors for empty and >100-char inputs.
  void setDescription(String raw) {
    final s = state;
    if (s is! Editing) return;
    final trimmed = raw.trim();
    final newDraft = s.draft.copyWith(description: trimmed);
    final errors = Map<String, String>.from(s.validationErrors);
    if (trimmed.length > _kMaxDescriptionChars) {
      errors['description'] = _kMsgDescriptionTooLong;
    } else {
      errors.remove('description');
    }
    state = Editing(step: s.step, draft: newDraft, validationErrors: errors);
    _markChanged(ExpenseDoc.fieldDescription, trimmed);
  }

  /// Updates the draft category and fires `expense_category_selected`.
  void setCategory(ExpenseCategory category) {
    final s = state;
    if (s is! Editing) return;
    final newDraft = s.draft.copyWith(category: category);
    state = Editing(
      step: s.step,
      draft: newDraft,
      validationErrors: s.validationErrors,
    );
    _emitCategorySelected(category);
    _markChanged(ExpenseDoc.fieldCategory, category);
  }

  /// Updates the draft date. Surfaces a validation error for future
  /// dates.
  void setDate(DateTime date) {
    final s = state;
    if (s is! Editing) return;
    final today = _clock();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final newDraft = s.draft.copyWith(date: date);
    final errors = Map<String, String>.from(s.validationErrors);
    if (date.isAfter(endOfToday)) {
      errors['date'] = _kMsgDateFuture;
    } else {
      errors.remove('date');
    }
    state = Editing(step: s.step, draft: newDraft, validationErrors: errors);
    _markChanged(ExpenseDoc.fieldDate, date);
  }

  // ---------------------------------------------------------------
  // Step transitions
  // ---------------------------------------------------------------

  /// Advances to Step 2 if the draft is valid; otherwise no-op.
  void proceedToStep2() {
    final s = state;
    if (s is! Editing) return;
    if (s.step != 1) return;
    if (!s.draft.isStep1Complete) return;
    if (s.validationErrors.isNotEmpty) return;

    _emitStep1Completed(s.draft);
    _step2OpenedAt = _clock();
    state = Editing(step: 2, draft: s.draft);
    _emitStep2Opened(s.draft);
  }

  /// Returns to Step 1 from Step 2.
  void back() {
    final s = state;
    if (s is! Editing) return;
    if (s.step != 2) return;
    state = Editing(
      step: 1,
      draft: s.draft,
      validationErrors: s.validationErrors,
    );
  }

  // ---------------------------------------------------------------
  // Step 2 setters
  // ---------------------------------------------------------------

  /// Sets the split method. Silently no-ops when the requested method
  /// is disabled (FR-EX-01 ships `equal` and `exact` only).
  void setSplitMethod(SplitMethod method) {
    final s = state;
    if (s is! Editing) return;
    if (s.step != 2) return;
    if (!isSplitMethodEnabled(method)) return;
    if (s.draft.splitMethod == method) return;

    final oldMethod = s.draft.splitMethod;
    final newDraft = s.draft.copyWith(splitMethod: method);
    // Clear any prior split-validation error: switching methods resets
    // the validation surface.
    final errors = Map<String, String>.from(s.validationErrors)
      ..remove('splits');
    state = Editing(step: s.step, draft: newDraft, validationErrors: errors);
    _emitSplitMethodChanged(oldMethod, method);
    _markChanged(ExpenseDoc.fieldSplitMethod, method);
  }

  /// Switches the payer between `currentUserUid` and `otherUserUid`.
  /// Fires `expense_payer_changed` only when the payer actually
  /// changes.
  void setPayerId(String userId) {
    final s = state;
    if (s is! Editing) return;
    if (s.step != 2) return;
    if (s.draft.payerId == userId) return;

    final newDraft = s.draft.copyWith(payerId: userId);
    state = Editing(
      step: s.step,
      draft: newDraft,
      validationErrors: s.validationErrors,
    );
    _emitPayerChanged(payerIsSelf: userId == currentUserUid);
    _markChanged(ExpenseDoc.fieldPayerId, userId);
  }

  /// Sets the exact-shares list for [SplitMethod.exact]. Surfaces a
  /// `splits` validation error (and fires
  /// `expense_split_validation_failed`) when the sum diverges from
  /// `amountPaise`.
  void setExactShares(List<int> shares) {
    final s = state;
    if (s is! Editing) return;
    if (s.step != 2) return;

    final newDraft = s.draft.copyWith(exactShares: List<int>.from(shares));
    final errors = Map<String, String>.from(s.validationErrors);
    final sum = shares.fold<int>(0, (a, b) => a + b);
    final total = s.draft.amountPaise;

    if (sum == total) {
      errors.remove('splits');
    } else {
      final direction = sum < total ? 'under' : 'over';
      errors['splits'] = _splitMismatchMessage(total, sum, direction);
      _emitSplitValidationFailed(SplitMethod.exact, direction);
    }

    state = Editing(step: s.step, draft: newDraft, validationErrors: errors);
    // In edit mode, the splits field changes iff the computed share
    // for either member differs from the original. Recompute the
    // would-be Firestore splits and compare.
    if (isEditMode && sum == total) {
      _markChanged(ExpenseDoc.fieldSplits, _computeShares(newDraft));
    }
  }

  // ---------------------------------------------------------------
  // Save and discard
  // ---------------------------------------------------------------

  /// Persists the draft to Firestore via the repository.
  /// Editing → Saving → (Success | AddExpenseError).
  ///
  /// In edit mode the branch calls `updateExpense` with a partial
  /// map shaped by `toUpdateMap(changedFields)`. The no-op guard
  /// (AC-3) short-circuits when `changedFields.isEmpty`.
  Future<void> save() async {
    final entry = state;
    final draft = switch (entry) {
      Editing(:final draft) => draft,
      AddExpenseError(:final draft) => draft,
      _ => null,
    };
    if (draft == null) return;
    if (!draft.isStep1Complete) return;
    if (draft.payerId == null) return;

    if (isEditMode) {
      // No-op guard: a save with zero changed fields is a deliberate
      // no-op (AC-3). The host widget also disables the CTA but the
      // controller is the load-bearing guard.
      if (_changedFields.isEmpty) return;

      _emitStep2Completed(draft);
      state = Saving(draft: draft);

      try {
        final shares = _computeShares(draft);
        final edited = ExpenseDoc(
          id: initialExpenseId,
          amountPaise: draft.amountPaise,
          description: draft.description,
          category: draft.category!,
          date: draft.date ?? _clock(),
          payerId: draft.payerId!,
          splits: shares,
          splitMethod: draft.splitMethod,
          createdBy: initialExpense!.createdBy,
        );
        // If the user re-entered an exact-shares list whose computed
        // values diverge from the original, ensure the splits key is
        // in the changed set. Belt-and-braces with the setExactShares
        // hook above.
        if (!_splitsEqual(edited.splits, _originalSnapshot!.splits)) {
          _changedFields.add(ExpenseDoc.fieldSplits);
        }
        final updates = edited.toUpdateMap(_changedFields);
        await _repository.updateExpense(
          friendshipId: friendshipId,
          expenseId: initialExpenseId!,
          updates: updates,
        );
        _emitEditSaved(draft: draft, fieldsChanged: _changedFields);
        state = Success(
          expenseId: initialExpenseId!,
          action: SuccessAction.editSaved,
        );
      } on ExpenseUpdateError catch (err) {
        _emitEditFailed(err.type);
        state = AddExpenseError(
          draft: draft,
          errorType: ExpenseCreateErrorType.unknown,
          message: _kMsgEditFailure,
        );
      }
      return;
    }

    // Create-mode branch — unchanged from PR #38.
    _emitStep2Completed(draft);
    state = Saving(draft: draft);

    try {
      final shares = _computeShares(draft);
      final doc = ExpenseDoc(
        amountPaise: draft.amountPaise,
        description: draft.description,
        category: draft.category!,
        date: draft.date ?? _clock(),
        payerId: draft.payerId!,
        splits: shares,
        splitMethod: draft.splitMethod,
        createdBy: currentUserUid,
      );
      final id = await _repository.createExpense(
        friendshipId: friendshipId,
        doc: doc,
      );
      _emitSaveSucceeded(draft: draft, expenseId: id);
      state = Success(expenseId: id);
    } on ExpenseCreateError catch (err) {
      _emitSaveFailed(err.type);
      state = AddExpenseError(
        draft: draft,
        errorType: err.type,
        message: _kMsgSaveFailure,
      );
    } catch (err, st) {
      _emitSaveFailed(ExpenseCreateErrorType.unknown);
      state = AddExpenseError(
        draft: draft,
        errorType: ExpenseCreateErrorType.unknown,
        message: _kMsgSaveFailure,
      );
      // Report to the framework's error reporter (Crashlytics hooks
      // into this via FlutterError.onError when wired in main.dart).
      // We don't rethrow because the call site uses VoidCallback —
      // a rethrown Future error would become an unhandled async error
      // routed to PlatformDispatcher.instance.onError. The typed
      // branch above is symmetric: state-transition + telemetry only.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: err,
          stack: st,
          library: 'expenses',
          context: ErrorDescription(
            'unexpected error during AddExpenseController.save()',
          ),
        ),
      );
    }
  }

  /// Soft-deletes the original expense (edit mode only). Editing →
  /// Saving → (Success(deleted) | AddExpenseError).
  ///
  /// No-op in create mode (the absence of an
  /// [initialExpenseId] means there is nothing to soft-delete).
  Future<void> softDelete() async {
    if (!isEditMode || initialExpenseId == null) return;
    final draft = _currentDraft();
    if (draft == null) return;
    state = Saving(draft: draft);
    try {
      await _repository.softDeleteExpense(
        friendshipId: friendshipId,
        expenseId: initialExpenseId!,
      );
      _emitDeleteConfirmed(draft: draft);
      state = Success(
        expenseId: initialExpenseId!,
        action: SuccessAction.deleted,
      );
    } on ExpenseDeleteError catch (err) {
      _emitDeleteFailed(err.type);
      state = AddExpenseError(
        draft: draft,
        // Reuse the existing ExpenseCreateErrorType.unknown for the
        // state-machine variant — the host widget displays the
        // dedicated delete-failure message verbatim. The typed
        // ExpenseDeleteErrorType already drove the telemetry payload
        // above.
        errorType: ExpenseCreateErrorType.unknown,
        message: _kMsgDeleteFailure,
      );
    }
  }

  /// Fires `expense_delete_initiated` (call from the dialog open
  /// path). Public so the host widget can emit the event
  /// before the typed `show()` await even though the controller does
  /// not own the dialog instance.
  void openDeleteDialog() => _emitDeleteInitiated();

  /// Fires `expense_delete_cancelled` (call from the dialog cancel
  /// path).
  void cancelDeleteDialog() => _emitDeleteCancelled();

  /// Returns the current draft from any non-terminal state, or null.
  ExpenseDraft? _currentDraft() {
    final s = state;
    return switch (s) {
      Editing(:final draft) => draft,
      Saving(:final draft) => draft,
      AddExpenseError(:final draft) => draft,
      Success() => null,
    };
  }

  /// Closes the sheet. Emits the matching abandonment event if the
  /// user had populated any step-1 fields (or had advanced to step 2).
  /// In edit mode, fires `expense_edit_abandoned` with the
  /// `had_changes` flag instead of the create-mode events.
  void discard() {
    final s = state;
    if (s is! Editing) return;
    final draft = s.draft;
    final now = _clock();

    if (isEditMode) {
      final ms = now.difference(_step1OpenedAt).inMilliseconds;
      _emitEditAbandoned(
        hadChanges: _changedFields.isNotEmpty,
        timeSpentMs: ms,
      );
      return;
    }

    if (s.step == 2) {
      final openedAt = _step2OpenedAt ?? _step1OpenedAt;
      final ms = now.difference(openedAt).inMilliseconds;
      _emitStep2Abandoned(draft.splitMethod, ms);
      return;
    }
    if (draft.filledFieldCount > 0) {
      final ms = now.difference(_step1OpenedAt).inMilliseconds;
      _emitStep1Abandoned(draft.filledFieldCount, ms);
    }
  }

  // ---------------------------------------------------------------
  // Internals — split computation
  // ---------------------------------------------------------------

  List<Split> _computeShares(ExpenseDraft draft) {
    final members = <String>[currentUserUid, otherUserUid];
    return computeSplits(
      method: draft.splitMethod,
      totalPaise: draft.amountPaise,
      memberUids: members,
      payerUid: draft.payerId,
      exactShares: draft.splitMethod == SplitMethod.exact
          ? draft.exactShares
          : null,
    );
  }

  String _splitMismatchMessage(int total, int sum, String direction) {
    final delta = (total - sum).abs();
    final totalStr = formatInrFromPaise(total);
    final sumStr = formatInrFromPaise(sum);
    final deltaStr = formatInrFromPaise(delta);
    return 'Splits must sum to $totalStr (currently $sumStr '
        '— $deltaStr $direction).';
  }

  // ---------------------------------------------------------------
  // Telemetry emit helpers — one per event, per the architect notes.
  // ---------------------------------------------------------------

  void _emitStep1Opened() {
    _analytics.logEvent(
      name: ExpenseTelemetry.step1Opened,
      parameters: <String, Object>{
        ExpenseTelemetry.paramContextType: 'friend',
        ExpenseTelemetry.paramEntryPoint: 'friend_detail',
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
      },
    );
  }

  void _emitCategorySelected(ExpenseCategory category) {
    _analytics.logEvent(
      name: ExpenseTelemetry.categorySelected,
      parameters: <String, Object>{
        ExpenseTelemetry.paramCategory: category.name,
      },
    );
  }

  void _emitStep1Completed(ExpenseDraft draft) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step1Completed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramAmountRange: ExpenseTelemetry.amountRangeFor(
          draft.amountPaise,
        ),
        ExpenseTelemetry.paramCategory: draft.category!.name,
        ExpenseTelemetry.paramHasNotes: false,
      },
    );
  }

  void _emitStep1Abandoned(int fieldsFilled, int ms) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step1Abandoned,
      parameters: <String, Object>{
        ExpenseTelemetry.paramFieldsFilledCount: fieldsFilled,
        ExpenseTelemetry.paramTimeSpentMs: ms,
      },
    );
  }

  void _emitStep2Opened(ExpenseDraft draft) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step2Opened,
      parameters: <String, Object>{
        ExpenseTelemetry.paramSplitMethod: draft.splitMethod.name,
        ExpenseTelemetry.paramParticipantCount: 2,
      },
    );
  }

  void _emitSplitMethodChanged(SplitMethod from, SplitMethod to) {
    _analytics.logEvent(
      name: ExpenseTelemetry.splitMethodChanged,
      parameters: <String, Object>{
        ExpenseTelemetry.paramFromMethod: from.name,
        ExpenseTelemetry.paramToMethod: to.name,
      },
    );
  }

  void _emitPayerChanged({required bool payerIsSelf}) {
    _analytics.logEvent(
      name: ExpenseTelemetry.payerChanged,
      parameters: <String, Object>{
        ExpenseTelemetry.paramPayerIsSelf: payerIsSelf,
      },
    );
  }

  void _emitStep2Completed(ExpenseDraft draft) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step2Completed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramSplitMethod: draft.splitMethod.name,
        ExpenseTelemetry.paramParticipantCount: 2,
        ExpenseTelemetry.paramPayerIsSelf: draft.payerId == currentUserUid,
      },
    );
  }

  void _emitSplitValidationFailed(SplitMethod method, String direction) {
    _analytics.logEvent(
      name: ExpenseTelemetry.splitValidationFailed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramSplitMethod: method.name,
        ExpenseTelemetry.paramDirection: direction,
      },
    );
  }

  void _emitStep2Abandoned(SplitMethod method, int ms) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step2Abandoned,
      parameters: <String, Object>{
        ExpenseTelemetry.paramSplitMethod: method.name,
        ExpenseTelemetry.paramTimeSpentMs: ms,
      },
    );
  }

  void _emitSaveSucceeded({
    required ExpenseDraft draft,
    required String expenseId,
  }) {
    _analytics.logEvent(
      name: ExpenseTelemetry.saveSucceeded,
      parameters: <String, Object>{
        ExpenseTelemetry.paramContextType: 'friend',
        ExpenseTelemetry.paramAmountRange: ExpenseTelemetry.amountRangeFor(
          draft.amountPaise,
        ),
        ExpenseTelemetry.paramCategory: draft.category!.name,
        ExpenseTelemetry.paramSplitMethod: draft.splitMethod.name,
        ExpenseTelemetry.paramParticipantCount: 2,
        ExpenseTelemetry.paramHasReceipt: false,
        ExpenseTelemetry.paramHasNotes: false,
        ExpenseTelemetry.paramIsOffline: false,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        ExpenseTelemetry.paramExpenseIdHash: hashId(expenseId),
      },
    );
  }

  void _emitSaveFailed(ExpenseCreateErrorType type) {
    _analytics.logEvent(
      name: ExpenseTelemetry.saveFailed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramErrorType: _errorTypeName(type),
        ExpenseTelemetry.paramIsOffline: type == ExpenseCreateErrorType.network,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
      },
    );
  }

  String _errorTypeName(ExpenseCreateErrorType type) {
    switch (type) {
      case ExpenseCreateErrorType.permissionDenied:
        return 'permission_denied';
      case ExpenseCreateErrorType.network:
        return 'network';
      case ExpenseCreateErrorType.unknown:
        return 'unknown';
    }
  }

  // ---------------------------------------------------------------
  // FR-EX-06 — edit/delete emit helpers (architect §2.6).
  // ---------------------------------------------------------------

  void _emitEditOpened() {
    _analytics.logEvent(
      name: ExpenseTelemetry.editOpened,
      parameters: <String, Object>{
        ExpenseTelemetry.paramContextType: 'friend',
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitEditFieldChanged(String fieldName) {
    _analytics.logEvent(
      name: ExpenseTelemetry.editFieldChanged,
      parameters: <String, Object>{ExpenseTelemetry.paramFieldName: fieldName},
    );
  }

  void _emitEditSaved({
    required ExpenseDraft draft,
    required Set<String> fieldsChanged,
  }) {
    // Stable order — toUpdateMap iterates the constants in insertion
    // order, but the set's iteration order is the order of insertion
    // by _markChanged. A sorted list keeps the analytics payload
    // deterministic across runs.
    final sorted = fieldsChanged.toList(growable: false)..sort();
    _analytics.logEvent(
      name: ExpenseTelemetry.editSaved,
      parameters: <String, Object>{
        ExpenseTelemetry.paramFieldsChanged: sorted.join(','),
        ExpenseTelemetry.paramSplitMethod: draft.splitMethod.name,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitEditFailed(ExpenseUpdateErrorType type) {
    _analytics.logEvent(
      name: ExpenseTelemetry.editFailed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramErrorCode: type.name,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitEditAbandoned({
    required bool hadChanges,
    required int timeSpentMs,
  }) {
    _analytics.logEvent(
      name: ExpenseTelemetry.editAbandoned,
      parameters: <String, Object>{
        ExpenseTelemetry.paramHadChanges: hadChanges,
        ExpenseTelemetry.paramTimeSpentMs: timeSpentMs,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitDeleteInitiated() {
    _analytics.logEvent(
      name: ExpenseTelemetry.deleteInitiated,
      parameters: <String, Object>{
        ExpenseTelemetry.paramContextType: 'friend',
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitDeleteConfirmed({required ExpenseDraft draft}) {
    _analytics.logEvent(
      name: ExpenseTelemetry.deleteConfirmed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramAmountPaise: draft.amountPaise,
        ExpenseTelemetry.paramParticipantCount: 2,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitDeleteCancelled() {
    _analytics.logEvent(
      name: ExpenseTelemetry.deleteCancelled,
      parameters: <String, Object>{
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  void _emitDeleteFailed(ExpenseDeleteErrorType type) {
    _analytics.logEvent(
      name: ExpenseTelemetry.deleteFailed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramErrorCode: type.name,
        ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        if (initialExpenseId != null)
          ExpenseTelemetry.paramExpenseIdHash: hashId(initialExpenseId!),
      },
    );
  }

  // ---------------------------------------------------------------
  // FR-EX-06 — change-tracking (only meaningful in edit mode).
  // ---------------------------------------------------------------

  /// Marks `field` changed (or no-longer-changed) by comparing
  /// [newValue] against the snapshot captured at construction.
  ///
  /// Transitions:
  ///   - original-state → changed-state: add to `_changedFields` and
  ///     emit `expense_edit_field_changed` ONCE.
  ///   - changed-state → original-state (user reverted): remove from
  ///     `_changedFields`; do NOT emit a new event (one-shot semantics
  ///     per architect §2.6).
  ///
  /// No-op in create mode.
  void _markChanged(String field, Object? newValue) {
    if (!isEditMode || _originalSnapshot == null) return;
    final original = _originalValueFor(field);
    final isStillChanged = !_valuesEqual(field, newValue, original);
    final wasChanged = _changedFields.contains(field);
    if (isStillChanged && !wasChanged) {
      _changedFields.add(field);
      _emitEditFieldChanged(field);
    } else if (!isStillChanged && wasChanged) {
      _changedFields.remove(field);
    }
  }

  /// Returns the original value for [field] from the captured snapshot.
  /// Returns `null` if `_originalSnapshot` is null (defensive — the
  /// caller always guards with `isEditMode`).
  Object? _originalValueFor(String field) {
    final snap = _originalSnapshot;
    if (snap == null) return null;
    switch (field) {
      case ExpenseDoc.fieldAmountPaise:
        return snap.amountPaise;
      case ExpenseDoc.fieldDescription:
        return snap.description;
      case ExpenseDoc.fieldCategory:
        return snap.category;
      case ExpenseDoc.fieldDate:
        return snap.date;
      case ExpenseDoc.fieldPayerId:
        return snap.payerId;
      case ExpenseDoc.fieldSplits:
        return snap.splits;
      case ExpenseDoc.fieldSplitMethod:
        return snap.splitMethod;
    }
    return null;
  }

  /// Field-aware equality used by `_markChanged`.
  ///
  /// - `date`: compares year/month/day only (the picker resets the
  ///   time component to midnight, but the original may carry a
  ///   server timestamp with non-zero time).
  /// - `splits`: compares element-by-element on (userId, sharePaise).
  /// - everything else: simple `==`.
  bool _valuesEqual(String field, Object? a, Object? b) {
    if (field == ExpenseDoc.fieldDate) {
      if (a is! DateTime || b is! DateTime) return a == b;
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }
    if (field == ExpenseDoc.fieldSplits) {
      if (a is! List<Split> || b is! List<Split>) return false;
      return _splitsEqual(a, b);
    }
    return a == b;
  }

  bool _splitsEqual(List<Split> a, List<Split> b) {
    if (a.length != b.length) return false;
    // The list is canonicalised by `_computeShares` to follow the
    // [currentUserUid, otherUserUid] order, and the original
    // snapshot is captured in Firestore-write order. To make the
    // comparison robust against any future reordering, key by
    // userId before comparing.
    final aBy = <String, int>{for (final s in a) s.userId: s.sharePaise};
    final bBy = <String, int>{for (final s in b) s.userId: s.sharePaise};
    if (aBy.length != bBy.length) return false;
    for (final entry in aBy.entries) {
      if (bBy[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// Captured-at-construction snapshot of the original [ExpenseDoc].
/// Used by the controller to compute the changed-fields diff in
/// edit mode without retaining the full doc in mutable state.
@immutable
class _OriginalSnapshot {
  const _OriginalSnapshot({
    required this.amountPaise,
    required this.description,
    required this.category,
    required this.date,
    required this.payerId,
    required this.splits,
    required this.splitMethod,
  });

  final int amountPaise;
  final String description;
  final ExpenseCategory category;
  final DateTime date;
  final String payerId;
  final List<Split> splits;
  final SplitMethod splitMethod;
}

/// Family provider keyed by friendship + user-pair tuple. The host
/// widget (`AddExpenseBottomSheet`) reads via this provider; the
/// widget tests override `expenseRepositoryProvider` and
/// `analyticsServiceProvider`, leaving the controller construction
/// itself to flow through this binding.
final addExpenseControllerProvider = StateNotifierProvider.autoDispose
    .family<AddExpenseController, AddExpenseState, AddExpenseArgs>((ref, args) {
      return AddExpenseController(
        friendshipId: args.friendshipId,
        currentUserUid: args.currentUserUid,
        otherUserUid: args.otherUserUid,
        repository: ref.watch(expenseRepositoryProvider),
        analytics: ref.watch(analyticsServiceProvider),
        initialExpense: args.initialExpense,
        initialExpenseId: args.initialExpenseId,
      );
    });

/// Argument tuple for [addExpenseControllerProvider].
@immutable
class AddExpenseArgs {
  /// Creates an [AddExpenseArgs].
  const AddExpenseArgs({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    this.initialExpense,
    this.initialExpenseId,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  /// When non-null, drives the controller into edit mode and seeds
  /// the draft from this document. Pair with [initialExpenseId].
  final ExpenseDoc? initialExpense;

  /// Firestore document ID of the expense being edited. Required
  /// alongside [initialExpense] to power update + soft-delete writes.
  final String? initialExpenseId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddExpenseArgs &&
        other.friendshipId == friendshipId &&
        other.currentUserUid == currentUserUid &&
        other.otherUserUid == otherUserUid &&
        other.initialExpenseId == initialExpenseId;
  }

  @override
  int get hashCode =>
      Object.hash(friendshipId, currentUserUid, otherUserUid, initialExpenseId);
}
