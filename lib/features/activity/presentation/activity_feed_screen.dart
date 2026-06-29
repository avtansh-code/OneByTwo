import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/formatters/ist_date_formatter.dart';
import 'package:onebytwo/core/routing/notification_deep_links.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/lists/obt_activity_row.dart';
import 'package:onebytwo/features/activity/application/activity_feed_provider.dart';
import 'package:onebytwo/features/activity/application/relative_timestamp_formatter.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/activity/presentation/widgets/activity_feed_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';

/// SCR-25 — Activity Feed screen (FR-AC-01 / FR-AC-02).
///
/// Renders five states defined by SCR-25:
///   - Loading: 5-row skeleton via [ActivityFeedSkeleton].
///   - Populated: a `ListView` of [OBTActivityRow] tiles ordered by
///     `createdAt` descending.
///   - Empty: SCR-25 "All quiet here" copy.
///   - Error: SCR-25 "Something went wrong" copy + Retry button.
///   - Refreshing: pull-to-refresh on the populated list with an error
///     snackbar on failure.
///
/// Deep-link routing (FR-AC-02 + FR-AC-03 architect §2.3 — shared
/// helper):
///   - `expenseAdded` / `expenseEdited` → `ExpenseDetailScreen` via
///     `NotificationDeepLinks.navigate`.
///   - `expenseDeleted` → "This item is no longer available" snackbar
///     via the shared helper; remain on the feed.
///   - `settlementRecorded` → `FriendDetailScreen` for the other party
///     via the shared helper.
///
/// Telemetry (PII per ADR-0013 — every deep-link entity ID is hashed
/// before emission: friendship composite UIDs via `hashFriendshipId`,
/// opaque expense IDs via `hashId`, both surfaced as `entity_id_hash`):
///   - `activity_feed_viewed` (once per session in Populated/Empty).
///   - `activity_item_tapped` (every row tap).
///   - `activity_feed_refreshed` (pull-to-refresh).
///   - `activity_feed_error` (on stream error).
class ActivityFeedScreen extends ConsumerStatefulWidget {
  /// Creates an [ActivityFeedScreen].
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  bool _loggedView = false;
  bool _loggedError = false;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(activityFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Activity')),
        elevation: 0.5,
      ),
      body: feedAsync.when(
        loading: () => const ActivityFeedSkeleton(),
        error: (error, _) {
          _logErrorOnce(error);
          return _ErrorState(onRetry: _onRetry);
        },
        data: (items) {
          _logViewedOnce(items.length);
          if (items.isEmpty) {
            return _EmptyState(onAddExpense: _onEmptyAddExpenseTapped);
          }
          return _PopulatedList(
            items: items,
            onRowTap: _onRowTap,
            onRefresh: _onRefresh,
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Telemetry helpers
  // -------------------------------------------------------------------------

  void _logViewedOnce(int itemCount) {
    if (_loggedView) return;
    _loggedView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'activity_feed_viewed',
            parameters: {'item_count': itemCount},
          ),
    );
  }

  void _logErrorOnce(Object error) {
    if (_loggedError) return;
    _loggedError = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'activity_feed_error',
            parameters: {'error_code': error.runtimeType.toString()},
          ),
    );
  }

  // -------------------------------------------------------------------------
  // User actions
  // -------------------------------------------------------------------------

  void _onRetry() {
    _loggedError = false;
    ref.invalidate(activityFeedProvider);
  }

  Future<void> _onRefresh() async {
    ref.invalidate(activityFeedProvider);
    try {
      await ref.read(activityFeedProvider.future);
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: 'activity_feed_refreshed',
              parameters: const {'success': true},
            ),
      );
    } catch (_) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: 'activity_feed_refreshed',
              parameters: const {'success': false},
            ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not refresh. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  void _onEmptyAddExpenseTapped() {
    // Open the add-expense context picker (the same surface the Home FAB
    // and empty state use) so the friendly empty CTA actually starts the
    // add flow rather than only hinting.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddExpenseContextPickerSheet(),
    );
  }

  Future<void> _onRowTap(ActivityFeedItem item) async {
    final analytics = ref.read(analyticsServiceProvider);
    final currentUid = ref.read(currentUserIdProvider);
    final entityId = _entityIdFor(item, currentUid);
    final entityIdHash = _hashEntityId(entityId, item);
    unawaited(
      analytics.logEvent(
        name: 'activity_item_tapped',
        parameters: {
          'event_type': item.type.wireName,
          'entity_id_hash': entityIdHash,
        },
      ),
    );

    if (!mounted) return;

    final target = _buildDeepLinkTarget(item, currentUid);
    await NotificationDeepLinks.navigate(context, target);
  }

  /// Resolves the [DeepLinkTarget] for an [ActivityFeedItem] using the
  /// same shared routing contract as the FCM notification tap surface
  /// (FR-AC-03 architect §2.3). Maps the activity event type to the
  /// equivalent notification type and forwards to
  /// [NotificationDeepLinks.resolveFromFields].
  DeepLinkTarget _buildDeepLinkTarget(
    ActivityFeedItem item,
    String currentUid,
  ) {
    final notifType = _mapActivityToNotificationType(item.type);
    String? contextId;
    String? itemId;
    switch (item.type) {
      case ActivityEventType.expenseAdded:
      case ActivityEventType.expenseEdited:
      case ActivityEventType.expenseDeleted:
        contextId = item.payload['friendshipId'] as String?;
        itemId = item.payload['expenseId'] as String?;
      case ActivityEventType.settlementRecorded:
        contextId = item.payload['contextId'] as String?;
      case ActivityEventType.friendAdded:
        contextId = item.payload['friendshipId'] as String?;
    }
    if (contextId == null) {
      return const DeepLinkUnavailable();
    }
    return NotificationDeepLinks.resolveFromFields(
      type: notifType,
      contextId: contextId,
      itemId: itemId,
      currentUid: currentUid,
    );
  }

  NotificationType _mapActivityToNotificationType(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.expenseAdded:
        return NotificationType.expenseAdded;
      case ActivityEventType.expenseEdited:
        return NotificationType.expenseEdited;
      case ActivityEventType.expenseDeleted:
        return NotificationType.expenseDeleted;
      case ActivityEventType.settlementRecorded:
        return NotificationType.settlementReceived;
      case ActivityEventType.friendAdded:
        // friend_added deep-links to the friend detail, the same target
        // as a settlement (resolved from the friendshipId contextId).
        return NotificationType.settlementReceived;
    }
  }

  /// Returns the deep-link entity ID for telemetry. For friendship
  /// targets (`settlementRecorded`), this is the `contextId`. For
  /// expense targets, this is the opaque `expenseId`.
  String _entityIdFor(ActivityFeedItem item, String currentUid) {
    switch (item.type) {
      case ActivityEventType.expenseAdded:
      case ActivityEventType.expenseEdited:
      case ActivityEventType.expenseDeleted:
        return (item.payload['expenseId'] as String?) ?? '';
      case ActivityEventType.settlementRecorded:
        return (item.payload['contextId'] as String?) ?? '';
      case ActivityEventType.friendAdded:
        return (item.payload['friendshipId'] as String?) ?? '';
    }
  }

  /// Hashes the deep-link entity ID for telemetry so no raw identifier
  /// leaves the event (param `entity_id_hash`). Friendship-composite IDs
  /// (`settlementRecorded`) go through [hashFriendshipId]; opaque scalar
  /// IDs (expense) go through [hashId]. Both yield the same ADR-0013
  /// SHA-256 digest form.
  String _hashEntityId(String entityId, ActivityFeedItem item) {
    switch (item.type) {
      case ActivityEventType.settlementRecorded:
        return hashFriendshipId(entityId);
      case ActivityEventType.friendAdded:
        // friend_added's entity id is the friendship composite, hashed
        // the same way as a settlement context id.
        return hashFriendshipId(entityId);
      case ActivityEventType.expenseAdded:
      case ActivityEventType.expenseEdited:
      case ActivityEventType.expenseDeleted:
        return hashId(entityId);
    }
  }
}

