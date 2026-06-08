import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/widgets/lists/obt_activity_row.dart';
import 'package:onebytwo/features/activity/application/activity_feed_provider.dart';
import 'package:onebytwo/features/activity/application/relative_timestamp_formatter.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/activity/presentation/widgets/activity_feed_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';

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
/// Deep-link routing (FR-AC-02):
///   - `expenseAdded` / `expenseEdited` → [ExpenseDetailScreen].
///   - `expenseDeleted` → info snackbar; remain on the feed.
///   - `settlementRecorded` → [FriendDetailScreen] for the other party.
///
/// Telemetry (PII per ADR-0013 — friendship composite UIDs hashed via
/// `hashFriendshipId`; expense IDs / settlement IDs are opaque scalar
/// IDs and not subject to ADR-0013 hashing):
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
    // The multi-context FAB chooser is deferred per architect §2.1.
    // For v1.0 the Empty-state CTA surfaces a hint snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open a friend from the Friends list to add an expense.'),
      ),
    );
  }

  Future<void> _onRowTap(ActivityFeedItem item) async {
    final analytics = ref.read(analyticsServiceProvider);
    final currentUid = ref.read(currentUserIdProvider);
    final entityId = _entityIdFor(item, currentUid);
    final telemetryEntityId = _hashIfFriendship(entityId, item);
    unawaited(
      analytics.logEvent(
        name: 'activity_item_tapped',
        parameters: {
          'event_type': item.type.wireName,
          'entity_id': telemetryEntityId,
        },
      ),
    );

    if (!mounted) return;

    switch (item.type) {
      case ActivityEventType.expenseAdded:
      case ActivityEventType.expenseEdited:
        final friendshipId = item.payload['friendshipId'] as String?;
        final expenseId = item.payload['expenseId'] as String?;
        if (friendshipId == null || expenseId == null) {
          _showUnavailableSnackbar();
          return;
        }
        final otherUid = _otherUidForFriendship(friendshipId, currentUid);
        if (otherUid == null) {
          _showUnavailableSnackbar();
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ExpenseDetailScreen(
              friendshipId: friendshipId,
              expenseId: expenseId,
              currentUserUid: currentUid,
              otherUserUid: otherUid,
            ),
          ),
        );
      case ActivityEventType.expenseDeleted:
        _showUnavailableSnackbar();
      case ActivityEventType.settlementRecorded:
        final contextId = item.payload['contextId'] as String?;
        if (contextId == null) {
          _showUnavailableSnackbar();
          return;
        }
        final otherUid = _otherUidForFriendship(contextId, currentUid);
        if (otherUid == null) {
          _showUnavailableSnackbar();
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FriendDetailScreen(
              friendshipId: contextId,
              currentUserUid: currentUid,
              otherUserUid: otherUid,
            ),
          ),
        );
    }
  }

  void _showUnavailableSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This item is no longer available.')),
    );
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
    }
  }

  /// Applies ADR-0013 hashing to friendship-composite entity IDs (the
  /// only PII-adjacent identifier surface among the deep-link
  /// targets). Opaque scalar IDs (expense, settlement) are returned
  /// unchanged.
  String _hashIfFriendship(String entityId, ActivityFeedItem item) {
    switch (item.type) {
      case ActivityEventType.settlementRecorded:
        return hashFriendshipId(entityId);
      case ActivityEventType.expenseAdded:
      case ActivityEventType.expenseEdited:
      case ActivityEventType.expenseDeleted:
        return entityId;
    }
  }

  /// Extracts the other party's UID from a friendship document ID
  /// (`{uidA}_{uidB}`). Returns null if the composite cannot be
  /// resolved.
  String? _otherUidForFriendship(String friendshipId, String currentUid) {
    final parts = friendshipId.split('_');
    if (parts.length != 2) return null;
    if (parts[0] == currentUid) return parts[1];
    if (parts[1] == currentUid) return parts[0];
    return null;
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final otherUid = _otherUidFor(item, currentUid);
          final profileAsync = otherUid == null
              ? const AsyncValue<UserModel?>.data(null)
              : ref.watch(userProfileProvider(otherUid));
          final otherName = profileAsync.maybeWhen(
            data: (profile) => profile?.displayName ?? 'Unknown',
            orElse: () => 'Unknown',
          );
          return OBTActivityRow(
            item: item,
            currentUserUid: currentUid,
            otherPartyDisplayName: otherName,
            secondaryText: formatRelativeTimestamp(
              now: now,
              createdAt: item.createdAt?.toUtc(),
            ),
            onTap: () => onRowTap(item),
          );
        },
      ),
    );
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
    }
    if (friendshipId == null) return null;
    final parts = friendshipId.split('_');
    if (parts.length != 2) return null;
    if (parts[0] == currentUid) return parts[1];
    if (parts[1] == currentUid) return parts[0];
    return null;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddExpense});

  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.notifications_none_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'All quiet here',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your activity will show up as you add expenses and settle up.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            ),
          ],
        ),
      ),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
