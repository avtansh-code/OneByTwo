import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/presentation/steps/step_1_amount_details.dart';
import 'package:onebytwo/features/expenses/presentation/steps/step_2_split_and_payer.dart';

/// Root host for the Add Expense bottom sheet (SCR-19 + SCR-20).
///
/// Reads the [addExpenseControllerProvider] keyed by an
/// [AddExpenseArgs] tuple and renders Step 1 or Step 2 depending on
/// `Editing.step`. On `Success` / `AddExpenseError` transitions the
/// sheet shows the matching snackbar; on `Success` the sheet
/// auto-dismisses via [Navigator.pop].
///
/// Future extraction note: the surrounding "sheet" chrome (drag
/// handle, rounded corners, padding) is rendered inline here for
/// PR #38 — a follow-up extracts it as the reusable `OBTBottomSheet`
/// per the design-system catalogue. The presentation here matches
/// the catalogue's specified surface visually so the extraction is
/// mechanical.
class AddExpenseBottomSheet extends ConsumerStatefulWidget {
  /// Creates an [AddExpenseBottomSheet].
  const AddExpenseBottomSheet({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    super.key,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  @override
  ConsumerState<AddExpenseBottomSheet> createState() =>
      _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends ConsumerState<AddExpenseBottomSheet> {
  AddExpenseArgs get _args => AddExpenseArgs(
    friendshipId: widget.friendshipId,
    currentUserUid: widget.currentUserUid,
    otherUserUid: widget.otherUserUid,
  );

  @override
  Widget build(BuildContext context) {
    ref.listen<AddExpenseState>(
      addExpenseControllerProvider(_args),
      _onStateChanged,
    );

    final state = ref.watch(addExpenseControllerProvider(_args));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AddExpenseState state) {
    final step = switch (state) {
      Editing(:final step) => step,
      Saving() => 2,
      AddExpenseError() => 2,
      Success() => 2,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _SheetHeader(step: step, onDismiss: () => _onDismiss(context)),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: step == 1
                ? Step1AmountDetails(args: _args)
                : Step2SplitAndPayer(args: _args),
          ),
        ),
      ],
    );
  }

  void _onStateChanged(AddExpenseState? previous, AddExpenseState next) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (next is Success && previous is! Success) {
      // TODO(avtansh): replace with the OBTSnackbar reusable.
      messenger.showSnackBar(const SnackBar(content: Text('Expense added.')));
      // Auto-dismiss the sheet on a successful save.
      Navigator.of(context).maybePop();
    } else if (next is AddExpenseError && previous is! AddExpenseError) {
      messenger.showSnackBar(SnackBar(content: Text(next.message)));
    }
  }

  void _onDismiss(BuildContext context) {
    ref.read(addExpenseControllerProvider(_args).notifier).discard();
    Navigator.of(context).maybePop();
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.step, required this.onDismiss});

  final int step;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Add Expense ($step/3)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
