// NotificationPayload domain parse tests (FR-AC-03).
//
// Verifies the Dart-side parsing of the FCM data envelope defined by
// `functions/src/notifications/types.ts`. The six `type` values are the
// discriminator the client routes on.
//
// Tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

void main() {
  group('NotificationTypeX.fromWireName', () {
    test('parses each of the six snake_case wire values', () {
      expect(
        NotificationTypeX.fromWireName('expense_added'),
        NotificationType.expenseAdded,
      );
      expect(
        NotificationTypeX.fromWireName('expense_edited'),
        NotificationType.expenseEdited,
      );
      expect(
        NotificationTypeX.fromWireName('expense_deleted'),
        NotificationType.expenseDeleted,
      );
      expect(
        NotificationTypeX.fromWireName('settlement_received'),
        NotificationType.settlementReceived,
      );
      expect(
        NotificationTypeX.fromWireName('reminder'),
        NotificationType.reminder,
      );
      expect(
        NotificationTypeX.fromWireName('group_invite'),
        NotificationType.groupInvite,
      );
    });

    test('returns null for unknown wire values (forward-incompat loud)', () {
      expect(NotificationTypeX.fromWireName('unknown_type'), isNull);
      expect(NotificationTypeX.fromWireName(''), isNull);
      expect(NotificationTypeX.fromWireName('expenseAdded'), isNull);
    });
  });

  group('NotificationPayload.fromFcmDataMap — happy path', () {
    test('parses an expense_added payload with all fields populated', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_added',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'itemId': 'expense-1',
        'title': 'Rahul added an expense',
        'body': 'Dinner — Rs.600. You owe Rs.300.',
        'senderName': 'Rahul',
        'amountPaise': '60000',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.type, NotificationType.expenseAdded);
      expect(payload.contextType, 'friendship');
      expect(payload.contextId, 'uid-a_uid-b');
      expect(payload.itemId, 'expense-1');
      expect(payload.title, 'Rahul added an expense');
      expect(payload.body, 'Dinner — Rs.600. You owe Rs.300.');
      expect(payload.senderName, 'Rahul');
      expect(payload.amountPaise, 60000);
      expect(payload.createdAt, DateTime.parse('2026-06-08T10:00:00.000Z'));
      expect(payload.inviteToken, isNull);
    });

    test('parses a settlement_received payload', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'settlement_received',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'itemId': 'settlement-9',
        'title': 'Priya settled up',
        'body': 'You received Rs.350.',
        'senderName': 'Priya',
        'amountPaise': '35000',
        'createdAt': '2026-06-08T11:30:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.type, NotificationType.settlementReceived);
      expect(payload.itemId, 'settlement-9');
      expect(payload.amountPaise, 35000);
    });

    test('parses a reminder payload', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'reminder',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'title': 'Reminder from Rahul',
        'body': 'Rahul is nudging you about Rs.500.',
        'senderName': 'Rahul',
        'amountPaise': '50000',
        'createdAt': '2026-06-08T12:00:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.type, NotificationType.reminder);
      expect(payload.itemId, isNull);
    });

    test('parses a group_invite payload (no amountPaise, has inviteToken)', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'group_invite',
        'contextType': 'group',
        'contextId': 'group-7',
        'title': 'Rahul invited you to a group',
        'body': 'Join "Goa Trip" to start splitting.',
        'senderName': 'Rahul',
        'inviteToken': 'token-abc-123',
        'createdAt': '2026-06-08T13:00:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.type, NotificationType.groupInvite);
      expect(payload.contextType, 'group');
      expect(payload.amountPaise, isNull);
      expect(payload.inviteToken, 'token-abc-123');
    });

    test('parses an expense_deleted payload (no itemId)', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_deleted',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'title': 'Rahul deleted an expense',
        'body': 'Dinner (Rs.600) was removed.',
        'senderName': 'Rahul',
        'amountPaise': '60000',
        'createdAt': '2026-06-08T14:00:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.type, NotificationType.expenseDeleted);
      expect(payload.itemId, isNull);
      expect(payload.amountPaise, 60000);
    });
  });

  group('NotificationPayload.fromFcmDataMap — defensive parse', () {
    test('returns null when `type` field is missing', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNull);
    });

    test('returns null when `type` is unknown (forward-incompat loud)', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_archived',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNull);
    });

    test('returns null when `contextType` field is missing', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_added',
        'contextId': 'uid-a_uid-b',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNull);
    });

    test('returns null when `contextId` field is missing', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_added',
        'contextType': 'friendship',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNull);
    });

    test('returns null when `createdAt` is unparseable', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_added',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'amountPaise': '600',
        'createdAt': 'not-a-date',
      });
      expect(payload, isNull);
    });

    test('amountPaise is null when missing (group_invite path)', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'group_invite',
        'contextType': 'group',
        'contextId': 'group-7',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'inviteToken': 'tok',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.amountPaise, isNull);
    });

    test('amountPaise is null when unparseable string (defensive)', () {
      final payload = NotificationPayload.fromFcmDataMap(<String, dynamic>{
        'type': 'expense_added',
        'contextType': 'friendship',
        'contextId': 'uid-a_uid-b',
        'title': 't',
        'body': 'b',
        'senderName': 'n',
        'amountPaise': 'NaN',
        'createdAt': '2026-06-08T10:00:00.000Z',
      });
      expect(payload, isNotNull);
      expect(payload!.amountPaise, isNull);
    });
  });
}
