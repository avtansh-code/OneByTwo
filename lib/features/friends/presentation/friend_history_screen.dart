import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friend_history_provider.dart';
import 'package:onebytwo/features/friends/presentation/widgets/transaction_visuals.dart';

/// Friend History screen (FR-FR-04 / Haldi 12; net-new in DC-06).
///
/// The dedicated, full per-friend transaction log: the **complete**
/// reverse-chronological list of expenses **and** settlements with the
/// friend, **month-grouped** (IST), each row carrying a **signed** amount
/// (positive = in your favour / you are owed or received; negative = you
/// owe / you paid out).
///
/// Reached via the "View full history" affordance on Friend Detail, which
/// supersedes the inline top-5 timeline preview.
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: every amount is an `int` paise value rendered
///   solely via `formatInrFromPaise()`; the sign glyph is the only addition
///   and there is no `/100` or `double` arithmetic.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this is a pure read
///   projection of the expense + settlement documents — it never reads,
///   derives from, or writes `simplifiedBalances`.
class FriendHistoryScreen extends ConsumerWidget {
  /// Creates a [FriendHistoryScreen].
  const FriendHistoryScreen({
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.friendDisplayName,
    super.key,
  });

  /// Friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  /// Authenticated user UID.
  final String currentUserUid;

  /// Friend UID.
  final String otherUserUid;

  /// The friend's resolved display name (shown in the header subtitle).
  final String friendDisplayName;

  FriendDetailArgs get _args => FriendDetailArgs(
    friendshipId: friendshipId,
    currentUserUid: currentUserUid,
    otherUserUid: otherUserUid,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(friendHistoryProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('History'),
            Text(
              'with $friendDisplayName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: OBTColors.metaText(theme),
              ),
            ),
          ],
        ),
      ),
      body: async.when(
        loading: () => const _HistoryLoadingState(),
        error: (error, stack) => _HistoryErrorState(
          onRetry: () => ref.invalidate(friendHistoryProvider(_args)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return _HistoryEmptyState(friendDisplayName: friendDisplayName);
          }
          return _HistoryList(
            events: events,
            currentUserUid: currentUserUid,
            friendDisplayName: friendDisplayName,
          );
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.events,
    required this.currentUserUid,
    required this.friendDisplayName,
  });

  final List<FriendDetailTimelineEvent> events;
  final String currentUserUid;
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    // Flatten the month-grouped log into a single item list (month headers
    // interleaved with rows) up front — a cheap single pass over lightweight
    // value holders — then render lazily via ListView.builder so only the
    // visible viewport is inflated. The log is uncapped, so eager inflation
    // (ListView(children:)) would build every row on each build.
    final items = <_HistoryItem>[];
    DateTime? currentMonthKey;
    for (final event in events) {
      final ist = toIst(event.timelineTimestamp);
      final monthKey = DateTime(ist.year, ist.month);
      if (currentMonthKey == null || monthKey != currentMonthKey) {
        currentMonthKey = monthKey;
        items.add(_MonthHeaderItem(event.timelineTimestamp));
      }
      items.add(_EventItem(event));
    }

    return ListView.builder(
      key: const Key('friend_history_list'),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        switch (item) {
          case _MonthHeaderItem(:final timestamp):
            return _MonthHeader(timestamp: timestamp);
          case _EventItem(:final event):
            return _HistoryRow(
              event: event,
              currentUserUid: currentUserUid,
              friendDisplayName: friendDisplayName,
            );
        }
      },
    );
  }
}

/// One entry in the flattened history list: a month header or a row.
sealed class _HistoryItem {
  const _HistoryItem();
}

class _MonthHeaderItem extends _HistoryItem {
  const _MonthHeaderItem(this.timestamp);

  /// A representative timestamp from the month (formatted IST-aware).
  final DateTime timestamp;
}

class _EventItem extends _HistoryItem {
  const _EventItem(this.event);

  final FriendDetailTimelineEvent event;
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          formatIstMonthHeader(timestamp),
          style: theme.textTheme.labelMedium?.copyWith(
            color: OBTColors.metaText(theme),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.event,
    required this.currentUserUid,
    required this.friendDisplayName,
  });

  final FriendDetailTimelineEvent event;
  final String currentUserUid;
  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final dateStr = formatIstShortDate(event.timelineTimestamp);

    final String title;
    final String descriptor;
    final IconData icon;
    final Color tileHue;
    final int signedPaise;

    switch (event) {
      case TimelineExpense(:final doc):
        final isMine = doc.payerId == currentUserUid;
        final mySplit = _myShare(doc);
        if (isMine) {
          final lent = doc.amountPaise - mySplit;
          signedPaise = lent;
          descriptor = 'you lent ${formatInrFromPaise(lent)}';
        } else {
          signedPaise = -mySplit;
          descriptor = 'you borrowed ${formatInrFromPaise(mySplit)}';
        }
        title = doc.description;
        icon = expenseCategoryIcon[doc.category] ?? Icons.receipt_long;
        tileHue = obtColors.categoryColor(friendCategoryKey(doc.category));
      case TimelineSettlement(:final doc):
        final isIncoming = doc.toUserId == currentUserUid;
        signedPaise = isIncoming ? doc.amountPaise : -doc.amountPaise;
        title = isIncoming
            ? '${_firstName(friendDisplayName)} paid you'
            : 'You paid ${_firstName(friendDisplayName)}';
        descriptor = 'settlement';
        icon = Icons.payments_outlined;
        tileHue = isIncoming
            ? obtColors.balancePositive
            : obtColors.balanceNegative;
    }

    final amountHue = signedPaise >= 0
        ? obtColors.balancePositive
        : obtColors.balanceNegative;
    // The sign glyph is the only addition to the formatter output; the
    // rupee conversion stays inside formatInrFromPaise() (Invariant 1).
    final amountText = signedPaise >= 0
        ? '+${formatInrFromPaise(signedPaise)}'
        : formatInrFromPaise(signedPaise);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Row(
          children: <Widget>[
            TransactionIconTile(icon: icon, hue: tileHue, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr • $descriptor',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: OBTColors.metaText(theme),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amountText,
              style: OBTText.amount(context).copyWith(color: amountHue),
            ),
          ],
        ),
      ),
    );
  }

  int _myShare(ExpenseDoc doc) {
    return doc.splits
        .firstWhere(
          (s) => s.userId == currentUserUid,
          orElse: () => doc.splits.first,
        )
        .sharePaise;
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(' ').first;
  }
}

/// Shimmer loading skeleton for the history screen. Freezes under reduced
/// motion via the shared `OBTSkeleton` set.
class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('friend_history_skeleton'),
      padding: const EdgeInsets.only(top: 8),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: OBTSkeleton(
            width: 120,
            height: 12,
            borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
          ),
        ),
        const OBTSkeletonList(itemCount: 6),
      ],
    );
  }
}

/// Empty state when the friendship has no expenses or settlements yet.
class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.friendDisplayName});

  final String friendDisplayName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OBTEmptyState(
      illustration: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.history_rounded, size: 52, color: colors.primary),
      ),
      headline: 'No history yet',
      supportingText:
          'Expenses and settlements with $friendDisplayName will appear here.',
    );
  }
}

/// Error state with a Retry that re-resolves the two snapshot streams.
class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't load this history. Please try again.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: OBTColors.metaText(theme),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
