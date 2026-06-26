import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/widgets/inputs/obt_amount_input.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/presentation/expense_date_format.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/changed_field_indicator.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/expense_category_grid.dart';

/// Step 1 of the Add Expense bottom sheet (SCR-19): amount, category,
/// description, optional date.
///
/// Pure projection of [AddExpenseController] — the widget owns no
/// state of its own. Every interaction dispatches a setter on the
/// controller; the controller decides validation + telemetry.
///
/// Future extraction note: the visual layout here uses inline
/// Material chrome; a follow-up refactors to OBTBottomSheet /
/// OBTPrimaryButton / OBTCategoryChip / OBTRupeeText per the
/// design-system catalogue.
class Step1AmountDetails extends ConsumerWidget {
  /// Creates a [Step1AmountDetails].
  const Step1AmountDetails({required this.args, super.key});

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
    final errors = state is Editing ? state.validationErrors : null;

    final canProceed =
        state is Editing &&
        draft != null &&
        draft.isStep1Complete &&
        (errors?.isEmpty ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount field — emits paise on every keystroke.
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldAmountPaise),
          child: OBTAmountInput(
            key: const Key('expense_amount_input'),
            autoFocus: false,
            onChanged: controller.setAmount,
            errorText: errors?['amount'],
            enabled: state is Editing,
          ),
        ),
        const SizedBox(height: 16),

        // Category grid — 8 chips, single-select.
        Text('Category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldCategory),
          child: ExpenseCategoryGrid(
            selected: draft?.category,
            onSelected: controller.setCategory,
          ),
        ),
        const SizedBox(height: 16),

        // Description.
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldDescription),
          child: TextField(
            key: const Key('expense_description_input'),
            maxLength: 100,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            enabled: state is Editing,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'e.g. Dinner at Dosa Plaza',
              errorText: errors?['description'],
            ),
            onChanged: controller.setDescription,
          ),
        ),
        const SizedBox(height: 16),

        // Date (defaults to today — controller initialises).
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldDate),
          child: _DateField(
            date: draft?.date,
            errorText: errors?['date'],
            enabled: state is Editing,
            onPick: controller.setDate,
          ),
        ),
        const SizedBox(height: 24),

        // Next button.
        FilledButton(
          onPressed: canProceed ? controller.proceedToStep2 : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.errorText,
    required this.enabled,
    required this.onPick,
  });

  final DateTime? date;
  final String? errorText;
  final bool enabled;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final formatted = date == null ? 'Today' : formatExpenseIstDate(date!);
    return InputDecorator(
      decoration: InputDecoration(labelText: 'Date', errorText: errorText),
      child: Row(
        children: [
          Expanded(child: Text(formatted)),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pick date',
            onPressed: enabled
                ? () async {
                    final today = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? today,
                      firstDate: DateTime(today.year - 5),
                      lastDate: today,
                    );
                    if (picked != null) {
                      onPick(picked);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
