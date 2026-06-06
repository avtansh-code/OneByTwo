import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Intermixed expense + settlement timeline rendered below the header.
///
/// Up to 5 rows per the SCR-11 spec. Tap on an expense row is a
/// deliberate no-op for PR #42 — FR-EX-06 owns the edit / delete flow.
/// Tap on a settlement row is also a no-op until a future PR introduces
/// the settlement detail screen.
///
/// All paise → INR conversion goes through [formatInrFromPaise]
/// (Invariant 1).
class FriendDetailTimelineWidget extends StatelessWidget {
  /// Creates a [FriendDetailTimelineWidget].
  const FriendDetailTimelineWidget({
    required this.timeline,
    required this.currentUserUid,
    required this.friendDisplayName,
    super.key,
  });

  /// The list of events to render, in display order (already date-desc).
  final List<FriendDetailTimelineEvent> timeline;

  /// The current user's UID — used to label the share line on expense rows.
  final String currentUserUid;

  /// The friend's display name — used in the payer label.
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: timeline.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = timeline[index];
        switch (event) {
          case TimelineExpense(:final doc):
            return _ExpenseRow(
              doc: doc,
              currentUserUid: currentUserUid,
              friendDisplayName: friendDisplayName,
            );
          case TimelineSettlement(:final doc):
            return _SettlementRow(doc: doc);
        }
      },
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.doc,
    required this.currentUserUid,
    required this.friendDisplayName,
  });

  final ExpenseDoc doc;
  final String currentUserUid;
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();
    final isMyExpense = doc.payerId == currentUserUid;
    final payerLabel = isMyExpense ? 'You' : _firstName(friendDisplayName);

    final mySplit = doc.splits.firstWhere(
      (s) => s.userId == currentUserUid,
      orElse: () => doc.splits.first,
    );
    final shareLabel = isMyExpense
        ? 'you lent ${formatInrFromPaise(doc.amountPaise - mySplit.sharePaise)}'
        : 'you borrowed ${formatInrFromPaise(mySplit.sharePaise)}';

    return InkWell(
      onTap: () {
        // No-op for PR #42. FR-EX-06 will own the edit / delete flow.
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  expenseCategoryIcon[doc.category] ?? Icons.receipt_long,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.description,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$payerLabel paid • ${dateFmt.format(doc.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              shareLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMyExpense
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(' ').first;
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({required this.doc});

  final SettlementDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();
    final amount = formatInrFromPaise(doc.amountPaise);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.handshake_outlined),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settlement',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  dateFmt.format(doc.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
