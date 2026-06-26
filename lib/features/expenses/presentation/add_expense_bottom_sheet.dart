import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/widgets/sheets/obt_stepper_sheet.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/presentation/steps/step_1_amount_details.dart';
import 'package:onebytwo/features/expenses/presentation/steps/step_2_split_and_payer.dart';
import 'package:onebytwo/features/expenses/presentation/steps/step_3_receipt_and_confirm.dart';

/// Root host for the Add Expense bottom sheet (SCR-19 + SCR-20).
///
/// Reads the [addExpenseControllerProvider] keyed by an
/// [AddExpenseArgs] tuple and renders Step 1 or Step 2 depending on
/// `Editing.step`. On `Success` / `AddExpenseError` transitions the
/// sheet shows the matching snackbar; on `Success` the sheet
/// auto-dismisses via [Navigator.pop].
///
/// FR-EX-06 — when [initialExpense] is non-null, the sheet runs in
/// edit mode: the header reads `'Edit Expense (N/2)'`, the success
/// snackbar reads `'Changes saved.'`, and the controller's
/// `changedFields` diff drives the CTA disabled state.
///
/// Future extraction note: the surrounding "sheet" chrome (drag
/// handle, rounded corners, padding) is rendered inline here for
/// FR-EX-01 — a follow-up extracts it as the reusable `OBTBottomSheet`
/// per the design-system catalogue. The presentation here matches
/// the catalogue's specified surface visually so the extraction is
/// mechanical.
class AddExpenseBottomSheet extends ConsumerStatefulWidget {
  /// Creates an [AddExpenseBottomSheet].
  const AddExpenseBottomSheet({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    this.initialExpense,
    this.initialExpenseId,
    super.key,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  /// When non-null, the sheet enters edit mode: the draft is seeded
  /// from this document, the controller computes a `changedFields`
  /// diff, and `save()` calls `updateExpense` instead of
  /// `createExpense`.
  final ExpenseDoc? initialExpense;

  /// Firestore document ID for [initialExpense]. Required when
  /// [initialExpense] is non-null.
  final String? initialExpenseId;

  @override
  ConsumerState<AddExpenseBottomSheet> createState() =>
      _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends ConsumerState<AddExpenseBottomSheet> {
  AddExpenseArgs get _args => AddExpenseArgs(
    friendshipId: widget.friendshipId,
    currentUserUid: widget.currentUserUid,
    otherUserUid: widget.otherUserUid,
    initialExpense: widget.initialExpense,
    initialExpenseId: widget.initialExpenseId,
  );

  bool get _isEditMode => widget.initialExpense != null;

  @override
  Widget build(BuildContext context) {
    ref.listen<AddExpenseState>(
      addExpenseControllerProvider(_args),
      _onStateChanged,
    );

    final state = ref.watch(addExpenseControllerProvider(_args));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AddExpenseState state) {
    final step = switch (state) {
      Editing(:final step) => step,
      Saving() => 3,
      Uploading() => 3,
      AddExpenseError() => 3,
      Success() => 3,
    };

    // The Add-expense 3-step sheet shell (Haldi 21): 28-radius top + grabber
    // + the visual stepper replacing the old `(N/3)` text counter. The
    // per-step routing and controller wiring are unchanged — each step body
    // owns its own Back / Next CTAs.
    return OBTStepperSheet(
      currentStep: step,
      totalSteps: 3,
      title: _isEditMode ? 'Edit Expense' : 'Add Expense',
      onClose: () => _onDismiss(context),
      stepBodies: <Widget>[
        Step1AmountDetails(args: _args),
        Step2SplitAndPayer(args: _args),
        Step3ReceiptAndConfirm(args: _args),
      ],
    );
  }

  void _onStateChanged(AddExpenseState? previous, AddExpenseState next) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (next is Success && previous is! Success) {
      // TODO(flutter-dev): replace with OBTSnackbar reusable from the
      // design-system catalogue (item 13). Inline rendering for FR-EX-01.
      messenger.showSnackBar(SnackBar(content: Text(_successMessage(next))));
      // Auto-dismiss the sheet on a successful save.
      Navigator.of(context).maybePop();
    } else if (next is AddExpenseError && previous is! AddExpenseError) {
      messenger.showSnackBar(SnackBar(content: Text(next.message)));
    }
  }

  String _successMessage(Success state) {
    switch (state.action) {
      case SuccessAction.createSaved:
        return 'Expense added.';
      case SuccessAction.editSaved:
        return 'Changes saved.';
      case SuccessAction.deleted:
        return 'Expense deleted.';
    }
  }

  void _onDismiss(BuildContext context) {
    ref.read(addExpenseControllerProvider(_args).notifier).discard();
    Navigator.of(context).maybePop();
  }
}
