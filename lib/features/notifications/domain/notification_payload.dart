import 'package:flutter/foundation.dart';

/// Discriminator enum for the six FCM notification types defined by the
/// server-side wire contract in `functions/src/notifications/types.ts`.
///
/// Each wire value is snake_case (`'expense_added'`,
/// `'settlement_received'`, etc.) per
/// `docs/design/07-technical/notifications.md` §2.2. The client converts
/// to camelCase on read via [NotificationTypeX.fromWireName] — mirror
/// of the FR-AC-01 `ActivityEventTypeX.parseSnakeCase` precedent.
///
/// **Forward-incompat is loud** — an unknown wire value returns `null`
/// from [NotificationTypeX.fromWireName] so the calling
/// [NotificationPayload.fromFcmDataMap] factory drops the payload
/// silently rather than rendering a half-parsed banner.
enum NotificationType {
  /// A new expense was added (wire: `'expense_added'`).
  expenseAdded,

  /// An existing expense was edited (wire: `'expense_edited'`).
  expenseEdited,

  /// An expense was soft-deleted (wire: `'expense_deleted'`).
  expenseDeleted,

  /// A settlement was recorded with the current user as payee
  /// (wire: `'settlement_received'`).
  settlementReceived,

  /// A reminder was nudged to the current user (wire: `'reminder'`).
  reminder,

  /// A group invite was sent to the current user (wire:
  /// `'group_invite'`). No producer in v1.0 — forward-compatibility
  /// only; tapping a group_invite surfaces a "groups coming soon"
  /// snackbar via the deep-link resolver.
  groupInvite,
}

/// Snake_case wire-value parsing for [NotificationType].
extension NotificationTypeX on NotificationType {
  /// Parses the FCM data envelope's `type` field. Returns `null` for
  /// any value not in the closed set above, so the
  /// [NotificationPayload.fromFcmDataMap] factory can drop unknown
  /// payloads silently rather than rendering a half-parsed banner.
  static NotificationType? fromWireName(String wire) {
    switch (wire) {
      case 'expense_added':
        return NotificationType.expenseAdded;
      case 'expense_edited':
        return NotificationType.expenseEdited;
      case 'expense_deleted':
        return NotificationType.expenseDeleted;
      case 'settlement_received':
        return NotificationType.settlementReceived;
      case 'reminder':
        return NotificationType.reminder;
      case 'group_invite':
        return NotificationType.groupInvite;
      default:
        return null;
    }
  }

  /// Returns the canonical snake_case wire name used by both the
  /// server and the telemetry `notification_type` parameter.
  String get wireName {
    switch (this) {
      case NotificationType.expenseAdded:
        return 'expense_added';
      case NotificationType.expenseEdited:
        return 'expense_edited';
      case NotificationType.expenseDeleted:
        return 'expense_deleted';
      case NotificationType.settlementReceived:
        return 'settlement_received';
      case NotificationType.reminder:
        return 'reminder';
      case NotificationType.groupInvite:
        return 'group_invite';
    }
  }
}

/// Immutable value type representing a single FCM data envelope as
/// defined by `functions/src/notifications/types.ts` and described in
/// `docs/design/07-technical/notifications.md` §2.1.
///
/// All FCM data values are strings on the wire (the FCM SDK enforces
/// this); typed fields like [amountPaise] and [createdAt] are parsed
/// after receipt. Per **Invariant 1**, [amountPaise] is `int`, never
/// `double`; the notification body string is pre-rendered server-side
/// so no client-side paise→INR arithmetic is required.
@immutable
class NotificationPayload {
  /// Creates a [NotificationPayload].
  const NotificationPayload({
    required this.type,
    required this.contextType,
    required this.contextId,
    required this.title,
    required this.body,
    required this.senderName,
    required this.createdAt,
    this.itemId,
    this.amountPaise,
    this.inviteToken,
  });

