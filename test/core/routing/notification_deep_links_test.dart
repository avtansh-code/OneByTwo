// Pure-function tests for NotificationDeepLinks.resolve (FR-AC-03 +
// FR-AC-05).
//
// The resolver is a pure function over (NotificationPayload, currentUid)
// → DeepLinkTarget. No BuildContext, no navigation. The navigation
// helper is tested via DeepLinkHandler / ActivityFeedScreen integration
// tests separately.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/routing/notification_deep_links.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

NotificationPayload _p({
  required NotificationType type,
  String contextType = 'friendship',
  String contextId = 'uid-me_uid-other',
  String? itemId = 'item-1',
  int? amountPaise = 60000,
  String? inviteToken,
}) {
  return NotificationPayload(
    type: type,
    contextType: contextType,
    contextId: contextId,
    itemId: itemId,
    title: 't',
    body: 'b',
    senderName: 'n',
    amountPaise: amountPaise,
    createdAt: DateTime.utc(2026, 6, 8),
    inviteToken: inviteToken,
  );
}

void main() {
  group('NotificationDeepLinks.resolve — expense paths', () {
    test('expense_added with valid friendship + itemId → '
        'DeepLinkExpenseDetail', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.expenseAdded),
        'uid-me',
      );
      expect(t, isA<DeepLinkExpenseDetail>());
      final ed = t as DeepLinkExpenseDetail;
      expect(ed.friendshipId, 'uid-me_uid-other');
      expect(ed.expenseId, 'item-1');
      expect(ed.currentUid, 'uid-me');
      expect(ed.otherUid, 'uid-other');
    });

    test('expense_edited with valid friendship + itemId → '
        'DeepLinkExpenseDetail', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.expenseEdited, itemId: 'item-9'),
        'uid-me',
      );
      expect(t, isA<DeepLinkExpenseDetail>());
      expect((t as DeepLinkExpenseDetail).expenseId, 'item-9');
    });

    test('expense_added with missing itemId → DeepLinkUnavailable', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.expenseAdded, itemId: null),
        'uid-me',
      );
      expect(t, isA<DeepLinkUnavailable>());
    });

    test('expense_deleted (regardless of itemId) → DeepLinkUnavailable '
        'with "This item is no longer available" semantics', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.expenseDeleted),
        'uid-me',
      );
      expect(t, isA<DeepLinkUnavailable>());
    });

    test('expense_added with malformed composite contextId → '
        'DeepLinkUnavailable', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.expenseAdded, contextId: 'not-a-composite'),
        'uid-me',
      );
      expect(t, isA<DeepLinkUnavailable>());
    });

    test('expense_added where current user is NOT a member of the '
        'composite → DeepLinkUnavailable', () {
      final t = NotificationDeepLinks.resolve(
        _p(
          type: NotificationType.expenseAdded,
          contextId: 'uid-alpha_uid-beta',
        ),
        'uid-me',
      );
      expect(t, isA<DeepLinkUnavailable>());
    });
  });

  group('NotificationDeepLinks.resolve — settlement / reminder', () {
    test(
      'settlement_received with valid friendship → DeepLinkFriendDetail',
      () {
        final t = NotificationDeepLinks.resolve(
          _p(type: NotificationType.settlementReceived),
          'uid-me',
        );
        expect(t, isA<DeepLinkFriendDetail>());
        final fd = t as DeepLinkFriendDetail;
        expect(fd.friendshipId, 'uid-me_uid-other');
        expect(fd.currentUid, 'uid-me');
        expect(fd.otherUid, 'uid-other');
      },
    );

    test('reminder with valid friendship → DeepLinkFriendDetail', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.reminder, itemId: null),
        'uid-me',
      );
      expect(t, isA<DeepLinkFriendDetail>());
    });

    test('settlement_received with malformed composite → '
        'DeepLinkUnavailable', () {
      final t = NotificationDeepLinks.resolve(
        _p(type: NotificationType.settlementReceived, contextId: 'malformed'),
        'uid-me',
      );
      expect(t, isA<DeepLinkUnavailable>());
    });

    test('settlement_received where current user is NOT a member → '
        'DeepLinkUnavailable', () {
      final t = NotificationDeepLinks.resolve(
        _p(
          type: NotificationType.settlementReceived,
          contextId: 'uid-alpha_uid-beta',
        ),
        'uid-me',
      );
      expect(t, isA<DeepLinkUnavailable>());
    });
  });

  group('NotificationDeepLinks.resolve — group_invite (forward-compat)', () {
    test('group_invite → DeepLinkGroupsComingSoon (no producer in v1.0)', () {
      final t = NotificationDeepLinks.resolve(
        _p(
          type: NotificationType.groupInvite,
          contextType: 'group',
          contextId: 'group-7',
          itemId: null,
          amountPaise: null,
          inviteToken: 'tok',
        ),
        'uid-me',
      );
      expect(t, isA<DeepLinkGroupsComingSoon>());
    });
  });

  group('NotificationDeepLinks.otherUidForFriendship', () {
    test(
      'extracts the other UID when the composite starts with currentUid',
      () {
        final other = NotificationDeepLinks.otherUidForFriendship(
          'uid-me_uid-other',
          'uid-me',
        );
        expect(other, 'uid-other');
      },
    );

    test('extracts the other UID when the composite ends with currentUid', () {
      final other = NotificationDeepLinks.otherUidForFriendship(
        'uid-other_uid-me',
        'uid-me',
      );
      expect(other, 'uid-other');
    });

    test('returns null when the composite has the wrong arity', () {
      expect(
        NotificationDeepLinks.otherUidForFriendship('only-one', 'uid-me'),
        isNull,
      );
      expect(
        NotificationDeepLinks.otherUidForFriendship('a_b_c', 'uid-me'),
        isNull,
      );
    });

    test(
      'returns null when the currentUid is not present in the composite',
      () {
        expect(
          NotificationDeepLinks.otherUidForFriendship(
            'uid-alpha_uid-beta',
            'uid-me',
          ),
          isNull,
        );
      },
    );
  });
}
