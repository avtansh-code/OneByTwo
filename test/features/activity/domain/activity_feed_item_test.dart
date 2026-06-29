// ActivityFeedItem domain tests (FR-AC-01).
//
// Tests the parsing of Firestore snapshot data into ActivityFeedItem
// (snake_case `type` field → camelCase ActivityEventType enum;
// payload as Map<String, dynamic>; createdAt as DateTime?). Malformed
// payloads are dropped via the onParseFailure callback per the
// strict-parsing pattern established in FriendshipDoc.fromFirestore
// (FR-FR-03 architect §3).
//
// These tests are written BEFORE the implementation exists
// (test-first); they will fail to compile until the production code
// at lib/features/activity/domain/ is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';

void main() {
  group('ActivityEventType — snake_case parsing', () {
    test('expense_added → ActivityEventType.expenseAdded', () {
      expect(
        ActivityEventTypeX.parseSnakeCase('expense_added'),
        ActivityEventType.expenseAdded,
      );
    });

    test('expense_edited → ActivityEventType.expenseEdited', () {
      expect(
        ActivityEventTypeX.parseSnakeCase('expense_edited'),
        ActivityEventType.expenseEdited,
      );
    });

    test('expense_deleted → ActivityEventType.expenseDeleted', () {
      expect(
        ActivityEventTypeX.parseSnakeCase('expense_deleted'),
        ActivityEventType.expenseDeleted,
      );
    });

    test('settlement → ActivityEventType.settlementRecorded', () {
      expect(
        ActivityEventTypeX.parseSnakeCase('settlement'),
        ActivityEventType.settlementRecorded,
      );
    });

    test('friend_added → ActivityEventType.friendAdded', () {
      expect(
        ActivityEventTypeX.parseSnakeCase('friend_added'),
        ActivityEventType.friendAdded,
      );
    });

    test('unknown snake_case returns null', () {
      expect(ActivityEventTypeX.parseSnakeCase('group_change'), isNull);
      expect(ActivityEventTypeX.parseSnakeCase('mystery_event'), isNull);
      expect(ActivityEventTypeX.parseSnakeCase(''), isNull);
    });
  });

  group('ActivityFeedItem.fromFirestore — happy paths', () {
    test('parses an expense_added document into a populated item', () {
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-1',
        data: <String, dynamic>{
          'type': 'expense_added',
          'payload': <String, dynamic>{
            'expenseId': 'exp-1',
            'friendshipId': 'uidA_uidB',
            'description': 'Dinner',
            'amountPaise': 10000,
            'category': 'food',
            'payerId': 'uidA',
            'splits': <Map<String, dynamic>>[
              <String, dynamic>{'userId': 'uidA', 'sharePaise': 5000},
              <String, dynamic>{'userId': 'uidB', 'sharePaise': 5000},
            ],
            'splitMethod': 'equal',
            'hasReceipt': false,
            'authorUid': 'uidA',
          },
          'createdAt': DateTime.utc(2026, 6, 8, 10, 30),
        },
      );

      expect(parsed, isNotNull);
      expect(parsed!.id, 'item-1');
      expect(parsed.type, ActivityEventType.expenseAdded);
      expect(parsed.payload['expenseId'], 'exp-1');
      expect(parsed.payload['friendshipId'], 'uidA_uidB');
      expect(parsed.payload['amountPaise'], 10000);
      expect(parsed.createdAt, DateTime.utc(2026, 6, 8, 10, 30));
    });

    test('parses a settlement document into a populated item', () {
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-2',
        data: <String, dynamic>{
          'type': 'settlement',
          'payload': <String, dynamic>{
            'settlementId': 'set-1',
            'fromUserId': 'uidA',
            'toUserId': 'uidB',
            'amountPaise': 5000,
            'contextType': 'friendship',
            'contextId': 'uidA_uidB',
            'authorUid': 'uidA',
          },
          'createdAt': DateTime.utc(2026, 6, 8, 11),
        },
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, ActivityEventType.settlementRecorded);
      expect(parsed.payload['settlementId'], 'set-1');
      expect(parsed.payload['amountPaise'], 5000);
    });

    test('payload values remain integers (Invariant 1)', () {
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-3',
        data: <String, dynamic>{
          'type': 'expense_added',
          'payload': <String, dynamic>{
            'amountPaise': 12345,
            'expenseId': 'exp-1',
            'friendshipId': 'uidA_uidB',
            'description': 'x',
            'category': 'general',
            'payerId': 'uidA',
            'splits': <Map<String, dynamic>>[],
            'splitMethod': 'equal',
            'hasReceipt': false,
            'authorUid': 'uidA',
          },
          'createdAt': DateTime.utc(2026, 6, 8),
        },
      );
      expect(parsed!.payload['amountPaise'], isA<int>());
      expect(parsed.payload['amountPaise'], isNot(isA<double>()));
    });
  });

  group('ActivityFeedItem.fromFirestore — malformed → drop + log', () {
    test('unknown type returns null and reports via onParseFailure', () {
      final reports = <String>[];
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-bad-1',
        data: <String, dynamic>{
          'type': 'group_change',
          'payload': <String, dynamic>{},
          'createdAt': DateTime.utc(2026, 6, 8),
        },
        onParseFailure: reports.add,
      );

      expect(parsed, isNull);
      expect(reports, hasLength(1));
      expect(reports.first, contains('item-bad-1'));
      expect(reports.first, contains('unknown type'));
    });

    test('missing type returns null and reports', () {
      final reports = <String>[];
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-bad-2',
        data: <String, dynamic>{
          'payload': <String, dynamic>{},
          'createdAt': DateTime.utc(2026, 6, 8),
        },
        onParseFailure: reports.add,
      );

      expect(parsed, isNull);
      expect(reports.single, contains('missing type'));
    });

    test('non-map payload returns null and reports', () {
      final reports = <String>[];
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-bad-3',
        data: <String, dynamic>{
          'type': 'expense_added',
          'payload': 'not-a-map',
          'createdAt': DateTime.utc(2026, 6, 8),
        },
        onParseFailure: reports.add,
      );

      expect(parsed, isNull);
      expect(reports.single, contains('payload'));
    });

    test('missing createdAt is permitted (renders as "Just now")', () {
      final parsed = ActivityFeedItem.fromFirestore(
        id: 'item-no-ts',
        data: <String, dynamic>{
          'type': 'expense_added',
          'payload': <String, dynamic>{
            'expenseId': 'exp-1',
            'friendshipId': 'uidA_uidB',
            'amountPaise': 100,
            'description': 'x',
            'category': 'general',
            'payerId': 'uidA',
            'splits': <Map<String, dynamic>>[],
            'splitMethod': 'equal',
            'hasReceipt': false,
            'authorUid': 'uidA',
          },
        },
      );

      expect(parsed, isNotNull);
      expect(parsed!.createdAt, isNull);
    });
  });

  group('ActivityFeedItem — value equality and immutability', () {
    test('two items with identical fields are equal', () {
      final a = ActivityFeedItem(
        id: 'same',
        type: ActivityEventType.expenseAdded,
        payload: const <String, dynamic>{'expenseId': 'e1'},
        createdAt: DateTime.utc(2026, 6, 8),
      );
      final b = ActivityFeedItem(
        id: 'same',
        type: ActivityEventType.expenseAdded,
        payload: const <String, dynamic>{'expenseId': 'e1'},
        createdAt: DateTime.utc(2026, 6, 8),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