  /// Strict parse of the FCM data envelope. Returns `null` if the
  /// payload is missing required fields, has an unknown `type`
  /// discriminator, or has an unparseable `createdAt`.
  ///
  /// A `null` return MUST be treated as "drop the notification" — the
  /// caller never rebuilds a half-parsed payload. This is the FR-AC-01
  /// `ActivityFeedItem.fromFirestore` strict-parsing precedent
  /// re-applied to the FCM boundary.
  static NotificationPayload? fromFcmDataMap(Map<String, dynamic> data) {
    final rawType = data['type'];
    if (rawType is! String) return null;
    final parsedType = NotificationTypeX.fromWireName(rawType);
    if (parsedType == null) return null;

    final contextType = data['contextType'];
    if (contextType is! String) return null;
    if (contextType != 'friendship' && contextType != 'group') return null;

    final contextId = data['contextId'];
    if (contextId is! String || contextId.isEmpty) return null;

    final title = data['title'];
    if (title is! String) return null;

    final body = data['body'];
    if (body is! String) return null;

    final senderName = data['senderName'];
    if (senderName is! String) return null;

    final createdAtRaw = data['createdAt'];
    if (createdAtRaw is! String) return null;
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;

    final itemIdRaw = data['itemId'];
    final itemId = itemIdRaw is String ? itemIdRaw : null;

    final inviteTokenRaw = data['inviteToken'];
    final inviteToken = inviteTokenRaw is String ? inviteTokenRaw : null;

    final amountPaiseRaw = data['amountPaise'];
    int? amountPaise;
    if (amountPaiseRaw is String) {
      amountPaise = int.tryParse(amountPaiseRaw);
    } else if (amountPaiseRaw is int) {
      // Defensive — the wire is string-only per FCM constraints, but
      // an integer-typed source (e.g. a hand-rolled test fixture)
      // should still parse cleanly.
      amountPaise = amountPaiseRaw;
    }

    return NotificationPayload(
      type: parsedType,
      contextType: contextType,
      contextId: contextId,
      title: title,
      body: body,
      senderName: senderName,
      createdAt: createdAt,
      itemId: itemId,
      amountPaise: amountPaise,
      inviteToken: inviteToken,
    );
  }

  /// Discriminator for the client-side deep-link router.
  final NotificationType type;

  /// Either `'friendship'` or `'group'`. v1.0 only emits `'friendship'`
  /// from the producer side; `'group'` is reserved for the Sprint 3
  /// groups epic.
  final String contextType;

  /// Raw friendship-composite id (`{uidA}_{uidB}`) or group id. Not
  /// hashed — the client needs the raw value to navigate.
  final String contextId;

  /// Optional expense / settlement / invite id, for deep-linking to
  /// the per-item screen.
  final String? itemId;

  /// Pre-rendered notification title string from the server.
  final String title;

  /// Pre-rendered notification body string from the server. Already
  /// contains any localised INR formatting; the client must NOT
  /// perform additional paise→INR arithmetic.
  final String body;

  /// Display name of the acting user (payer / settler / sender).
  final String senderName;

  /// Optional integer paise amount. **Use `int` only (Invariant 1).**
  /// Omitted for `group_invite`; present for all other types.
  final int? amountPaise;

  /// Server timestamp of the originating Firestore write, parsed from
  /// the wire ISO-8601 string.
  final DateTime createdAt;

  /// Optional invite token for the `group_invite` payload (forward
  /// compat — no producer in v1.0).
  final String? inviteToken;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPayload &&
        other.type == type &&
        other.contextType == contextType &&
        other.contextId == contextId &&
        other.itemId == itemId &&
        other.title == title &&
        other.body == body &&
        other.senderName == senderName &&
        other.amountPaise == amountPaise &&
        other.createdAt == createdAt &&
        other.inviteToken == inviteToken;
  }

  @override
  int get hashCode => Object.hash(
    type,
    contextType,
    contextId,
    itemId,
    title,
    body,
    senderName,
    amountPaise,
    createdAt,
    inviteToken,
  );
}
