import 'package:flutter/material.dart';

import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

/// Sealed discriminated union over the in-app navigation targets a
/// notification can deep-link to (FR-AC-03, FR-AC-05).
///
/// Resolved purely from a [NotificationPayload] by
/// [NotificationDeepLinks.resolve] (no [BuildContext], no
/// dependencies). The navigation itself is performed by
/// [NotificationDeepLinks.navigate].
@immutable
sealed class DeepLinkTarget {
  const DeepLinkTarget();
}

/// Push [ExpenseDetailScreen] for a friendship-context expense.
final class DeepLinkExpenseDetail extends DeepLinkTarget {
  /// Creates a [DeepLinkExpenseDetail].
  const DeepLinkExpenseDetail({
    required this.friendshipId,
    required this.expenseId,
    required this.currentUid,
    required this.otherUid,
  });

  /// Friendship composite ID (`{uidA}_{uidB}`).
  final String friendshipId;

  /// Expense document ID under
  /// `friendships/{friendshipId}/expenses/{expenseId}`.
  final String expenseId;

  /// The current user's UID (signed-in viewer).
  final String currentUid;

  /// The other party's UID — extracted from [friendshipId] via
  /// [NotificationDeepLinks.otherUidForFriendship].
  final String otherUid;
}

/// Push [FriendDetailScreen] for a friendship-context settlement or
/// reminder.
final class DeepLinkFriendDetail extends DeepLinkTarget {
  /// Creates a [DeepLinkFriendDetail].
  const DeepLinkFriendDetail({
    required this.friendshipId,
    required this.currentUid,
    required this.otherUid,
  });

  /// Friendship composite ID.
  final String friendshipId;

  /// Current viewer's UID.
  final String currentUid;

  /// Other party's UID.
  final String otherUid;
}

/// Show the SCR-25 "This item is no longer available" snackbar; do
/// not navigate. Used for `expense_deleted` and any malformed /
/// orphaned payload.
final class DeepLinkUnavailable extends DeepLinkTarget {
  /// Creates a [DeepLinkUnavailable].
  const DeepLinkUnavailable();
}

/// Show a "Groups coming soon" snackbar for `group_invite` payloads.
/// Forward-compatibility only — no producer in v1.0.
final class DeepLinkGroupsComingSoon extends DeepLinkTarget {
  /// Creates a [DeepLinkGroupsComingSoon].
  const DeepLinkGroupsComingSoon();
}

/// Shared resolver / navigator for notification + activity-feed deep
/// links (FR-AC-03 architect §2.3).
///
/// Consumed by:
///   1. `ActivityFeedScreen._onRowTap` (FR-AC-01 / FR-AC-02 — refactored
///      to use this helper in commit 10).
///   2. The foreground in-app banner tap (FR-AC-03).
///   3. The background system-notification tap (FR-AC-03).
///   4. The cold-start `getInitialMessage` payload (FR-AC-05).
///
/// **The resolver is a pure function.** Telemetry (`activity_item_tapped`
/// vs `fcm_notification_tapped`) stays at the call site so the helper
/// has no analytics dependency.
class NotificationDeepLinks {
  const NotificationDeepLinks._();

  /// Pure-function resolver from `(payload, currentUid)` to
  /// [DeepLinkTarget].
  ///
  /// Per-type rules:
  ///   - `expense_added` / `expense_edited`: requires `itemId` and a
  ///     valid friendship-composite `contextId`. Returns
  ///     [DeepLinkExpenseDetail] on success, [DeepLinkUnavailable] on
  ///     missing-field / malformed-composite.
  ///   - `expense_deleted`: always returns [DeepLinkUnavailable] (the
  ///     expense is gone — SCR-25 fallback).
  ///   - `settlement_received` / `reminder`: requires a valid
  ///     friendship-composite `contextId`. Returns [DeepLinkFriendDetail]
  ///     on success, [DeepLinkUnavailable] on malformed.
  ///   - `group_invite`: returns [DeepLinkGroupsComingSoon] (no
  ///     producer in v1.0).
  static DeepLinkTarget resolve(
    NotificationPayload payload,
    String currentUid,
  ) {
    return resolveFromFields(
      type: payload.type,
      contextId: payload.contextId,
      itemId: payload.itemId,
      currentUid: currentUid,
    );
  }

  /// Pure-function resolver from raw fields to [DeepLinkTarget]. Used
  /// by both the FCM payload resolver above and the activity-feed
  /// row-tap call site (FR-AC-02) so the two consumers share a single
  /// routing contract.
  static DeepLinkTarget resolveFromFields({
    required NotificationType type,
    required String contextId,
    required String currentUid,
    String? itemId,
  }) {
    switch (type) {
      case NotificationType.expenseAdded:
      case NotificationType.expenseEdited:
        if (itemId == null) return const DeepLinkUnavailable();
        final other = otherUidForFriendship(contextId, currentUid);
        if (other == null) return const DeepLinkUnavailable();
        return DeepLinkExpenseDetail(
          friendshipId: contextId,
          expenseId: itemId,
          currentUid: currentUid,
          otherUid: other,
        );
      case NotificationType.expenseDeleted:
        return const DeepLinkUnavailable();
      case NotificationType.settlementReceived:
      case NotificationType.reminder:
        final other = otherUidForFriendship(contextId, currentUid);
        if (other == null) return const DeepLinkUnavailable();
        return DeepLinkFriendDetail(
          friendshipId: contextId,
          currentUid: currentUid,
          otherUid: other,
        );
      case NotificationType.groupInvite:
        return const DeepLinkGroupsComingSoon();
    }
  }

  /// Extracts the other party's UID from a friendship composite ID
  /// (`{uidA}_{uidB}`). Returns `null` if the composite has the wrong
  /// arity OR the [currentUid] is not present.
  static String? otherUidForFriendship(String friendshipId, String currentUid) {
    final parts = friendshipId.split('_');
    if (parts.length != 2) return null;
    if (parts[0] == currentUid) return parts[1];
    if (parts[1] == currentUid) return parts[0];
    return null;
  }

  /// Performs the platform navigation for [target].
  ///
  /// For [DeepLinkExpenseDetail] / [DeepLinkFriendDetail]: pushes the
  /// target screen onto the navigator stack via [MaterialPageRoute].
  /// For [DeepLinkUnavailable]: shows the "This item is no longer
  /// available" snackbar — no navigation.
  /// For [DeepLinkGroupsComingSoon]: shows a "Groups coming soon"
  /// snackbar — no navigation.
  static Future<void> navigate(
    BuildContext context,
    DeepLinkTarget target,
  ) async {
    switch (target) {
      case DeepLinkExpenseDetail(
        :final friendshipId,
        :final expenseId,
        :final currentUid,
        :final otherUid,
      ):
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
      case DeepLinkFriendDetail(
        :final friendshipId,
        :final currentUid,
        :final otherUid,
      ):
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FriendDetailScreen(
              friendshipId: friendshipId,
              currentUserUid: currentUid,
              otherUserUid: otherUid,
            ),
          ),
        );
      case DeepLinkUnavailable():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This item is no longer available.')),
        );
      case DeepLinkGroupsComingSoon():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Groups are coming soon.')),
        );
    }
  }
}
