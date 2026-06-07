import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/expense_draft.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/changed_field_indicator.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/receipt_fullscreen_viewer.dart';

/// Step 3 of the Add Expense bottom sheet (SCR-21 — receipt and
/// confirm). Renders, top-to-bottom:
///
/// 1. The receipt picker section. Empty state: dashed-border picker
///    area with "Take Photo" + "From Gallery" buttons (SCR-21 §State
///    1). Attached state: thumbnail preview (constrained to the
///    240 dp picker area) with "Replace" + "Remove" buttons (SCR-21
///    §State 2). Uploading state: progress spinner overlaid on the
///    thumbnail at 0.5 opacity (SCR-21 §State 3).
/// 2. The summary card. Read-only projection of every Step 1 + Step
///    2 field per SCR-21 §Components Used. Driven by the controller's
///    current draft.
/// 3. The Back + Save Expense (or Save Changes in edit mode) row.
///
/// Pure projection of [AddExpenseController] — the widget owns no
/// state of its own. Every interaction dispatches a setter on the
/// controller.
class Step3ReceiptAndConfirm extends ConsumerWidget {
  /// Creates a [Step3ReceiptAndConfirm].
  const Step3ReceiptAndConfirm({required this.args, super.key});

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

    final isUploading = state is Uploading;
    final isSaving = state is Saving;
    final isBusy = isUploading || isSaving;
    final receiptError = state is Editing
        ? state.validationErrors['receipt']
        : null;

    // Edit-mode no-op guard: if there are zero changed fields, the
    // Save Changes CTA is disabled (mirrors PR #46's Step 2 gate).
    final hasChanges =
        !controller.isEditMode || controller.changedFields.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Receipt', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // Receipt picker area.
        ChangedFieldIndicator(
          isChanged: controller.isFieldChanged(ExpenseDoc.fieldReceiptUrl),
          child: _ReceiptPickerArea(
            draft: draft,
            isUploading: isUploading,
            isBusy: isBusy,
            onTakePhoto: () => _onTakePhoto(context, controller),
            onFromGallery: () => _onFromGallery(context, controller),
            onReplace: () => _onReplace(context, controller),
            onRemove: controller.removeReceipt,
          ),
        ),
        if (receiptError != null) ...[
          const SizedBox(height: 8),
          _ReceiptValidationMessage(message: receiptError),
        ],
        const SizedBox(height: 24),
        // Summary card.
        Text('Summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _SummaryCard(
          draft: draft,
          currentUserUid: args.currentUserUid,
          otherUserUid: args.otherUserUid,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? null : controller.back,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SaveButton(
                isEditMode: controller.isEditMode,
                canSave: !isBusy && hasChanges,
                isBusy: isBusy,
                onPressed: controller.save,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onTakePhoto(
    BuildContext context,
    AddExpenseController controller,
  ) async {
    final result = await controller.pickReceiptFromCamera();
    if (!context.mounted) return;
    _maybeShowReceiptError(context, result);
  }

  Future<void> _onFromGallery(
    BuildContext context,
    AddExpenseController controller,
  ) async {
    final result = await controller.pickReceiptFromGallery();
    if (!context.mounted) return;
    _maybeShowReceiptError(context, result);
  }

  Future<void> _onReplace(
    BuildContext context,
    AddExpenseController controller,
  ) async {
    // Replace opens the gallery by default — matches the SCR-21
    // wireframe where "Replace" hands back to the gallery picker
    // rather than the camera (assumption: replace usually means
    // pick a different existing photo). Camera-source replace is
    // available via the picker dialog the gallery picker shows on
    // some platforms.
    final result = await controller.pickReceiptFromGallery();
    if (!context.mounted) return;
    _maybeShowReceiptError(context, result);
  }

  void _maybeShowReceiptError(
    BuildContext context,
    ReceiptValidationResult result,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    switch (result) {
      case ReceiptValidationResult.oversize:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Image is too large. Please choose a photo under 10 MB.',
            ),
          ),
        );
      case ReceiptValidationResult.unsupportedType:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This file format is not supported. '
              'Please use a JPEG or PNG image.',
            ),
          ),
        );
      case ReceiptValidationResult.ok:
      case ReceiptValidationResult.cancelled:
      case ReceiptValidationResult.notEditing:
        // No snackbar — ok is the happy path; cancelled / notEditing
        // are user-initiated no-ops.
        break;
    }
  }
}

