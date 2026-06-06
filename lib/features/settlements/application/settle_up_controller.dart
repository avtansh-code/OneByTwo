import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_state.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settle_up_draft.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Driver for the Settle Up bottom sheet (FR-SE-05 / FR-SE-06 /
/// FR-SE-07).
///
/// Riverpod 2.x [StateNotifier] that mirrors the
/// `AddExpenseController` precedent: sealed-state hierarchy, one
/// `_emit*` helper per telemetry event, repository + analytics
/// injected via constructor. UI widgets are pure projections.
///
/// Architect Notes §2.7: telemetry single-fire discipline — every
/// event fires at most once per transition. Re-emission is bounded
/// by state-machine transitions (Saving → Success → no re-entry).
class SettleUpController extends StateNotifier<SettleUpState> {
  /// Creates a [SettleUpController]. Initial state is
  /// [SettleUpEditing] with the suggested amount pre-filled.
  SettleUpController({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherDisplayName,
    required this.suggestedAmountPaise,
    required SettlementRepository repository,
    required AnalyticsService analytics,
    DateTime Function()? clock,
  }) : _repository = repository,
       _analytics = analytics,
       _clock = clock ?? DateTime.now,
       super(
         SettleUpEditing(
           draft: SettleUpDraft.initial(
             suggestedAmountPaise: suggestedAmountPaise,
             date: (clock ?? DateTime.now)(),
           ),
         ),
       );

  /// The friendship document ID — `uid-a_uid-b` sorted lexicographically.
  final String friendshipId;

  /// The authenticated user's UID — written as `fromUserId` on the
  /// settlement doc.
  final String currentUserUid;

  /// The friend's UID — written as `toUserId` on the settlement doc.
  final String otherUserUid;

  /// The friend's display name — used by the sheet header.
  final String otherDisplayName;

  /// The simplified-debts suggestion in paise (set at construction
  /// time). The draft's amountPaise pre-fills to this value.
  final int suggestedAmountPaise;

  final SettlementRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _clock;

  // ---------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------

  /// Updates the draft amount (paise). Surfaces validation errors
  /// (amount <= 0 or > suggested) without firing telemetry.
  void setAmount(int paise) {
    final s = state;
    if (s is! SettleUpEditing) return;
    final next = s.draft.copyWith(amountPaise: paise);
    state = SettleUpEditing(draft: next, validationErrors: next.validate());
  }

  /// Updates the draft date.
  void setDate(DateTime date) {
    final s = state;
    if (s is! SettleUpEditing) return;
    final next = s.draft.copyWith(date: date);
    state = SettleUpEditing(draft: next, validationErrors: next.validate());
  }

  /// Updates the draft note. Passing `null` explicitly clears the
  /// note (the canonical empty form).
  void setNote(String? note) {
    final s = state;
    if (s is! SettleUpEditing) return;
    final next = note == null
        ? s.draft.copyWith(clearNote: true)
        : s.draft.copyWith(note: note);
    state = SettleUpEditing(draft: next, validationErrors: next.validate());
  }

  // ---------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------

  /// Persists the draft to Firestore via the repository.
  /// Editing → Saving → (SettleUpSuccess | SettleUpError).
  ///
  /// If the draft is invalid at the time of the call, fires
  /// `settle_up_validation_failed` for the first failing field and
  /// returns without attempting the Firestore write.
  Future<void> save() async {
    final draft = _resolveDraft(state);
    if (draft == null) return;

    final validationErrors = draft.validate();
    if (validationErrors.isNotEmpty) {
      _emitValidationFailed(validationErrors);
      return;
    }

    state = SettleUpSaving(draft: draft);

    try {
      final doc = SettlementDoc(
        settlementId: 'unused-on-create',
        fromUserId: currentUserUid,
        toUserId: otherUserUid,
        amountPaise: draft.amountPaise,
        contextType: 'friendship',
        contextId: friendshipId,
        date: draft.date,
        note: draft.canonicalNote,
        method: 'manual',
        verificationStatus: 'unverified',
        currency: 'INR',
        createdAt: _clock(),
        deleted: false,
      );
      final id = await _repository.createSettlement(doc: doc);
      _emitSettlementRecorded(draft: draft, settlementId: id);
      state = SettleUpSuccess(settlementId: id, isPartial: draft.isPartial);
    } on SettlementCreateError catch (err) {
      _emitError(err.type);
      state = SettleUpError(
        draft: draft,
        errorType: err.type,
        message: err.type.userFacingMessage,
      );
    } catch (err, st) {
      _emitError(SettlementCreateErrorType.unknown);
      state = SettleUpError(
        draft: draft,
        errorType: SettlementCreateErrorType.unknown,
        message: SettlementCreateErrorType.unknown.userFacingMessage,
      );
      // Surface to FlutterError so Crashlytics / logging breadcrumbs
      // capture the unexpected exception. The state-transition + the
      // typed error are already in place for the UI.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: err,
          stack: st,
          library: 'settlements',
          context: ErrorDescription(
            'unexpected error during SettleUpController.save()',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------

  SettleUpDraft? _resolveDraft(SettleUpState s) {
    return switch (s) {
      SettleUpEditing(:final draft) => draft,
      SettleUpError(:final draft) => draft,
      _ => null,
    };
  }

  void _emitSettlementRecorded({
    required SettleUpDraft draft,
    required String settlementId,
  }) {
    _analytics.logEvent(
      name: SettleUpTelemetry.settlementRecorded,
      parameters: <String, Object>{
        SettleUpTelemetry.paramContextType: 'friendship',
        SettleUpTelemetry.paramAmountRange: SettleUpTelemetry.amountRangeFor(
          draft.amountPaise,
        ),
        SettleUpTelemetry.paramIsPartial: draft.isPartial,
        SettleUpTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
        SettleUpTelemetry.paramSettlementIdHash: hashId(settlementId),
      },
    );
  }

  void _emitError(SettlementCreateErrorType type) {
    _analytics.logEvent(
      name: SettleUpTelemetry.errorEvent,
      parameters: <String, Object>{
        SettleUpTelemetry.paramErrorCode: type.telemetryErrorCode,
        SettleUpTelemetry.paramContextType: 'friendship',
        SettleUpTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
      },
    );
  }

  void _emitValidationFailed(Map<String, String> errors) {
    // Fire ONCE for the first failing field, in priority order. The
    // controller does not emit multiple events per Save tap because
    // the UI surfaces all errors inline already.
    final field = errors.containsKey('amount') ? 'amount' : errors.keys.first;
    _analytics.logEvent(
      name: SettleUpTelemetry.validationFailed,
      parameters: <String, Object>{
        SettleUpTelemetry.paramField: field,
        SettleUpTelemetry.paramReason: errors[field] ?? '',
      },
    );
  }
}

/// Argument tuple for [settleUpControllerProvider].
@immutable
class SettleUpArgs {
  /// Creates a [SettleUpArgs].
  const SettleUpArgs({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherDisplayName,
    required this.suggestedAmountPaise,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  /// Friend display name (rendered in the sheet header).
  final String otherDisplayName;

  /// The pre-fill amount (positive paise).
  final int suggestedAmountPaise;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettleUpArgs &&
        other.friendshipId == friendshipId &&
        other.currentUserUid == currentUserUid &&
        other.otherUserUid == otherUserUid &&
        other.otherDisplayName == otherDisplayName &&
        other.suggestedAmountPaise == suggestedAmountPaise;
  }

  @override
  int get hashCode => Object.hash(
    friendshipId,
    currentUserUid,
    otherUserUid,
    otherDisplayName,
    suggestedAmountPaise,
  );
}

/// Family provider keyed by friendship + user-pair tuple + suggestion.
/// The host widget (`SettleUpBottomSheet`) reads via this provider;
/// the widget tests override `settlementRepositoryProvider` and
/// `analyticsServiceProvider`, leaving the controller construction
/// itself to flow through this binding.
final settleUpControllerProvider = StateNotifierProvider.autoDispose
    .family<SettleUpController, SettleUpState, SettleUpArgs>((ref, args) {
      return SettleUpController(
        friendshipId: args.friendshipId,
        currentUserUid: args.currentUserUid,
        otherUserUid: args.otherUserUid,
        otherDisplayName: args.otherDisplayName,
        suggestedAmountPaise: args.suggestedAmountPaise,
        repository: ref.watch(settlementRepositoryProvider),
        analytics: ref.watch(analyticsServiceProvider),
      );
    });
