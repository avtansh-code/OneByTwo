// Shared notification payload builder — reused by the DC-09 notifications
// reskin gate (notifications_haldi_reskin_test.dart) and the golden scaffold
// (dc09_activity_golden_test.dart) so neither file redefines the builder (the
// DC-07 / DC-08 shared-fakes review lesson).

import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

/// Builds a [NotificationPayload] for the in-app banner. `type` drives the
/// per-type icon + hue (the DC-09 hex re-point); everything else takes a
/// sensible default.
NotificationPayload notificationPayload({
  NotificationType type = NotificationType.expenseAdded,
  String title = 'Rahul added an expense',
  String body = 'Dinner — Rs.600.',
}) {
  return NotificationPayload(
    type: type,
    contextType: 'friendship',
    contextId: 'uid-a_uid-b',
    itemId: 'expense-1',
    title: title,
    body: body,
    senderName: 'Rahul',
    amountPaise: 60000,
    createdAt: DateTime.utc(2026, 6, 8),
  );
}
