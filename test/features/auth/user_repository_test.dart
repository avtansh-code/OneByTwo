// FR-PR-03 UserRepository.updateNotificationPrefs writer tests.
//
// Verifies the dot-path partial-map update shape ratified in architect
// §2.2 of the FR-PR-03 + FR-AC-04 notification-preferences story:
//
//   await _firestore.collection('users').doc(uid).update({
//     for (final entry in prefs.entries)
//       'notificationPrefs.${entry.key}': entry.value,
//     'updatedAt': FieldValue.serverTimestamp(),
//   });
//
// `fake_cloud_firestore` is not in the pubspec, so the tests inject a
// minimal `FirebaseFirestore` fake via `implements` + `noSuchMethod`
// that captures the `update()` payload. Only the methods touched by
// the writer are implemented — anything else falls through to
// noSuchMethod which throws NoSuchMethodError if invoked. This is by
// design: it surfaces drift if the writer ever calls something the
// tests don't model.

// ignore_for_file: cascade_invocations
// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/auth/data/user_repository.dart';

// ---------------------------------------------------------------------------
// Minimal Firestore fakes
// ---------------------------------------------------------------------------
//
// `DocumentReference` and `CollectionReference` are sealed at the
// cloud_firestore package boundary, but `implements` + `noSuchMethod`
// remains the only way to inject a fake without pulling in
// `fake_cloud_firestore` (which is not in pubspec). The fakes only
// model the methods the writer touches (`collection().doc().update()`).

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  Map<Object, Object?>? capturedUpdate;
  int updateCallCount = 0;
  Exception? throwOnUpdate;

  @override
  Future<void> update(Map<Object, Object?> data) async {
    updateCallCount++;
    capturedUpdate = Map<Object, Object?>.from(data);
    if (throwOnUpdate != null) throw throwOnUpdate!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Map<String, _FakeDocumentReference> _docs =
      <String, _FakeDocumentReference>{};
  String? lastDocPath;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = path ?? 'auto';
    lastDocPath = id;
    return _docs.putIfAbsent(id, _FakeDocumentReference.new);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  final Map<String, _FakeCollectionReference> _cols =
      <String, _FakeCollectionReference>{};
  String? lastCollectionPath;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    lastCollectionPath = path;
    return _cols.putIfAbsent(path, _FakeCollectionReference.new);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubFirebaseStorage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserRepository _repo(_FakeFirestore firestore) =>
    UserRepository(firestore: firestore, storage: _StubFirebaseStorage());

_FakeDocumentReference _userDoc(_FakeFirestore firestore, String uid) {
  final col = firestore.collection('users') as _FakeCollectionReference;
  return col.doc(uid) as _FakeDocumentReference;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UserRepository — updateNotificationPrefs writer (FR-PR-03)', () {
    test('single-key flip issues update with exactly two payload keys: '
        'the dot-path entry and updatedAt server timestamp', () async {
      final firestore = _FakeFirestore();
      final repo = _repo(firestore);

      await repo.updateNotificationPrefs(
        uid: 'uid-test',
        prefs: const {'reminder': false},
      );

      expect(firestore.lastCollectionPath, 'users');
      final doc = _userDoc(firestore, 'uid-test');
      expect(doc.updateCallCount, 1);
      expect(doc.capturedUpdate, isNotNull);

      final payload = doc.capturedUpdate!;
      // Exactly two keys.
      expect(payload.keys.toSet(), {'notificationPrefs.reminder', 'updatedAt'});
      expect(payload['notificationPrefs.reminder'], isFalse);
      expect(payload['updatedAt'], isA<FieldValue>());
    });

    test('multi-key flip writes one dot-path entry per key plus updatedAt; '
        'untouched keys are NOT present in the payload', () async {
      final firestore = _FakeFirestore();
      final repo = _repo(firestore);

      await repo.updateNotificationPrefs(
        uid: 'uid-test',
        prefs: const {'newExpense': true, 'settlement': false},
      );

      final doc = _userDoc(firestore, 'uid-test');
      final payload = doc.capturedUpdate!;
      expect(payload.keys.toSet(), {
        'notificationPrefs.newExpense',
        'notificationPrefs.settlement',
        'updatedAt',
      });
      expect(payload['notificationPrefs.newExpense'], isTrue);
      expect(payload['notificationPrefs.settlement'], isFalse);
      // The reminder key is NOT in the payload.
      expect(payload.containsKey('notificationPrefs.reminder'), isFalse);
      expect(payload['updatedAt'], isA<FieldValue>());
    });

    test(
      'empty prefs map is a no-op (defensive: no Firestore update issued)',
      () async {
        final firestore = _FakeFirestore();
        final repo = _repo(firestore);

        await repo.updateNotificationPrefs(
          uid: 'uid-test',
          prefs: const <String, bool>{},
        );

        // The collection / doc were never accessed.
        expect(firestore.lastCollectionPath, isNull);
      },
    );

    test('AC-23: writer NEVER touches displayName / photoUrl / fcmTokens / '
        'locale / phoneNumber / createdAt keys', () async {
      final firestore = _FakeFirestore();
      final repo = _repo(firestore);

      await repo.updateNotificationPrefs(
        uid: 'uid-test',
        prefs: const {
          'newExpense': false,
          'settlement': false,
          'reminder': false,
        },
      );

      final payload = _userDoc(firestore, 'uid-test').capturedUpdate!;
      for (final forbidden in const [
        'displayName',
        'photoUrl',
        'fcmTokens',
        'locale',
        'phoneNumber',
        'createdAt',
      ]) {
        expect(
          payload.containsKey(forbidden),
          isFalse,
          reason: '$forbidden must NOT appear in the writer payload',
        );
        // Also assert the dot-path variant is absent.
        expect(
          payload.keys.where((k) => k.toString().startsWith(forbidden)),
          isEmpty,
          reason: '$forbidden.* must NOT appear in the writer payload',
        );
      }
    });

    test('writes target users/{uid} — uid is forwarded to .doc()', () async {
      final firestore = _FakeFirestore();
      final repo = _repo(firestore);

      await repo.updateNotificationPrefs(
        uid: 'uid-abc-123',
        prefs: const {'reminder': false},
      );

      final col = firestore.collection('users') as _FakeCollectionReference;
      expect(col.lastDocPath, 'uid-abc-123');
    });

    test('Firestore update rejection propagates as FirebaseException so the '
        'controller can classify error_code', () async {
      final firestore = _FakeFirestore();
      final repo = _repo(firestore);

      // Pre-register the doc and arm it to throw.
      final doc = _userDoc(firestore, 'uid-test');
      doc.throwOnUpdate = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'offline',
      );

      await expectLater(
        repo.updateNotificationPrefs(
          uid: 'uid-test',
          prefs: const {'reminder': false},
        ),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
