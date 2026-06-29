import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
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

/// FR-EX-05: 10 MB cap on receipt size (SRS schema doc line 303 +
/// `storage.rules` `request.resource.size < 10 * 1024 * 1024`).
const int _kMaxReceiptBytes = 10 * 1024 * 1024;

/// FR-EX-05: accepted MIME types for receipts (SRS schema doc line
/// 304 + `storage.rules` `image/(jpeg|png)`).
const Set<String> _kAcceptedReceiptMimeTypes = <String>{
  'image/jpeg',
  'image/png',
};

/// FR-EX-05: accepted file extensions when the picker does NOT
/// surface a `mimeType` (some Android pickers return only `.path`).
const Set<String> _kAcceptedReceiptExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
};

/// FR-EX-05: max image dimension passed to `image_picker` for
/// receipts. Larger than the avatar default (1024) to preserve
/// receipt legibility (architect §2.5).
const int _kReceiptMaxDimension = 1920;

/// Validation error message constants (use the screen-spec wording).
const String _kMsgAmountOverCap = 'Amount cannot exceed ₹99,99,999.99.';
const String _kMsgDescriptionTooLong =
    'Description must be under 100 characters.';
const String _kMsgDateFuture = 'Date cannot be in the future.';
const String _kMsgSaveFailure = "Couldn't add the expense. Try again.";
const String _kMsgEditFailure = 'Could not save changes. Try again.';
const String _kMsgDeleteFailure = "Couldn't delete the expense. Try again.";

/// FR-EX-05 receipt-validation messages (SCR-21 §Inputs and
/// Validation line 348).
const String _kMsgReceiptOversize =
    'Image is too large. Please choose a photo under 10 MB.';
const String _kMsgReceiptWrongType =
    'This file format is not supported. Please use a JPEG or PNG image.';
const String _kMsgReceiptUploadFailed = 'Could not attach receipt. Try again.';

/// FR-EX-05 internal source markers used by `_applyReceipt` to
/// decide whether to fire `expense_receipt_attached`. The "unknown"
/// marker means a non-user-driven attach (e.g. `setReceipt` from a
/// widget test) and does NOT fire telemetry.
const String _kReceiptSourceCamera = 'camera';
const String _kReceiptSourceGallery = 'gallery';
const String _kReceiptSourceUnknown = '__unknown__';

/// FR-EX-05 outcome enum surfaced by [AddExpenseController.setReceipt]
/// and the picker methods. Lets the call site decide whether to
/// clear the picker UI or show the in-band snackbar.
enum ReceiptValidationResult {
  /// File accepted; draft updated.
  ok,

  /// File rejected: size > 10 MB.
  oversize,

  /// File rejected: not a JPEG or PNG.
  unsupportedType,

  /// User cancelled the picker (no `XFile` returned).
  cancelled,

