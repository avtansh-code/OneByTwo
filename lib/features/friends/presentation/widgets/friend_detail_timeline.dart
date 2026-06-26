import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/widgets/transaction_visuals.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Intermixed expense + settlement timeline rendered below the header
/// (SCR-11 / Haldi 11), reskinned to the Haldi visual system (DC-06).
///
/// Up to 5 rows per the SCR-11 spec — the "View full history" affordance on
/// Friend Detail opens the full Haldi 12 log. Tap on an expense row pushes
/// the [ExpenseDetailScreen] (FR-EX-06). Tap on a settlement row is a
/// no-op until a future PR introduces the settlement detail screen.
///
/// Each row leads with a Haldi category-hue [TransactionIconTile]; amounts
/// render in the Bricolage tabular [OBTText.amount] tinted by the balance
/// trio. All paise -> INR conversion goes through `formatInrFromPaise()`
/// (Invariant 1).
class FriendDetailTimelineWidget extends StatelessWidget {
  /// Creates a [FriendDetailTimelineWidget].
  const FriendDetailTimelineWidget({
    required this.timeline,
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.friendDisplayName,
    super.key,
  });

  /// The list of events to render, in display order (already date-desc).
  final List<FriendDetailTimelineEvent> timeline;

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// The current user's UID — used to label the share line on expense rows.
  final String currentUserUid;

  /// The friend's UID — threaded into the expense detail screen so it
  /// can host the edit / delete sheet.
  final String otherUserUid;

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
              friendshipId: friendshipId,
              currentUserUid: currentUserUid,
              otherUserUid: otherUserUid,
              friendDisplayName: friendDisplayName,
            );
          case TimelineSettlement(:final doc):
            return _SettlementRow(
              doc: doc,
              currentUserUid: currentUserUid,
              friendDisplayName: friendDisplayName,
            );
        }
      },
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.doc,
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.friendDisplayName,
  });

  final ExpenseDoc doc;
  final String friendshipId;
  final String currentUserUid;
  final String otherUserUid;
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
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
    final shareHue = isMyExpense
        ? obtColors.balancePositive
        : obtColors.balanceNegative;

    return InkWell(
      onTap: doc.id == null ? null : () => _openExpenseDetail(context, doc.id!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TransactionIconTile(
              icon: expenseCategoryIcon[doc.category] ?? Icons.receipt_long,
              hue: obtColors.categoryColor(friendCategoryKey(doc.category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
                      color: OBTColors.metaText(theme),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              shareLabel,
              style: OBTText.amount(context).copyWith(color: shareHue),
            ),
          ],
        ),
      ),
    );
  }

  void _openExpenseDetail(BuildContext context, String expenseId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseDetailScreen(
          friendshipId: friendshipId,
          expenseId: expenseId,
          currentUserUid: currentUserUid,
          otherUserUid: otherUserUid,
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
  const _SettlementRow({
    required this.doc,
    required this.currentUserUid,
    required this.friendDisplayName,
  });

  final SettlementDoc doc;
  final String currentUserUid;
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final dateFmt = DateFormat.yMMMd();
    final amount = formatInrFromPaise(doc.amountPaise);
    final isMine = doc.fromUserId == currentUserUid;
    final friendFirstName = _firstName(friendDisplayName);
    final label = isMine
        ? 'You paid $friendFirstName $amount'
        : '$friendFirstName paid you $amount';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TransactionIconTile(
            icon: Icons.payments_outlined,
            hue: obtColors.balanceZero,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateFmt.format(doc.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: OBTColors.metaText(theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(' ').first;
  }
}
