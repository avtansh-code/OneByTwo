import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';

/// Minimal placeholder for the friend-detail screen (SCR-11) that
/// FR-FR-04 will ship. Pushed when a row is tapped in
/// `FriendsListScreen` so the navigation contract is exercised
/// end-to-end and the AC-6 real-time test can walk
/// open → tap → back → real-time update.
///
/// **Intentionally minimal.** The screen does not display the raw
/// `friendshipId` (which would expose a PII-adjacent composite of two
/// UIDs in the UI) or any balance information. The neutral copy makes
/// it obvious to QA and design reviewers that the real screen has not
/// yet shipped.
///
/// FR-EX-01 wires the FAB on this placeholder: tapping the
/// `Add expense` FAB opens the [AddExpenseBottomSheet] preloaded
/// with this friendship's context (Architect Notes §2.5 — no
/// re-fetch; the context flows in via the constructor).
///
/// Removal moment: replace this widget with the real `FriendDetailScreen`
/// in the FR-FR-04 PR. The call site in `FriendsListScreen.onRowTap`
/// stays the same; only the destination widget changes (and the FAB
/// wiring lifts to the real screen verbatim).
class FriendDetailPlaceholderScreen extends ConsumerWidget {
  /// Creates a [FriendDetailPlaceholderScreen].
  const FriendDetailPlaceholderScreen({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Friend')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Friend details coming soon',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Detailed expenses and settle-up actions will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add expense',
        onPressed: () => _openAddExpenseSheet(context),
        child: const Icon(Icons.add, semanticLabel: 'Add expense'),
      ),
    );
  }

  Future<void> _openAddExpenseSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => AddExpenseBottomSheet(
        friendshipId: friendshipId,
        currentUserUid: currentUserUid,
        otherUserUid: otherUserUid,
      ),
    );
  }
}