  /// Controller not in an [Editing] state — no-op.
  notEditing,
}

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
    required ReceiptStorageService receiptStorage,
    required ImagePickerService imagePicker,
    DateTime Function()? clock,
    this.initialExpense,
    this.initialExpenseId,
  }) : _repository = repository,
       _analytics = analytics,
       _receiptStorage = receiptStorage,
       _imagePicker = imagePicker,
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
  final ReceiptStorageService _receiptStorage;
  final ImagePickerService _imagePicker;
  final DateTime Function() _clock;

  /// Wall-clock timestamp when Step 1 was opened, used to compute
  /// `time_spent_ms` for the abandonment events.
  late DateTime _step1OpenedAt;

  /// Wall-clock timestamp when Step 2 was entered.
  DateTime? _step2OpenedAt;

  /// Wall-clock timestamp when Step 3 was entered (FR-EX-05). Used
  /// to compute `time_spent_ms` for the `expense_step3_abandoned`
  /// event.
  DateTime? _step3OpenedAt;

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

  /// Returns true when [field] has been modified from its original
  /// value in edit mode (always false in create mode). Used by the
  /// step widgets to render the FR-EX-06 changed-field indicator on
  /// each modified row per SCR-22 §Edit Flow line 449 / §Accessibility
  /// line 509 (AC-4).
  bool isFieldChanged(String field) => _changedFields.contains(field);

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
        existingReceiptUrl: initial.receiptUrl,
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
      receiptUrl: doc.receiptUrl,
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

  /// Returns to the previous step. Step 2 → Step 1; Step 3 → Step 2.
  /// No-op on Step 1.
  void back() {
    final s = state;
    if (s is! Editing) return;
    if (s.step == 1) return;
    state = Editing(
      step: s.step - 1,
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
  // FR-EX-05 — Step 3 transition and receipt setters
  // ---------------------------------------------------------------

  /// Advances to Step 3 if Step 2 is valid (splits sum check is
  /// green; payer is set). Fires
  /// `expense_step3_opened` with
  /// `has_receipt_from_edit: <bool>`. Acts as a no-op when the
  /// current step is not 2 or when the splits validation has
  /// failed.
  void proceedToStep3() {
    final s = state;
    if (s is! Editing) return;
    if (s.step != 2) return;
    if (s.validationErrors['splits'] != null) return;
    if (s.draft.amountPaise <= 0) return;
    if (s.draft.payerId == null) return;

    _step3OpenedAt = _clock();
    state = Editing(step: 3, draft: s.draft);
    _emitStep3Opened(hasReceiptFromEdit: s.draft.existingReceiptUrl != null);
  }

  /// Sets the receipt file directly (used by widget tests that inject
  /// a pre-picked `XFile`). Surfaces size and MIME validation errors
  /// in-band via a snackbar message; returns the validation outcome
  /// so the call site can decide whether to clear the picker UI.
  /// Production code paths use [pickReceiptFromCamera] /
  /// [pickReceiptFromGallery] which call this method internally.
  ReceiptValidationResult setReceipt(XFile? file) {
    final s = state;
    if (s is! Editing) return ReceiptValidationResult.notEditing;
    if (file == null) {
      // Caller passed null — treat as a remove. Symmetric with
      // [removeReceipt] but does not fire the telemetry event (the
      // remove event fires only when the user taps the explicit
      // "Remove" affordance, not when the picker is dismissed).
      state = Editing(
        step: s.step,
        draft: s.draft.copyWith(receiptFile: null),
        validationErrors: s.validationErrors,
      );
      return ReceiptValidationResult.ok;
    }
    return _applyReceipt(file, source: _kReceiptSourceUnknown);
  }

  /// Explicit "Remove" affordance (SCR-21 §States 2 → 1). Clears
  /// both [ExpenseDraft.receiptFile] and
  /// [ExpenseDraft.existingReceiptUrl] (the latter only matters in
  /// edit mode), fires `expense_receipt_removed`, and surfaces the
  /// empty-state picker UI via the new draft.
  void removeReceipt() {
    final s = state;
    if (s is! Editing) return;
    if (!s.draft.hasReceipt) return;
    final newDraft = s.draft.copyWith(
      receiptFile: null,
      existingReceiptUrl: null,
    );
    state = Editing(
      step: s.step,
      draft: newDraft,
      validationErrors: s.validationErrors,
    );
    _emitReceiptRemoved();
    // In edit mode, the receiptUrl field changes whenever the new
    // state diverges from the original.
    _markChanged(ExpenseDoc.fieldReceiptUrl, null);
  }

  /// Opens the camera picker. On success, runs the same validation
  /// pipeline as [setReceipt] and surfaces the snackbar message on
  /// rejection. Telemetry: `expense_receipt_attached` with
  /// `source: 'camera'` fires only on a successful attach.
  Future<ReceiptValidationResult> pickReceiptFromCamera() async {
    final file = await _imagePicker.pickFromCamera(
      maxWidth: _kReceiptMaxDimension,
      maxHeight: _kReceiptMaxDimension,
    );
    if (file == null) return ReceiptValidationResult.cancelled;
    return _applyReceipt(file, source: _kReceiptSourceCamera);
  }

  /// Opens the gallery picker. On success, runs the same validation
  /// pipeline as [setReceipt] and surfaces the snackbar message on
  /// rejection. Telemetry: `expense_receipt_attached` with
  /// `source: 'gallery'` fires only on a successful attach.
  Future<ReceiptValidationResult> pickReceiptFromGallery() async {
    final file = await _imagePicker.pickFromGallery(
      maxWidth: _kReceiptMaxDimension,
      maxHeight: _kReceiptMaxDimension,
    );
    if (file == null) return ReceiptValidationResult.cancelled;
    return _applyReceipt(file, source: _kReceiptSourceGallery);
  }

  /// Validates [file] (size + MIME) and, on success, sets the draft's
  /// receipt and fires the attach event. On failure, sets
  /// `validationErrors['receipt']` for the host widget to surface
  /// via snackbar.
  ReceiptValidationResult _applyReceipt(XFile file, {required String source}) {
    final s = state;
    if (s is! Editing) return ReceiptValidationResult.notEditing;

    // Size check — read the file synchronously via XFile.length()
    // is async; we don't await here because the snackbar surface
    // wants an immediate verdict. Wrap in a sync method that uses
    // a best-effort heuristic for the test path (XFile.length()
    // resolves on the production picker but the fake injects a
    // pre-known byte count).
    return _validateAndApply(file, source: source);
  }

  ReceiptValidationResult _validateAndApply(
    XFile file, {
    required String source,
  }) {
    final s = state;
    if (s is! Editing) return ReceiptValidationResult.notEditing;

    // MIME-type check. Some Android pickers omit `mimeType`; fall
    // back to the file extension if so.
    if (!_isAcceptedMimeOrExtension(file)) {
      final errors = Map<String, String>.from(s.validationErrors)
        ..['receipt'] = _kMsgReceiptWrongType;
      state = Editing(step: s.step, draft: s.draft, validationErrors: errors);
      return ReceiptValidationResult.unsupportedType;
    }

    // Size check — we synchronously compute the size from the
    // underlying file. The fake picker in tests overrides this
    // via the XFile.length() method.
    final sizeBytes = _readFileSizeSync(file);
    if (sizeBytes > _kMaxReceiptBytes) {
      final errors = Map<String, String>.from(s.validationErrors)
        ..['receipt'] = _kMsgReceiptOversize;
      state = Editing(step: s.step, draft: s.draft, validationErrors: errors);
      return ReceiptValidationResult.oversize;
    }

    final errors = Map<String, String>.from(s.validationErrors)
      ..remove('receipt');
    final newDraft = s.draft.copyWith(receiptFile: file);
    state = Editing(step: s.step, draft: newDraft, validationErrors: errors);

    if (source != _kReceiptSourceUnknown) {
      _emitReceiptAttached(source: source, fileSizeBytes: sizeBytes);
    }

    // In edit mode, attaching a new file always counts as a change
    // (the receiptUrl will be overwritten with the new download
    // URL on save).
    _markChanged(ExpenseDoc.fieldReceiptUrl, file);

    return ReceiptValidationResult.ok;
  }

  bool _isAcceptedMimeOrExtension(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) {
      return _kAcceptedReceiptMimeTypes.contains(mime.toLowerCase());
    }
    final path = file.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = path.substring(dot);
    return _kAcceptedReceiptExtensions.contains(ext);
  }

  int _readFileSizeSync(XFile file) {
    // The picker returns an XFile wrapping a real on-disk file. We
    // use dart:io File.lengthSync() because XFile.length() is async,
    // and the size check must be synchronous so the validation
    // verdict appears in the same UI frame as the picker callback.
    // Widget tests inject XFiles backed by real (temp-dir) files;
    // pure-controller tests bypass this method via the
    // ReceiptValidationResult contract.
    try {
      return File(file.path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------
  // Step transitions (continued) — Back from Step 3 returns to Step 2
  // ---------------------------------------------------------------

  // ---------------------------------------------------------------
  // Save and discard
  // ---------------------------------------------------------------

  /// Persists the draft to Firestore via the repository.
  /// Editing → (Uploading)? → Saving → (Success | AddExpenseError).
  ///
  /// FR-EX-05: when the draft carries a `receiptFile` AND the upload
  /// is new (create mode, OR edit mode with a changed receipt), the
  /// chain runs Uploading → Saving — the receipt is uploaded to
  /// Firebase Storage at
  /// `receipts/friendships/{fid}/{eid}` and the resulting download
  /// URL is baked into the create-map (for create) or the
  /// update-map (for edit) before the Firestore write fires.
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

      // FR-EX-05: edit-mode receipt upload (Replace path) runs before
      // the Firestore update. The remove path is handled inside the
      // update branch — `receiptUrl: null` in the partial-update
      // map AND we delete the Storage object after the Firestore
      // write commits (architect §2.1).
      String? newReceiptUrl;
      final hasNewReceipt = draft.receiptFile != null;
      if (hasNewReceipt) {
        state = Uploading(draft: draft);
        try {
          newReceiptUrl = await _receiptStorage.uploadFriendshipReceipt(
            friendshipId: friendshipId,
            expenseId: initialExpenseId!,
            file: draft.receiptFile!,
          );
        } on ReceiptUploadError catch (err) {
          if (!mounted) return;
          _emitSaveFailed(_mapReceiptToCreateErrorType(err.type));
          state = AddExpenseError(
            draft: draft,
            errorType: ExpenseCreateErrorType.unknown,
            message: _kMsgReceiptUploadFailed,
          );
          return;
        }
        if (!mounted) return;
      }

      state = Saving(draft: draft);

      try {
        final shares = _computeShares(draft);
        // Resolve the value of receiptUrl to persist. Three cases:
        //  - new receipt picked → use the freshly-uploaded URL;
        //  - existing receipt removed → null;
        //  - existing receipt unchanged → preserve the original URL.
        final String? receiptUrlToWrite;
        if (newReceiptUrl != null) {
          receiptUrlToWrite = newReceiptUrl;
        } else if (draft.existingReceiptUrl == null &&
            _originalSnapshot!.receiptUrl != null) {
          receiptUrlToWrite = null;
        } else {
          receiptUrlToWrite = draft.existingReceiptUrl;
        }

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
          receiptUrl: receiptUrlToWrite,
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
        if (!mounted) return;

        // FR-EX-05: if the user removed the receipt (URL flipped to
        // null), purge the Storage object now that the Firestore
        // write has committed. Storage failures here are non-fatal
        // — the orphan-cleanup function (FUTURE) will reap any
        // strays.
        if (_originalSnapshot.receiptUrl != null && receiptUrlToWrite == null) {
          try {
            await _receiptStorage.deleteFriendshipReceipt(
              friendshipId: friendshipId,
              expenseId: initialExpenseId!,
            );
          } on ReceiptUploadError {
            // Swallow — the orphan-cleanup function handles this case.
          }
          if (!mounted) return;
        }

        _emitEditSaved(draft: draft, fieldsChanged: _changedFields);
        state = Success(
          expenseId: initialExpenseId!,
          action: SuccessAction.editSaved,
        );
      } on ExpenseUpdateError catch (err) {
        if (!mounted) return;
        _emitEditFailed(err.type);
        state = AddExpenseError(
          draft: draft,
          errorType: ExpenseCreateErrorType.unknown,
          message: _kMsgEditFailure,
        );
      }
      return;
    }

    // Create-mode branch.
    _emitStep2Completed(draft);

    // FR-EX-05: when a receipt is attached, pre-allocate the expense
    // ID so the Storage path `receipts/friendships/{fid}/{eid}` is
    // resolvable BEFORE the Firestore write. Then upload, then
    // createExpenseAtId with the URL populated.
    //
    // When no receipt is attached, use the existing zero-overhead
    // `createExpense` path which lets Firestore generate the ID.
    final hasReceipt = draft.receiptFile != null;

    if (!hasReceipt) {
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
        if (!mounted) return;
        _emitSaveSucceeded(
          draft: draft,
          expenseId: id,
          hasReceipt: false,
          receiptSizeBytes: null,
        );
        state = Success(expenseId: id);
      } on ExpenseCreateError catch (err) {
        if (!mounted) return;
        _emitSaveFailed(err.type);
        state = AddExpenseError(
          draft: draft,
          errorType: err.type,
          message: _kMsgSaveFailure,
        );
      } catch (err, st) {
        if (!mounted) return;
        _emitSaveFailed(ExpenseCreateErrorType.unknown);
        state = AddExpenseError(
          draft: draft,
          errorType: ExpenseCreateErrorType.unknown,
          message: _kMsgSaveFailure,
        );
        // Report to the framework's error reporter (Crashlytics hooks
        // into this via FlutterError.onError when wired in main.dart).
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
      return;
    }

    // Create with receipt path: allocate ID → upload → createExpenseAtId.
    final allocatedId = _repository.newExpenseId(friendshipId: friendshipId);
    final receiptFile = draft.receiptFile!;
    final receiptSize = _readFileSizeSync(receiptFile);

    state = Uploading(draft: draft);
    String url;
    try {
      url = await _receiptStorage.uploadFriendshipReceipt(
        friendshipId: friendshipId,
        expenseId: allocatedId,
        file: receiptFile,
      );
    } on ReceiptUploadError catch (err) {
      if (!mounted) return;
      _emitSaveFailed(_mapReceiptToCreateErrorType(err.type));
      state = AddExpenseError(
        draft: draft,
        errorType: ExpenseCreateErrorType.unknown,
        message: _kMsgReceiptUploadFailed,
      );
      return;
    }
    if (!mounted) return;

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
        receiptUrl: url,
      );
      await _repository.createExpenseAtId(
        friendshipId: friendshipId,
        expenseId: allocatedId,
        doc: doc,
      );
      if (!mounted) return;
      _emitSaveSucceeded(
        draft: draft,
        expenseId: allocatedId,
        hasReceipt: true,
        receiptSizeBytes: receiptSize,
      );
      state = Success(expenseId: allocatedId);
    } on ExpenseCreateError catch (err) {
      if (!mounted) return;
      _emitSaveFailed(err.type);
      state = AddExpenseError(
        draft: draft,
        errorType: err.type,
        message: _kMsgSaveFailure,
      );
    } catch (err, st) {
      if (!mounted) return;
      _emitSaveFailed(ExpenseCreateErrorType.unknown);
      state = AddExpenseError(
        draft: draft,
        errorType: ExpenseCreateErrorType.unknown,
        message: _kMsgSaveFailure,
      );
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

  ExpenseCreateErrorType _mapReceiptToCreateErrorType(
    ReceiptUploadErrorType type,
  ) {
    switch (type) {
      case ReceiptUploadErrorType.permissionDenied:
        return ExpenseCreateErrorType.permissionDenied;
      case ReceiptUploadErrorType.network:
        return ExpenseCreateErrorType.network;
      case ReceiptUploadErrorType.oversize:
      case ReceiptUploadErrorType.unsupportedType:
      case ReceiptUploadErrorType.unknown:
        return ExpenseCreateErrorType.unknown;
    }
  }

  /// Soft-deletes the original expense (edit mode only). Editing →
  /// Saving → (Success(deleted) | AddExpenseError).
  ///
  /// No-op in create mode (the absence of an
  /// [initialExpenseId] means there is nothing to soft-delete).
  /// Soft-deletes the expense. Returns `true` when the delete succeeded
  /// (the repository write completed), `false` on a delete error.
  ///
  /// The success/error [state] transition is best-effort: this is an
  /// autoDispose+family controller, so if it is disposed during the
  /// repository await the state is not updated — but the return value
  /// still reflects the outcome, so the caller can navigate reliably
  /// instead of re-reading a possibly-recreated provider state (D10).
  Future<bool> softDelete() async {
    if (!isEditMode || initialExpenseId == null) return false;
    final draft = _currentDraft();
    if (draft == null) return false;
    state = Saving(draft: draft);
    try {
      await _repository.softDeleteExpense(
        friendshipId: friendshipId,
        expenseId: initialExpenseId!,
      );
    } on ExpenseDeleteError catch (err) {
      if (mounted) {
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
      return false;
    }
    if (mounted) {
      _emitDeleteConfirmed(draft: draft);
      state = Success(
        expenseId: initialExpenseId!,
        action: SuccessAction.deleted,
      );
    }
    return true;
  }

  /// Returns the current draft from any non-terminal state, or null.
  ExpenseDraft? _currentDraft() {
    final s = state;
    return switch (s) {
      Editing(:final draft) => draft,
      Saving(:final draft) => draft,
      Uploading(:final draft) => draft,
      AddExpenseError(:final draft) => draft,
      Success() => null,
    };
  }

  /// Closes the sheet. Emits the matching abandonment event if the
  /// user had populated any step-1 fields (or had advanced to step 2
  /// / step 3). In edit mode, fires `expense_edit_abandoned` with
  /// the `had_changes` flag instead of the create-mode events.
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

    if (s.step == 3) {
      final openedAt = _step3OpenedAt ?? _step2OpenedAt ?? _step1OpenedAt;
      final ms = now.difference(openedAt).inMilliseconds;
      _emitStep3Abandoned(hadReceipt: draft.hasReceipt, timeSpentMs: ms);
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

  // ---------------------------------------------------------------
  // FR-EX-05 — Step 3 / receipt emit helpers (architect §2.6)
  // ---------------------------------------------------------------

  void _emitStep3Opened({required bool hasReceiptFromEdit}) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step3Opened,
      parameters: <String, Object>{
        ExpenseTelemetry.paramHasReceiptFromEdit: hasReceiptFromEdit,
      },
    );
  }

  void _emitReceiptAttached({
    required String source,
    required int fileSizeBytes,
  }) {
    _analytics.logEvent(
      name: ExpenseTelemetry.receiptAttached,
      parameters: <String, Object>{
        ExpenseTelemetry.paramSource: source,
        ExpenseTelemetry.paramFileSizeBytes: fileSizeBytes,
      },
    );
  }

  void _emitReceiptRemoved() {
    _analytics.logEvent(
      name: ExpenseTelemetry.receiptRemoved,
      parameters: const <String, Object>{},
    );
  }

  void _emitStep3Abandoned({
    required bool hadReceipt,
    required int timeSpentMs,
  }) {
    _analytics.logEvent(
      name: ExpenseTelemetry.step3Abandoned,
      parameters: <String, Object>{
        ExpenseTelemetry.paramHadReceipt: hadReceipt,
        ExpenseTelemetry.paramTimeSpentMs: timeSpentMs,
      },
    );
  }

  void _emitSaveSucceeded({
    required ExpenseDraft draft,
    required String expenseId,
    required bool hasReceipt,
    required int? receiptSizeBytes,
  }) {
    final params = <String, Object>{
      ExpenseTelemetry.paramContextType: 'friend',
      ExpenseTelemetry.paramAmountRange: ExpenseTelemetry.amountRangeFor(
        draft.amountPaise,
      ),
      ExpenseTelemetry.paramCategory: draft.category!.name,
      ExpenseTelemetry.paramSplitMethod: draft.splitMethod.name,
      ExpenseTelemetry.paramParticipantCount: 2,
      ExpenseTelemetry.paramHasReceipt: hasReceipt,
      ExpenseTelemetry.paramHasNotes: false,
      ExpenseTelemetry.paramIsOffline: false,
      ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
      ExpenseTelemetry.paramExpenseIdHash: hashId(expenseId),
    };
    if (hasReceipt && receiptSizeBytes != null) {
      params[ExpenseTelemetry.paramReceiptSizeBytes] = receiptSizeBytes;
    }
    _analytics.logEvent(
      name: ExpenseTelemetry.saveSucceeded,
      parameters: params,
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

  void _emitDeleteConfirmed({required ExpenseDraft draft}) {
    _analytics.logEvent(
      name: ExpenseTelemetry.deleteConfirmed,
      parameters: <String, Object>{
        ExpenseTelemetry.paramAmountRange: ExpenseTelemetry.amountRangeFor(
          draft.amountPaise,
        ),
        ExpenseTelemetry.paramParticipantCount: 2,
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
      case ExpenseDoc.fieldReceiptUrl:
        return snap.receiptUrl;
    }
    return null;
  }

  /// Field-aware equality used by `_markChanged`.
  ///
  /// - `date`: compares year/month/day only (the picker resets the
  ///   time component to midnight, but the original may carry a
  ///   server timestamp with non-zero time).
  /// - `splits`: compares element-by-element on (userId, sharePaise).
  /// - `receiptUrl`: a fresh `XFile` pick always counts as changed
  ///   (the existing URL will be overwritten on save); a `null`
  ///   draft value equals a `null` original (no change).
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
    if (field == ExpenseDoc.fieldReceiptUrl) {
      // A new XFile pick is always a change; otherwise compare URLs.
      if (a is XFile) return false;
      return a == b;
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
    required this.receiptUrl,
  });

  final int amountPaise;
  final String description;
  final ExpenseCategory category;
  final DateTime date;
  final String payerId;
  final List<Split> splits;
  final SplitMethod splitMethod;
  final String? receiptUrl;
}

/// Injectable wall-clock for [addExpenseControllerProvider], mirroring
/// `homeClockProvider`. Defaults to [DateTime.now]; overridden in widget and
/// golden tests so the Step 1 expense date renders deterministically (the
/// date defaults to "today", which would otherwise make dated goldens
/// non-deterministic across day boundaries).
final addExpenseClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

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
        receiptStorage: ref.watch(receiptStorageServiceProvider),
        imagePicker: ref.watch(imagePickerServiceProvider),
        clock: ref.watch(addExpenseClockProvider),
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
