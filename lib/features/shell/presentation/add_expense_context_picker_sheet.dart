import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_flow.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_list_tile.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';

/// Modal bottom sheet hosting the Add-Expense context picker
/// (SCR-08 Step 1).
///
/// Two sections:
///   - **Friends:** consumes `friendsListProvider` and renders the
///     populated / empty / loading / error sub-states. Selecting a
///     friend fires `expense_context_selected{context_type: 'friend'}`,
///     dismisses the picker, and opens the existing
///     [AddExpenseBottomSheet] with the friend's
///     `(friendshipId, currentUserUid, otherUserUid)` tuple.
///   - **Groups:** a single "Coming in Sprint 3" stub row per
///     `components.md §3` disabled-state token. Tapping it shows a
///     SnackBar, fires
///     `expense_context_selected{context_type: 'group'}`, and KEEPS
///     the picker open (deferred per the architect's call —
///     `docs/sprint-zero/stories/FR-HD-04-persistent-fab-and-context-picker.md`
///     Architect Notes §2.3).
///
/// **Invariant compliance.**
///   - **Invariant 1 (paise integers):** no monetary values flow
///     through the picker. The `FriendListTile` consumes `int paise`
///     from `FriendListItem.netBalancePaise` and renders via the
///     existing `BalancePill` (formats via `formatInrFromPaise`).
///   - **Invariant 2 (`simplifiedBalances` server-only):** the picker
///     reads `friendsListProvider` (which projects the field deeper
///     in the pipeline) but the picker itself does NOT touch the
///     field name.
///
/// **PII guard (ADR-0013).** The `expense_context_selected` payload
/// carries only `context_type` ∈ {`friend`, `group`}. NO uid,
/// friendship-id, or hashed identifier. See
/// `docs/design/07-technical/telemetry-plan.md §1.3` line 89.
class AddExpenseContextPickerSheet extends ConsumerWidget {
  /// Creates an [AddExpenseContextPickerSheet].
  const AddExpenseContextPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Add Expense', style: theme.textTheme.titleLarge),
              ),
              const _SectionHeader(label: 'Friends'),
              _FriendsSection(state: friendsAsync),
              const SizedBox(height: 12),
              const _SectionHeader(label: 'Groups'),
              const _GroupsStubRow(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _FriendsSection extends ConsumerWidget {
  const _FriendsSection({required this.state});
  final AsyncValue<List<FriendListItem>> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return state.when(
      loading: () => const _FriendsLoading(),
      error: (error, stack) =>
          _FriendsError(onRetry: () => ref.invalidate(friendsListProvider)),
      data: (items) {
        if (items.isEmpty) {
          return const _FriendsEmpty();
        }
        return _FriendsPopulated(items: items);
      },
    );
  }
}

class _FriendsPopulated extends ConsumerWidget {
  const _FriendsPopulated({required this.items});
  final List<FriendListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          FriendListTile(
            item: item,
            onTap: () => _onFriendSelected(context, ref, item),
          ),
      ],
    );
  }

  Future<void> _onFriendSelected(
    BuildContext context,
    WidgetRef ref,
    FriendListItem item,
  ) async {
    // PER ARCHITECT §2.5 — emit telemetry FIRST, then dismiss the
    // picker, then open the AddExpenseBottomSheet. Avoids the race
    // where the picker pops and the new sheet animates in
    // simultaneously.
    await ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: expenseContextSelectedEvent,
          parameters: <String, Object>{contextTypeParam: contextTypeFriend},
        );

    if (!context.mounted) return;

    final currentUid = ref.read(currentUserIdProvider);
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;

    navigator.pop();

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => AddExpenseBottomSheet(
        friendshipId: item.friendshipId,
        currentUserUid: currentUid,
        otherUserUid: item.otherUserId,
      ),
    );
  }
}

class _FriendsEmpty extends ConsumerWidget {
  const _FriendsEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('You have no friends yet', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _onAddFirstFriend(context, ref),
            child: const Text('Add your first friend'),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddFirstFriend(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    // Read the signed-in identity BEFORE dismissing the picker — this
    // widget (and its `ref`) is torn down by the pop.
    final currentUserId = ref.read(currentUserIdProvider);
    final currentUserPhone = ref.read(currentUserPhoneProvider);
    navigator.pop();
    await openAddFriendFlow(
      context: rootContext,
      currentUserId: currentUserId,
      currentUserPhone: currentUserPhone,
    );
  }
}

class _FriendsLoading extends StatelessWidget {
  const _FriendsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FriendsError extends StatelessWidget {
  const _FriendsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Something went wrong loading your friends.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _GroupsStubRow extends ConsumerWidget {
  const _GroupsStubRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return ListTile(
      leading: Icon(Icons.groups_outlined, color: mutedColor),
      title: Text(
        'Groups',
        style: theme.textTheme.titleMedium?.copyWith(color: mutedColor),
      ),
      trailing: Text(
        'Coming in Sprint 3',
        style: theme.textTheme.labelMedium?.copyWith(color: mutedColor),
      ),
      onTap: () => _onGroupsTapped(context, ref),
    );
  }

  Future<void> _onGroupsTapped(BuildContext context, WidgetRef ref) async {
    // Show snackbar + fire telemetry; KEEP the picker mounted (per
    // architect §2.3).
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(content: Text('Group expenses coming in Sprint 3.')),
    );
    await ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: expenseContextSelectedEvent,
          parameters: <String, Object>{contextTypeParam: contextTypeGroup},
        );
  }
}
