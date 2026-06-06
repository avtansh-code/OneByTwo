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
      final doc = SettlementDoc.fromFirestore(id: 'sid-1', data: _validData());
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

    test(
      'amountPaise == 0 returns null (must be positive per Invariant 1)',
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
      },
    );

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

    test(
      'DateTime value (not Timestamp) is also accepted for date / createdAt',
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
      },
    );

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

  group('SettlementDoc equality', () {
    SettlementDoc base() => SettlementDoc(
      settlementId: 'sid-1',
      fromUserId: 'uid-from',
      toUserId: 'uid-to',
      amountPaise: 5000,
      contextType: 'friendship',
      contextId: 'uid-from_uid-to',
      date: DateTime(2026, 6),
      note: 'Pizza',
      method: 'manual',
      verificationStatus: 'unverified',
      currency: 'INR',
      createdAt: DateTime(2026, 6, 1, 12),
      deleted: false,
    );

    test('identical instances are equal and share hashCode', () {
      final a = base();
      expect(a, equals(a));
      expect(a.hashCode, equals(a.hashCode));
    });

    test('two SettlementDocs with the same fields are equal and share '
        'hashCode', () {
      expect(base(), equals(base()));
      expect(base().hashCode, equals(base().hashCode));
    });

    test('different settlementId breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: 'sid-2',
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different fromUserId breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: 'uid-other',
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different toUserId breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: 'uid-other',
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different amountPaise breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise + 1,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different contextType breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: 'group',
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different contextId breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: 'other_pair',
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different date breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: DateTime(2026, 6, 2),
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different note breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: 'Different note',
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different method breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: 'upi',
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different verificationStatus breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: 'verified',
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different currency breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: 'USD',
        createdAt: a.createdAt,
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different createdAt breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: DateTime(2026, 6, 1, 13),
        deleted: a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different deleted breaks equality', () {
      final a = base();
      final b = SettlementDoc(
        settlementId: a.settlementId,
        fromUserId: a.fromUserId,
        toUserId: a.toUserId,
        amountPaise: a.amountPaise,
        contextType: a.contextType,
        contextId: a.contextId,
        date: a.date,
        note: a.note,
        method: a.method,
        verificationStatus: a.verificationStatus,
        currency: a.currency,
        createdAt: a.createdAt,
        deleted: !a.deleted,
      );
      expect(a, isNot(equals(b)));
    });

    test('different runtime type breaks equality', () {
      expect(base(), isNot(equals('not a SettlementDoc')));
    });
  });

  group('SettlementDoc.toCreateMap — write-side shape (FR-SE-05)', () {
    SettlementDoc baseDoc({
      String fromUserId = 'uid-from',
      String toUserId = 'uid-to',
      int amountPaise = 5000,
      String? note,
      DateTime? date,
      String contextType = 'friendship',
      String contextId = 'uid-from_uid-to',
    }) {
      return SettlementDoc(
        settlementId: 'unused-on-create',
        fromUserId: fromUserId,
        toUserId: toUserId,
        amountPaise: amountPaise,
        contextType: contextType,
        contextId: contextId,
        date: date ?? DateTime(2026, 6, 5),
        note: note,
        method: 'manual',
        verificationStatus: 'unverified',
        currency: 'INR',
        createdAt: DateTime(2026, 6, 1, 12),
        deleted: false,
      );
    }

    test('contains exactly the keys whitelisted by hasOnlyKnownKeys', () {
      final map = baseDoc().toCreateMap();
      expect(
        map.keys.toSet(),
        equals(<String>{
          'fromUserId',
          'toUserId',
          'amountPaise',
          'contextType',
          'contextId',
          'date',
          'note',
          'method',
          'verificationStatus',
          'currency',
          'createdAt',
          'deleted',
        }),
      );
    });

    test('amountPaise is int (Invariant 1)', () {
      final map = baseDoc(amountPaise: 12345).toCreateMap();
      expect(map['amountPaise'], isA<int>());
      expect(map['amountPaise'], 12345);
    });

    test('date is Timestamp', () {
      final map = baseDoc(date: DateTime(2026, 6, 5)).toCreateMap();
      expect(map['date'], isA<Timestamp>());
      expect((map['date'] as Timestamp).toDate(), DateTime(2026, 6, 5));
    });

    test('createdAt is FieldValue.serverTimestamp() (request.time)', () {
      final map = baseDoc().toCreateMap();
      // FieldValue.serverTimestamp() returns a sentinel — we assert by
      // type and by NOT equalling a literal Timestamp.
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('method == "manual" (ARCH-EXT-01)', () {
      final map = baseDoc().toCreateMap();
      expect(map['method'], 'manual');
    });

    test('currency == "INR" (ARCH-EXT-02)', () {
      final map = baseDoc().toCreateMap();
      expect(map['currency'], 'INR');
    });

    test('verificationStatus == "unverified" (ARCH-EXT-06)', () {
      final map = baseDoc().toCreateMap();
      expect(map['verificationStatus'], 'unverified');
    });

    test('deleted == false', () {
      final map = baseDoc().toCreateMap();
      expect(map['deleted'], false);
    });

    test('note is null when omitted (canonical §2.3)', () {
      final map = baseDoc().toCreateMap();
      expect(map.containsKey('note'), isTrue);
      expect(map['note'], isNull);
    });

    test('note is preserved when present', () {
      final map = baseDoc(note: 'Pizza').toCreateMap();
      expect(map['note'], 'Pizza');
    });

    test('fromUserId / toUserId / contextType / contextId are strings', () {
      final map = baseDoc(
        fromUserId: 'uid-me',
        toUserId: 'uid-friend',
        contextId: 'uid-friend_uid-me',
      ).toCreateMap();
      expect(map['fromUserId'], 'uid-me');
      expect(map['toUserId'], 'uid-friend');
      expect(map['contextType'], 'friendship');
      expect(map['contextId'], 'uid-friend_uid-me');
    });

    test('group context type is preserved', () {
      final map = baseDoc(
        contextType: 'group',
        contextId: 'gid-1',
      ).toCreateMap();
      expect(map['contextType'], 'group');
      expect(map['contextId'], 'gid-1');
    });

    test('no extra keys leak into the map (defends hasOnlyKnownKeys)', () {
      final map = baseDoc().toCreateMap();
      const forbiddenKeys = ['groupId', 'splits', 'description', 'category'];
      for (final k in forbiddenKeys) {
        expect(map.containsKey(k), isFalse, reason: 'unexpected key: $k');
      }
    });
  });
}
