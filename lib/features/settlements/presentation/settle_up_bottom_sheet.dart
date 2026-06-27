import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/widgets/sheets/obt_settle_up_sheet.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_controller.dart';
import 'package:onebytwo/features/settlements/application/settle_up_state.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';

/// How long the in-sheet success moment lingers before the sheet
/// auto-dismisses, so the check + the single haptic register before the
/// route closes (DC-08 AC-1, replacing the old auto-dismiss + snackbar).
const Duration _successDismissDelay = Duration(milliseconds: 1400);

/// Root host for the Settle Up bottom sheet (SCR-23 / FR-SE-05).
///
/// Reads the [settleUpControllerProvider] keyed by a [SettleUpArgs]
/// tuple and projects each state onto the shared [OBTSettleUpSheet]
/// (DC-08 rebuild): the suggested-payment header (the **single**
/// `simplifiedBalances` projection read — never a debt graph, never a
/// client write; Invariant 2), the editable amount via the sheet's
/// `OBTAmountInput` (the integer-paise `onChanged(int paise)` contract is
/// untouched; Invariant 1), the inert "Pay via UPI" slot, and the
/// success moment.
///
/// State mapping (Architect ruling):
/// - `SettleUpEditing` → the editing surface, with `amountErrorText` read
///   from the `amount` validation error.
/// - `SettleUpSaving` → `isSaving` (the CTA shows "Recording…").
/// - `SettleUpSuccess` → `isSuccess` renders the in-sheet success moment
///   (check + a single haptic from the component), then the sheet
///   auto-dismisses after [_successDismissDelay].
/// - `SettleUpError` → the editing surface stays open and the typed
///   error message is surfaced via the snackbar the controller drives.
///
/// Telemetry single-fire discipline (Architect Notes §2.7):
/// `settle_up_screen_viewed` fires exactly once on first paint of the
/// body via a post-frame callback, gated by `_loggedView`.
class SettleUpBottomSheet extends ConsumerStatefulWidget {
  /// Creates a [SettleUpBottomSheet].
  const SettleUpBottomSheet({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherDisplayName,
    required this.suggestedAmountPaise,
    this.currentUserPhotoUrl,
    this.otherUserPhotoUrl,
    this.source = 'friend_detail',
    super.key,
  });

  /// Telemetry source token for `settle_up_screen_viewed.source`
  /// (`SettleUpTelemetry.paramSource`). Defaults to `'friend_detail'`
  /// (the original PR #43 entry point); the Home dashboard passes
  /// `'home_dashboard'` (the token pre-declared in
  /// `settle_up_telemetry.dart`). A non-identifying enum token — no
  /// hashing required.
  final String source;

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  /// Friend display name (for the header).
  final String otherDisplayName;

  /// Pre-fill amount in paise.
  final int suggestedAmountPaise;

  /// Optional current user avatar URL.
  final String? currentUserPhotoUrl;

  /// Optional friend avatar URL.
  final String? otherUserPhotoUrl;

  @override
  ConsumerState<SettleUpBottomSheet> createState() =>
      _SettleUpBottomSheetState();
}

class _SettleUpBottomSheetState extends ConsumerState<SettleUpBottomSheet> {
  bool _loggedView = false;
  Timer? _dismissTimer;

  SettleUpArgs get _args => SettleUpArgs(
    friendshipId: widget.friendshipId,
    currentUserUid: widget.currentUserUid,
    otherUserUid: widget.otherUserUid,
    otherDisplayName: widget.otherDisplayName,
    suggestedAmountPaise: widget.suggestedAmountPaise,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _logViewedOnce());
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _logViewedOnce() {
    if (_loggedView) return;
    _loggedView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: SettleUpTelemetry.screenViewed,
            parameters: <String, Object>{
              SettleUpTelemetry.paramContextType: 'friendship',
              SettleUpTelemetry.paramSource: widget.source,
              SettleUpTelemetry.paramFriendshipIdHash: hashFriendshipId(
                widget.friendshipId,
              ),
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettleUpState>(
      settleUpControllerProvider(_args),
      _onStateChanged,
    );

    final state = ref.watch(settleUpControllerProvider(_args));

    final amountErrorText = switch (state) {
      SettleUpEditing(:final validationErrors) => validationErrors['amount'],
      _ => null,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: OBTSettleUpSheet(
        payerDisplayName: 'You',
        payeeDisplayName: widget.otherDisplayName,
        payerPhotoUrl: widget.currentUserPhotoUrl,
        payeePhotoUrl: widget.otherUserPhotoUrl,
        suggestedAmountPaise: widget.suggestedAmountPaise,
        isSaving: state is SettleUpSaving,
        isSuccess: state is SettleUpSuccess,
        amountErrorText: amountErrorText,
        onAmountChanged: (paise) => ref
            .read(settleUpControllerProvider(_args).notifier)
            .setAmount(paise),
        onRecord: () =>
            ref.read(settleUpControllerProvider(_args).notifier).save(),
      ),
    );
  }

  void _onStateChanged(SettleUpState? previous, SettleUpState next) {
    if (next is SettleUpSuccess && previous is! SettleUpSuccess) {
      // Let the in-sheet success moment (check + single haptic, rendered by
      // OBTSettleUpSheet) register, then dismiss the sheet.
      _dismissTimer?.cancel();
      _dismissTimer = Timer(_successDismissDelay, () {
        if (mounted) Navigator.of(context).maybePop();
      });
    } else if (next is SettleUpError && previous is! SettleUpError) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(next.message)));
    }
  }
}