// ---------------------------------------------------------------------------
// State widgets
// ---------------------------------------------------------------------------

class _PopulatedList extends ConsumerWidget {
  const _PopulatedList({
    required this.items,
    required this.onRowTap,
    required this.onRefresh,
  });

  final List<ActivityFeedItem> items;
  final void Function(ActivityFeedItem item) onRowTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(currentUserIdProvider);
    final now = DateTime.now().toUtc();

    // Flatten into IST day-grouped sections (Today / Yesterday / date), each
    // header followed by its rows — the SCR-25 chronological grouping.
    final entries = <_FeedEntry>[];
    String? currentDay;
    for (final item in items) {
      final label = _dayGroupLabel(
        now: now,
        createdAt: item.createdAt?.toUtc(),
      );
      if (label != currentDay) {
        currentDay = label;
        entries.add(_DayHeaderEntry(label));
      }
      entries.add(_RowEntry(item));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry is _DayHeaderEntry) {
            return _DayHeader(label: entry.label);
          }
          final item = (entry as _RowEntry).item;
          final otherUid = _otherUidFor(item, currentUid);
          final profileAsync = otherUid == null
              ? const AsyncValue<UserModel?>.data(null)
              : ref.watch(userProfileProvider(otherUid));
          final otherName = profileAsync.maybeWhen(
            data: (profile) => profile?.displayName ?? 'Unknown',
            orElse: () => 'Unknown',
          );
          return _ActivityCard(
            child: OBTActivityRow(
              item: item,
              currentUserUid: currentUid,
              otherPartyDisplayName: otherName,
              secondaryText: formatRelativeTimestamp(
                now: now,
                createdAt: item.createdAt?.toUtc(),
              ),
              onTap: () => onRowTap(item),
            ),
          );
        },
      ),
    );
  }

  /// The IST day-group label for [createdAt]: "Today", "Yesterday", or the
  /// IST long date for older entries (SCR-25 grouping; UTC+5:30 fixed).
  String _dayGroupLabel({required DateTime now, DateTime? createdAt}) {
    if (createdAt == null) return 'Earlier';
    final nowIst = toIst(now);
    final itemIst = toIst(createdAt);
    final today = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final day = DateTime(itemIst.year, itemIst.month, itemIst.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return formatIstLongDate(createdAt);
  }

  String? _otherUidFor(ActivityFeedItem item, String currentUid) {
    String? friendshipId;
    switch (item.type) {
      case ActivityEventType.expenseAdded:
      case ActivityEventType.expenseEdited:
      case ActivityEventType.expenseDeleted:
        friendshipId = item.payload['friendshipId'] as String?;
      case ActivityEventType.settlementRecorded:
        friendshipId = item.payload['contextId'] as String?;
      case ActivityEventType.friendAdded:
        friendshipId = item.payload['friendshipId'] as String?;
    }
    if (friendshipId == null) return null;
    final parts = friendshipId.split('_');
    if (parts.length != 2) return null;
    if (parts[0] == currentUid) return parts[1];
    if (parts[1] == currentUid) return parts[0];
    return null;
  }
}

/// A flattened activity-feed entry: a day-group header or an activity row.
sealed class _FeedEntry {
  const _FeedEntry();
}

class _DayHeaderEntry extends _FeedEntry {
  const _DayHeaderEntry(this.label);
  final String label;
}

class _RowEntry extends _FeedEntry {
  const _RowEntry(this.item);
  final ActivityFeedItem item;
}

/// The "Today" / "Yesterday" / date overline header opening each day's run
/// of activity rows (SCR-25).
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: OBTColors.metaText(theme),
          ),
        ),
      ),
    );
  }
}

/// A soft surface card wrapping an activity row (SCR-25 row card).
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: obtColors.rowShadow,
          border: theme.brightness == Brightness.dark
              ? Border.all(color: theme.colorScheme.outline)
              : null,
        ),
        child: child,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddExpense});

  final VoidCallback onAddExpense;

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
        child: Icon(
          Icons.notifications_none_outlined,
          size: 52,
          color: colors.primary,
        ),
      ),
      headline: "Nothing's happened yet",
      supportingText:
          'When you or your friends add expenses or settle up, '
          "it'll all show up here.",
      ctaLabel: 'Add an expense',
      onCta: onAddExpense,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We could not load your activity. Please try again.',
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
