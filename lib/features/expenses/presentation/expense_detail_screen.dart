import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/widgets/dialogs/obt_confirmation_dialog.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/application/expense_detail_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/receipt_fullscreen_viewer.dart';

/// Read-only detail screen for a single expense (SCR-22).
///
/// Reached from the friend-detail timeline; pushes an
/// [AddExpenseBottomSheet] in edit mode on the Edit AppBar action and
/// surfaces a destructive [OBTConfirmationDialog] on the Delete AppBar
/// action. Both AppBar actions are only rendered when the current user
/// created the expense (defence-in-depth — the rules currently
/// permit any friendship member to update or delete per architect §2.9
/// item 5, but the UI gates by creator).
///
/// The screen reads the expense via [expenseDetailProvider] (a
/// `FutureProvider.family`) and surfaces loading / error / empty /
/// loaded states inline.
class ExpenseDetailScreen extends ConsumerStatefulWidget {
  /// Creates an [ExpenseDetailScreen].
  const ExpenseDetailScreen({
    required this.friendshipId,
    required this.expenseId,
    required this.currentUserUid,
    required this.otherUserUid,
    super.key,
  });

  /// The friendship document ID.
  final String friendshipId;

  /// The expense document ID under
  /// `friendships/{friendshipId}/expenses/{expenseId}`.
  final String expenseId;

  /// The authenticated user's UID.
  final String currentUserUid;

  /// The friend's UID (the other party to the friendship).
  final String otherUserUid;

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  ExpenseDetailArgs get _args => ExpenseDetailArgs(
    friendshipId: widget.friendshipId,
    expenseId: widget.expenseId,
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expenseDetailProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense'),
        actions: _appBarActions(async),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorView(onRetry: _onRetry),
        data: (doc) {
          if (doc == null) return _MissingView(onBack: () => _onBack(context));
          return _ExpenseDetailBody(
            doc: doc,
            currentUserUid: widget.currentUserUid,
            otherUserUid: widget.otherUserUid,
          );
        },
      ),
    );
  }

  List<Widget> _appBarActions(AsyncValue<ExpenseDoc?> async) {
    final doc = async.valueOrNull;
    if (doc == null) return const <Widget>[];
    // UI-gate Edit / Delete on creator. The rules permit any member
    // to write per architect §2.9 item 5; this defence-in-depth check
    // keeps the affordances scoped.
    if (doc.createdBy != widget.currentUserUid) return const <Widget>[];
    return <Widget>[
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit',
        onPressed: () => _onEditTapped(doc),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: () => _onDeleteTapped(doc),
      ),
    ];
  }

  void _onRetry() {
    ref.invalidate(expenseDetailProvider(_args));
  }

  void _onBack(BuildContext context) {
    Navigator.of(context).maybePop();
  }

  Future<void> _onEditTapped(ExpenseDoc doc) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => AddExpenseBottomSheet(
        friendshipId: widget.friendshipId,
        currentUserUid: widget.currentUserUid,
        otherUserUid: widget.otherUserUid,
        initialExpense: doc,
        initialExpenseId: widget.expenseId,
      ),
    );
    if (!mounted) return;
    // After a successful edit or delete the bottom-sheet has already
    // popped; refresh the detail view by invalidating the provider.
    ref.invalidate(expenseDetailProvider(_args));
  }

  Future<void> _onDeleteTapped(ExpenseDoc doc) async {
    // Emit expense_delete_initiated directly via the analytics service
    // (NOT via the controller) — the controller is autoDispose+family
    // and would be GC'd between read calls, dropping the Saving state
    // it needs to transition through during softDelete().
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(
      analytics.logEvent(
        name: ExpenseTelemetry.deleteInitiated,
        parameters: <String, Object>{
          ExpenseTelemetry.paramContextType: 'friend',
          ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(
            widget.friendshipId,
          ),
          ExpenseTelemetry.paramExpenseIdHash: hashId(widget.expenseId),
        },
      ),
    );

    final confirmed = await OBTConfirmationDialog.show(
      context,
      title: 'Delete this expense?',
      body:
          'This will update balances for all participants. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!mounted) return;
    if (!confirmed) {
      unawaited(
        analytics.logEvent(
          name: ExpenseTelemetry.deleteCancelled,
          parameters: <String, Object>{
            ExpenseTelemetry.paramFriendshipIdHash: hashFriendshipId(
              widget.friendshipId,
            ),
            ExpenseTelemetry.paramExpenseIdHash: hashId(widget.expenseId),
          },
        ),
      );
      return;
    }

    // Build the controller via the family provider; the read keeps it
    // alive for the duration of the await chain.
    final args = AddExpenseArgs(
      friendshipId: widget.friendshipId,
      currentUserUid: widget.currentUserUid,
      otherUserUid: widget.otherUserUid,
      initialExpense: doc,
      initialExpenseId: widget.expenseId,
    );
    final controller = ref.read(addExpenseControllerProvider(args).notifier);
    await controller.softDelete();
    if (!mounted) return;
    final state = ref.read(addExpenseControllerProvider(args));
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (state is Success && state.action == SuccessAction.deleted) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Expense deleted.')),
      );
      await Navigator.of(context).maybePop();
    } else if (state is AddExpenseError) {
      messenger?.showSnackBar(SnackBar(content: Text(state.message)));
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load expense'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MissingView extends StatelessWidget {
  const _MissingView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Expense no longer exists'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDetailBody extends ConsumerWidget {
  const _ExpenseDetailBody({
    required this.doc,
    required this.currentUserUid,
    required this.otherUserUid,
  });

  final ExpenseDoc doc;
  final String currentUserUid;
  final String otherUserUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();
    final amount = formatInrFromPaise(doc.amountPaise);
    final isMyExpense = doc.payerId == currentUserUid;
    final payerLabel = isMyExpense ? 'You' : 'Friend';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  expenseCategoryIcon[doc.category] ?? Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.description, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      dateFmt.format(doc.date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Amount', value: amount),
          _DetailRow(label: 'Category', value: doc.category.name),
          _DetailRow(label: 'Paid by', value: payerLabel),
          _DetailRow(label: 'Split', value: _splitMethodLabel(doc.splitMethod)),
          const SizedBox(height: 16),
          Text('Splits', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final split in doc.splits)
            _DetailRow(
              label: split.userId == currentUserUid ? 'You' : 'Friend',
              value: formatInrFromPaise(split.sharePaise),
            ),
          // FR-EX-05: receipt thumbnail when present.
          if (doc.receiptUrl != null) ...[
            const SizedBox(height: 24),
            Text('Receipt', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _ReceiptTile(url: doc.receiptUrl!),
          ],
        ],
      ),
    );
  }

  String _splitMethodLabel(SplitMethod method) {
    switch (method) {
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// FR-EX-05: receipt thumbnail on the Expense Detail
/// screen. Constrained to 240 × 320 dp per SCR-21 line 325. Tap
/// opens the fullscreen viewer (`ReceiptFullscreenViewer.fromUrl`).
class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (_) => ReceiptFullscreenViewer.fromUrl(url),
        );
      },
      child: Semantics(
        label: 'Receipt image attached. Double-tap to view full size.',
        button: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 240,
            height: 320,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
