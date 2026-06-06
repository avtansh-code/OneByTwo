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
  /// Creates an [AddExpenseController]. The constructor fires
  /// `expense_step1_opened` synchronously.
  AddExpenseController({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required ExpenseRepository repository,
    required AnalyticsService analytics,
    DateTime Function()? clock,
  }) : _repository = repository,
       _analytics = analytics,
       _clock = clock ?? DateTime.now,
       super(
         Editing(
           step: 1,
           draft: ExpenseDraft(
             date: (clock ?? DateTime.now)(),
             payerId: currentUserUid,
           ),
         ),
       ) {
    _step1OpenedAt = _clock();
    _emitStep1Opened();
  }

  /// The friendship document ID — `uid-a_uid-b` sorted lexicographically.
  final String friendshipId;

  /// The authenticated user's UID.
  final String currentUserUid;

  /// The friend's UID (the other party to the friendship).
  final String otherUserUid;

  final ExpenseRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _clock;

  /// Wall-clock timestamp when Step 1 was opened, used to compute
  /// `time_spent_ms` for the abandonment events.
  late DateTime _step1OpenedAt;

  /// Wall-clock timestamp when Step 2 was entered.
  DateTime? _step2OpenedAt;

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
  }

  // ---------------------------------------------------------------
  // Save and discard
  // ---------------------------------------------------------------

  /// Persists the draft to Firestore via the repository.
  /// Editing → Saving → (Success | AddExpenseError).
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
      // Re-throw via Future.error so observers can capture; the
      // controller has already moved to AddExpenseError above.
      throw ExpenseCreateError(
        type: ExpenseCreateErrorType.unknown,
        underlying: err,
        stackTrace: st,
      );
    }
  }

  /// Closes the sheet. Emits the matching abandonment event if the
  /// user had populated any step-1 fields (or had advanced to step 2).
  void discard() {
    final s = state;
    if (s is! Editing) return;
    final draft = s.draft;
    final now = _clock();

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
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddExpenseArgs &&
        other.friendshipId == friendshipId &&
        other.currentUserUid == currentUserUid &&
        other.otherUserUid == otherUserUid;
  }

  @override
  int get hashCode => Object.hash(friendshipId, currentUserUid, otherUserUid);
}
