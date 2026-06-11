// FR-AC-04 ReminderCallableAdapter unit tests.
//
// Tests the production `cloud_functions` → `ReminderCallable` shim
// added in PR #55 that translates `FirebaseFunctionsException` into
// the existing typed `ReminderCallableException` consumed by
// `ReminderRepositoryImpl.sendReminder`.
//
// The HttpsCallable + HttpsCallableResult constructors are private to
// the cloud_functions package, so this test implements them via the
// public Dart interface (`implements`) + noSuchMethod for unused
// surface.

// ignore_for_file: cascade_invocations

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/reminders/data/reminder_callable_adapter.dart';
import 'package:onebytwo/features/reminders/data/reminder_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({required super.code, super.details})
    : super(message: 'test: $code');
}

class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this.data);

  @override
  final T data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpsCallable implements HttpsCallable {
  Map<String, dynamic>? capturedParams;
  Object? response;
  Exception? throwError;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    if (parameters is Map) {
      capturedParams = Map<String, dynamic>.from(parameters);
    }
    if (throwError != null) throw throwError!;
    return _FakeHttpsCallableResult<T>(response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeHttpsCallable callable;
  late ReminderCallableAdapter adapter;

  setUp(() {
    callable = _FakeHttpsCallable();
    adapter = ReminderCallableAdapter(callable);
  });

  group('ReminderCallableAdapter — happy path', () {
    test(
      'forwards params to HttpsCallable and returns data map verbatim',
      () async {
        callable.response = <String, dynamic>{
          'success': true,
          'nextAllowedAtIso': '2026-06-12T00:00:00.000Z',
        };

        final result = await adapter.call(<String, dynamic>{
          'toUserId': 'uid-r',
          'contextType': 'friendship',
          'contextId': 'uid-s_uid-r',
        });

        expect(callable.capturedParams, {
          'toUserId': 'uid-r',
          'contextType': 'friendship',
          'contextId': 'uid-s_uid-r',
        });
        expect(result, {
          'success': true,
          'nextAllowedAtIso': '2026-06-12T00:00:00.000Z',
        });
      },
    );
  });

  group('ReminderCallableAdapter — FirebaseFunctionsException translation', () {
    test('RATE_LIMITED → ReminderCallableException with code + errorCode '
        '+ nextAllowedAtIso preserved across the boundary', () async {
      callable.throwError = _TestFirebaseFunctionsException(
        code: 'resource-exhausted',
        details: const <String, dynamic>{
          'errorCode': 'RATE_LIMITED',
          'nextAllowedAtIso': '2026-06-12T00:00:00.000Z',
        },
      );

      try {
        await adapter.call(<String, dynamic>{'toUserId': 'uid-r'});
        fail('Expected ReminderCallableException');
      } on ReminderCallableException catch (e) {
        expect(e.code, 'resource-exhausted');
        expect(e.errorCode, 'RATE_LIMITED');
        expect(e.nextAllowedAtIso, '2026-06-12T00:00:00.000Z');
      }
    });

    test(
      'RECIPIENT_DOESNT_OWE → typed exception; nextAllowedAtIso is null',
      () async {
        callable.throwError = _TestFirebaseFunctionsException(
          code: 'failed-precondition',
          details: const <String, dynamic>{'errorCode': 'RECIPIENT_DOESNT_OWE'},
        );

        try {
          await adapter.call(<String, dynamic>{'toUserId': 'uid-r'});
          fail('Expected ReminderCallableException');
        } on ReminderCallableException catch (e) {
          expect(e.code, 'failed-precondition');
          expect(e.errorCode, 'RECIPIENT_DOESNT_OWE');
          expect(e.nextAllowedAtIso, isNull);
        }
      },
    );

    test(
      'RECIPIENT_PREFS_DISABLED → typed exception; nextAllowedAtIso is null',
      () async {
        callable.throwError = _TestFirebaseFunctionsException(
          code: 'failed-precondition',
          details: const <String, dynamic>{
            'errorCode': 'RECIPIENT_PREFS_DISABLED',
          },
        );

        try {
          await adapter.call(<String, dynamic>{'toUserId': 'uid-r'});
          fail('Expected ReminderCallableException');
        } on ReminderCallableException catch (e) {
          expect(e.code, 'failed-precondition');
          expect(e.errorCode, 'RECIPIENT_PREFS_DISABLED');
          expect(e.nextAllowedAtIso, isNull);
        }
      },
    );

    test(
      'RECIPIENT_NO_TOKENS → typed exception; nextAllowedAtIso is null',
      () async {
        callable.throwError = _TestFirebaseFunctionsException(
          code: 'failed-precondition',
          details: const <String, dynamic>{'errorCode': 'RECIPIENT_NO_TOKENS'},
        );

        try {
          await adapter.call(<String, dynamic>{'toUserId': 'uid-r'});
          fail('Expected ReminderCallableException');
        } on ReminderCallableException catch (e) {
          expect(e.code, 'failed-precondition');
          expect(e.errorCode, 'RECIPIENT_NO_TOKENS');
          expect(e.nextAllowedAtIso, isNull);
        }
      },
    );

    test(
      'opaque (non-FirebaseFunctionsException) failure re-throws as-is',
      () async {
        final opaque = Exception('socket timed out');
        callable.throwError = opaque;

        try {
          await adapter.call(<String, dynamic>{'toUserId': 'uid-r'});
          fail('Expected the original exception to surface');
        } on ReminderCallableException {
          fail('Should not translate non-FirebaseFunctionsException');
        } on Exception catch (e) {
          expect(identical(e, opaque), isTrue);
        }
      },
    );

    test('FirebaseFunctionsException with missing details map yields '
        'UNKNOWN-shape translation (errorCode falls back; '
        'nextAllowedAtIso null)', () async {
      callable.throwError = _TestFirebaseFunctionsException(
        code: 'internal',
        // No details at all.
      );

      try {
        await adapter.call(<String, dynamic>{'toUserId': 'uid-r'});
        fail('Expected ReminderCallableException');
      } on ReminderCallableException catch (e) {
        expect(e.code, 'internal');
        // The fallback is per architect §2.5: when `details` is
        // absent, errorCode == 'UNKNOWN' and nextAllowedAtIso null.
        expect(e.errorCode, 'UNKNOWN');
        expect(e.nextAllowedAtIso, isNull);
      }
    });
  });
}
