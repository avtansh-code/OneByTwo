// SettlementDoc strict-parsing tests (FR-FR-04).
//
// Mirrors the friendship_doc_test.dart parse-discipline pattern: every
// malformed entry is rejected (returns null AND fires onParseFailure),
// and a well-formed doc parses fully. Soft-deleted docs still parse —
// the repository is responsible for filtering them out at the next
// layer.
//
// SettlementDoc is the first client-side projection of the top-level
// `settlements/{settlementId}` collection PR #37 shipped rules and a
// trigger for. PR #42 reads it; FR-SE-08 / PR #43 will be the first
// client write producer.
//
// These tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

Map<String, dynamic> _validData({
  String fromUserId = 'uid-from',
  String toUserId = 'uid-to',
  int amountPaise = 5000,
  String contextType = 'friendship',
  String contextId = 'uid-from_uid-to',
  DateTime? date,
  String? note,
  String method = 'manual',
  String verificationStatus = 'unverified',
  String currency = 'INR',
  DateTime? createdAt,
  bool deleted = false,
}) {
  return <String, dynamic>{
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'amountPaise': amountPaise,
    'contextType': contextType,
    'contextId': contextId,
    'date': Timestamp.fromDate(date ?? DateTime(2026, 6)),
    'note': note,
    'method': method,
    'verificationStatus': verificationStatus,
    'currency': currency,
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 6, 1, 12)),
    'deleted': deleted,
  };
}

void main() {
  group('SettlementDoc.fromFirestore — happy path', () {
    test('parses a fully-populated valid document', () {
      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData(amountPaise: 12345, note: 'Pizza split'),
      );

      expect(doc, isNotNull);
      expect(doc!.settlementId, 'sid-1');
      expect(doc.fromUserId, 'uid-from');
      expect(doc.toUserId, 'uid-to');
      expect(doc.amountPaise, 12345);
      expect(doc.amountPaise, isA<int>());
      expect(doc.contextType, 'friendship');
      expect(doc.contextId, 'uid-from_uid-to');
      expect(doc.date, DateTime(2026, 6));
      expect(doc.note, 'Pizza split');
      expect(doc.method, 'manual');
      expect(doc.verificationStatus, 'unverified');
      expect(doc.currency, 'INR');
      expect(doc.createdAt, DateTime(2026, 6, 1, 12));
      expect(doc.deleted, isFalse);
    });

    test('null note is allowed (schema default)', () {
      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData(),
      );
      expect(doc, isNotNull);
      expect(doc!.note, isNull);
    });

    test('deleted == true still parses (filter happens at repository '
        'layer)', () {
      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData(deleted: true),
      );
      expect(doc, isNotNull);
      expect(doc!.deleted, isTrue);
    });

    test('group context type is accepted as well as friendship', () {
      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData(contextType: 'group', contextId: 'gid-1'),
      );
      expect(doc, isNotNull);
      expect(doc!.contextType, 'group');
    });
  });

  group('SettlementDoc.fromFirestore — strict parsing', () {
    test('missing required field returns null and fires onParseFailure', () {
      final failures = <String>[];
      final data = _validData()..remove('amountPaise');

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: data,
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
      expect(failures.single, contains('sid-1'));
      expect(failures.single, contains('amountPaise'));
    });

    test('amountPaise as String returns null and fires onParseFailure', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()..['amountPaise'] = '5000',
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
      expect(failures.single, contains('amountPaise'));
    });

    test('amountPaise as double returns null', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()..['amountPaise'] = 50.0,
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
    });

    test('amountPaise == 0 returns null (must be positive per Invariant 1)',
        () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData(amountPaise: 0),
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
      expect(failures.single, contains('amountPaise'));
    });

    test('amountPaise negative returns null', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData(amountPaise: -100),
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
    });

    test('non-string fromUserId returns null', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()..['fromUserId'] = 42,
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
      expect(failures.single, contains('fromUserId'));
    });

    test('non-Timestamp date returns null', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()..['date'] = '2026-06-01',
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
      expect(failures.single, contains('date'));
    });

    test('non-bool deleted returns null', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()..['deleted'] = 'false',
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
    });

    test('omitted optional onParseFailure does NOT throw', () {
      expect(
        () => SettlementDoc.fromFirestore(
          id: 'sid-1',
          data: _validData()..remove('amountPaise'),
        ),
        returnsNormally,
      );
    });

    test('DateTime value (not Timestamp) is also accepted for date / createdAt',
        () {
      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()
          ..['date'] = DateTime(2026, 6, 5)
          ..['createdAt'] = DateTime(2026, 6, 5, 10),
      );
      expect(doc, isNotNull);
      expect(doc!.date, DateTime(2026, 6, 5));
      expect(doc.createdAt, DateTime(2026, 6, 5, 10));
    });

    test('non-string note (when present) returns null', () {
      final failures = <String>[];

      final doc = SettlementDoc.fromFirestore(
        id: 'sid-1',
        data: _validData()..['note'] = 42,
        onParseFailure: failures.add,
      );

      expect(doc, isNull);
      expect(failures, hasLength(1));
      expect(failures.single, contains('note'));
    });
  });
}
