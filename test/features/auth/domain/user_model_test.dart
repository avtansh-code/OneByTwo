import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';

// ignore_for_file: subtype_of_sealed_class

/// Minimal fake [DocumentSnapshot] that returns a fixed data map, so
/// [UserModel.fromFirestore] can be exercised without Firebase.
class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(this._data);

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('UserModel.fromFirestore', () {
    test('parses a full user document', () {
      final snapshot = _FakeDocumentSnapshot(<String, dynamic>{
        'phoneNumber': '+919876543210',
        'displayName': 'User One',
        'photoUrl': 'https://example.com/a.jpg',
        'fcmTokens': <String>['tok'],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026)),
        'notificationPrefs': <String, dynamic>{
          'newExpense': true,
          'settlement': true,
          'reminder': false,
        },
        'locale': 'en-IN',
      });

      final model = UserModel.fromFirestore(snapshot);

      expect(model.phoneNumber, '+919876543210');
      expect(model.displayName, 'User One');
      expect(model.photoUrl, 'https://example.com/a.jpg');
      expect(model.locale, 'en-IN');
    });

    test('D13: tolerates the PII-free account-deletion tombstone '
        '(no phoneNumber) and surfaces "Deleted User"', () {
      // FR-AU-09 tombstone shape: users/{uid} replaced with only
      // {displayName: "Deleted User", deletedAt}. The non-nullable
      // phoneNumber cast previously threw, making the friend render as
      // "Unknown" instead of "Deleted User".
      final snapshot = _FakeDocumentSnapshot(<String, dynamic>{
        'displayName': 'Deleted User',
        'deletedAt': Timestamp.fromDate(DateTime.utc(2026)),
      });

      final model = UserModel.fromFirestore(snapshot);

      expect(model.displayName, 'Deleted User');
      expect(model.phoneNumber, '');
      expect(model.photoUrl, isNull);
      // Defaults still apply for the stripped fields.
      expect(model.locale, 'en-IN');
      expect(model.fcmTokens, isEmpty);
    });
  });
}
