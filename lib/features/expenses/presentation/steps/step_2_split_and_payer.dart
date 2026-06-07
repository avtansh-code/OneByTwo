import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/expense_draft.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/changed_field_indicator.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/split_row.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/split_validation_message.dart';

/// Step 2 of the Add Expense bottom sheet (SCR-20): split method
/// chips, per-member split rows (for exact), payer toggle, Back +
/// Save.
///
/// Pure projection of [AddExpenseController]. The three deferred
/// split methods (unequal / percentage / shares) render as disabled
/// chips with a "Coming soon" tooltip per AC-7.
class Step2SplitAndPayer extends ConsumerWidget {
  /// Creates a [Step2SplitAndPayer].
  const Step2SplitAndPayer({required this.args, super.key});

  /// Controller key.
  final AddExpenseArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addExpenseControllerProvider(args));
    final controller = ref.read(addExpenseControllerProvider(args).notifier);

    final draft = switch (state) {
      Editing(:final draft) => draft,
      Saving(:final draft) => draft,
      AddExpenseError(:final draft) => draft,
      _ => null,
    };
    if (draft == null) {
      return const SizedBox.shrink();
    }
    final errors = state is Editing ? state.validationErrors : null;
    final isSaving = state is Saving;
    // FR-EX-06: in edit mode the CTA is additionally gated by
    // changedFields.isNotEmpty so an unchanged edit cannot trigger
    // a no-op write (the controller has the load-bearing guard).
    final hasChanges =
        !controller.isEditMode || controller.changedFields.isNotEmpty;
    final canSave =
        !isSaving &&
        (errors?['splits'] == null) &&
        draft.amountPaise > 0 &&
        hasChanges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Split method', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldSplitMethod),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SplitMethod.values
                .map(
                  (m) => _SplitMethodChip(
                    method: m,
                    selected: draft.splitMethod == m,
                    enabled: isSplitMethodEnabled(m) && !isSaving,
                    onTap: () => controller.setSplitMethod(m),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),

        // Split rows: equal shows the computed split (read-only),
        // exact shows editable rows.
        Text(
          draft.splitMethod == SplitMethod.equal
              ? 'Split equally'
              : 'Enter each share',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldSplits),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SplitRow(
                label: 'You',
                method: draft.splitMethod,
                paise: _shareFor(args.currentUserUid, draft),
                onChanged: draft.splitMethod == SplitMethod.exact
                    ? (paise) => _setExact(controller, draft, 0, paise)
                    : null,
              ),
              const SizedBox(height: 8),
              SplitRow(
                label: 'Friend',
                method: draft.splitMethod,
                paise: _shareFor(args.otherUserUid, draft),
                onChanged: draft.splitMethod == SplitMethod.exact
                    ? (paise) => _setExact(controller, draft, 1, paise)
                    : null,
              ),
            ],
          ),
        ),
        if (errors?['splits'] != null) ...[
          const SizedBox(height: 8),
          SplitValidationMessage(message: errors!['splits']!),
        ],
        const SizedBox(height: 16),

        // Payer toggle.
        Text('Paid by', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldPayerId),
          child: Row(
            children: [
              Expanded(
                child: _PayerChoice(
                  label: 'You',
                  selected: draft.payerId == args.currentUserUid,
                  enabled: !isSaving,
                  onTap: () => controller.setPayerId(args.currentUserUid),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PayerChoice(
                  label: 'Friend',
                  selected: draft.payerId == args.otherUserUid,
                  enabled: !isSaving,
                  onTap: () => controller.setPayerId(args.otherUserUid),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Total summary using formatInrFromPaise.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: Theme.of(context).textTheme.titleMedium),
            Text(
              formatInrFromPaise(draft.amountPaise),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Back + Save row.
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isSaving ? null : controller.back,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SaveButton(
                isEditMode: controller.isEditMode,
                hasChanges: hasChanges,
                canSave: canSave,
                isSaving: isSaving,
                onPressed: controller.save,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _shareFor(String userId, ExpenseDraft draft) {
    // Single source of truth: delegate to computeSplits() so any future
    // change to the splitter's rounding policy (banker's rounding,
    // remainder-to-even, etc.) is reflected here automatically.
    // Without this delegation the UI would silently diverge from the
    // saved Firestore document.
    if (draft.splitMethod == SplitMethod.equal) {
      final splits = computeSplits(
        method: SplitMethod.equal,
        totalPaise: draft.amountPaise,
        memberUids: <String>[args.currentUserUid, args.otherUserUid],
      );
      for (final s in splits) {
        if (s.userId == userId) return s.sharePaise;
      }
      return 0;
    }
    final shares = draft.exactShares;
    if (shares.isEmpty) return 0;
    if (userId == args.currentUserUid) return shares[0];
    return shares.length > 1 ? shares[1] : 0;
  }

  void _setExact(
    AddExpenseController controller,
    ExpenseDraft draft,
    int index,
    int paise,
  ) {
    final current = List<int>.from(draft.exactShares);
    while (current.length < 2) {
      current.add(0);
    }
    current[index] = paise;
    controller.setExactShares(current);
  }
}

class _SplitMethodChip extends StatelessWidget {
  const _SplitMethodChip({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SplitMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // TODO(flutter-dev): replace with the reusable OBTCategoryChip
    // (sibling of expense-category chips). Inline rendering for FR-EX-01.
    final label = _labelFor(method);
    final chip = ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
    );
    if (!enabled) {
      return Tooltip(message: 'Coming soon', child: chip);
    }
    return chip;
  }

  String _labelFor(SplitMethod m) {
    switch (m) {
      case SplitMethod.equal:
        return 'Equal';
      case SplitMethod.exact:
        return 'Exact';
      case SplitMethod.unequal:
        return 'Unequal';
      case SplitMethod.percentage:
        return 'Percentage';
      case SplitMethod.shares:
        return 'Shares';
    }
  }
}

class _PayerChoice extends StatelessWidget {
  const _PayerChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
    );
  }
}

/// Step-2 primary CTA. In create mode the label is "Save"; in edit mode
/// it flips to "Save Changes". When the controller is in edit mode and
/// the no-op guard has disabled the button (no fields changed), the
/// button is wrapped in `Semantics(label: 'Save changes, no
/// modifications made.')` per SCR-22 §Accessibility line 510 (AC-3).
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isEditMode,
    required this.hasChanges,
    required this.canSave,
    required this.isSaving,
    required this.onPressed,
  });

  final bool isEditMode;
  final bool hasChanges;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isEditMode ? 'Save Changes' : 'Save';
    final button = FilledButton(
      onPressed: canSave ? onPressed : null,
      child: isSaving
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
    if (isEditMode && !hasChanges) {
      return Semantics(
        label: 'Save changes, no modifications made.',
        button: true,
        enabled: false,
        child: button,
      );
    }
    return button;
  }
}
