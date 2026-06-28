import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/inputs/obt_segmented_split_control.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/expense_draft.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/changed_field_indicator.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/split_row.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/split_validation_message.dart';

/// Step 2 of the Add Expense bottom sheet (SCR-20): the segmented
/// split-method control, per-member split rows (for exact), payer toggle,
/// Back + Next.
///
/// Pure projection of [AddExpenseController]. The split-method selector is
/// the shared Haldi [OBTSegmentedSplitControl] — `equal` / `exact` are the
/// enabled methods (FR-EX-01); the three reserved methods render disabled
/// ("Coming soon"). The control surfaces the live "adds up" (green) /
/// over-under (red) validation off `totalPaise` vs `allocatedPaise`, and
/// Next is disabled until the split sums exactly to the total (AC-2,
/// Invariant 1 — integer paise, no float, no `/100`).
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
      Uploading(:final draft) => draft,
      AddExpenseError(:final draft) => draft,
      _ => null,
    };
    if (draft == null) {
      return const SizedBox.shrink();
    }
    final errors = state is Editing ? state.validationErrors : null;
    final isSaving = state is Saving;
    // The split rows' running allocation (integer paise — equal sums to the
    // total by construction; exact is the sum of the entered shares). Drives
    // the OBTSegmentedSplitControl live validation and the Next gate.
    final allocatedPaise =
        _shareFor(args.currentUserUid, draft) +
        _shareFor(args.otherUserUid, draft);
    final balanced = allocatedPaise == draft.amountPaise;
    // FR-EX-05: Step 2 advances to Step 3; the save itself fires from Step
    // 3. The CTA is "Next". Next is gated on the split summing exactly to the
    // total (AC-2 — `balanced`) in addition to the controller's splits
    // validation, so an off-total exact split cannot advance.
    final canAdvance =
        !isSaving &&
        (errors?['splits'] == null) &&
        draft.amountPaise > 0 &&
        balanced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Split method', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldSplitMethod),
          child: OBTSegmentedSplitControl(
            selected: draft.splitMethod,
            enabledMethods: const <SplitMethod>{
              SplitMethod.equal,
              SplitMethod.exact,
            },
            onMethodSelected: controller.setSplitMethod,
            totalPaise: draft.amountPaise,
            allocatedPaise: allocatedPaise,
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
              style: OBTText.amount(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Back + Next row.
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
              child: _NextButton(
                canAdvance: canAdvance,
                isSaving: isSaving,
                onPressed: controller.proceedToStep3,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final background = selected
        ? colors.primary
        : colors.surfaceContainerHighest;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: AnimatedContainer(
          duration: AppTheme.motionDurationShort,
          curve: AppTheme.motionCurve,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? background : obtColors.disabledFill,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled ? foreground : obtColors.disabledText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 2 advance CTA. The label is always "Next". The hasChanges
/// gate has been removed for FR-EX-05 — the user is free to advance
/// to Step 3 (the summary) even without modifications in edit mode;
/// the no-op guard then sits on Step 3's "Save Changes" CTA per
/// SCR-22 §Accessibility line 510.
class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.canAdvance,
    required this.isSaving,
    required this.onPressed,
  });

  final bool canAdvance;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: canAdvance ? onPressed : null,
      child: isSaving
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Next'),
    );
  }
}