class _ReceiptPickerArea extends StatelessWidget {
  const _ReceiptPickerArea({
    required this.draft,
    required this.isUploading,
    required this.isBusy,
    required this.onTakePhoto,
    required this.onFromGallery,
    required this.onReplace,
    required this.onRemove,
  });

  final ExpenseDraft draft;
  final bool isUploading;
  final bool isBusy;
  final VoidCallback onTakePhoto;
  final VoidCallback onFromGallery;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (draft.hasReceipt) {
      return _AttachedReceiptArea(
        draft: draft,
        isUploading: isUploading,
        isBusy: isBusy,
        onReplace: onReplace,
        onRemove: onRemove,
      );
    }
    return _EmptyReceiptArea(
      isBusy: isBusy,
      onTakePhoto: onTakePhoto,
      onFromGallery: onFromGallery,
    );
  }
}

class _EmptyReceiptArea extends StatelessWidget {
  const _EmptyReceiptArea({
    required this.isBusy,
    required this.onTakePhoto,
    required this.onFromGallery,
  });

  final bool isBusy;
  final VoidCallback onTakePhoto;
  final VoidCallback onFromGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to take a photo or pick from gallery',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onTakePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('From Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttachedReceiptArea extends StatelessWidget {
  const _AttachedReceiptArea({
    required this.draft,
    required this.isUploading,
    required this.isBusy,
    required this.onReplace,
    required this.onRemove,
  });

  final ExpenseDraft draft;
  final bool isUploading;
  final bool isBusy;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: isBusy ? null : () => _openFullscreen(context, draft),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 240,
                  width: double.infinity,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: _ReceiptThumbnail(draft: draft),
                ),
              ),
            ),
            if (isUploading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x80000000),
                  child: Center(
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onReplace,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Replace'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openFullscreen(BuildContext context, ExpenseDraft draft) {
    showDialog<void>(
      context: context,
      builder: (_) => ReceiptFullscreenViewer(draft: draft),
    );
  }
}

/// Renders the thumbnail from either the freshly-picked file
/// (`draft.receiptFile`) or the previously-attached URL
/// (`draft.existingReceiptUrl`).
class _ReceiptThumbnail extends StatelessWidget {
  const _ReceiptThumbnail({required this.draft});

  final ExpenseDraft draft;

  @override
  Widget build(BuildContext context) {
    final file = draft.receiptFile;
    if (file != null) {
      return Image.file(File(file.path), fit: BoxFit.cover);
    }
    final url = draft.existingReceiptUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined, size: 32)),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ReceiptValidationMessage extends StatelessWidget {
  const _ReceiptValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.draft,
    required this.currentUserUid,
    required this.otherUserUid,
  });

  final ExpenseDraft draft;
  final String currentUserUid;
  final String otherUserUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();
    final amount = formatInrFromPaise(draft.amountPaise);
    final payerLabel = draft.payerId == currentUserUid ? 'You' : 'Friend';
    final categoryLabel = draft.category?.name ?? '—';
    final splitMethodLabel = _splitMethodLabel(draft.splitMethod);
    final dateLabel = draft.date != null ? dateFmt.format(draft.date!) : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Amount', value: amount),
          _SummaryRow(label: 'Description', value: draft.description),
          _SummaryRow(label: 'Category', value: categoryLabel),
          _SummaryRow(label: 'Date', value: dateLabel),
          _SummaryRow(label: 'Paid by', value: payerLabel),
          _SummaryRow(label: 'Split', value: splitMethodLabel),
        ],
      ),
    );
  }

  String _splitMethodLabel(SplitMethod m) {
    switch (m) {
      case SplitMethod.equal:
        return 'Equal';
      case SplitMethod.exact:
        return 'Exact';
      case SplitMethod.percentage:
        return 'Percentage';
      case SplitMethod.unequal:
        return 'Unequal';
      case SplitMethod.shares:
        return 'Shares';
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Step 3 primary CTA. "Save Expense" in create mode; "Save Changes"
/// in edit mode. Disabled during Uploading / Saving (the host renders
/// the spinner via [isBusy]).
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isEditMode,
    required this.canSave,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isEditMode;
  final bool canSave;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isEditMode ? 'Save Changes' : 'Save Expense';
    final button = FilledButton(
      onPressed: canSave ? onPressed : null,
      child: isBusy
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
    if (isEditMode && !canSave && !isBusy) {
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
