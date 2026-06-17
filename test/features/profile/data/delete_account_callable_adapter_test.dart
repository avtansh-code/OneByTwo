// FR-AU-09 DeleteAccountCallableAdapter + DeleteAccountRepository unit tests.
//
// Tests the production `cloud_functions` -> `DeleteAccountCallable` shim
// that translates `FirebaseFunctionsException` into the typed
// `DeleteAccountException`, and the repository's success/failure mapping.
//
// The HttpsCallable + HttpsCallableResult constructors are private to the
// cloud_functions package, so this test implements them via the public Dart
// interface (`implements`) + noSuchMethod for unused surface.

// ignore_for_file: cascade_invocations

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/profile/data/delete_account_callable_adapter.dart';
import 'package:onebytwo/features/profile/data/delete_account_repository.dart';

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
  int calls = 0;
  Object? response;
  Exception? throwError;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls++;
    if (throwError != null) throw throwError!;
    return _FakeHttpsCallableResult<T>(response as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeHttpsCallable callable;
  late DeleteAccountCallableAdapter adapter;

  setUp(() {
    callable = _FakeHttpsCallable();
    adapter = DeleteAccountCallableAdapter(callable);
  });

  group('DeleteAccountCallableAdapter — happy path', () {
    test('invokes the callable and returns the data map verbatim', () async {
      callable.response = <String, dynamic>{'success': true};
      final result = await adapter.call();
      expect(callable.calls, 1);
      expect(result, {'success': true});
    });

    test('returns an empty map when the callable data is not a Map', () async {
      callable.response = 'not-a-map';
      expect(await adapter.call(), <String, dynamic>{});
    });
  });

  group('DeleteAccountCallableAdapter — exception translation', () {
    test('translates FirebaseFunctionsException with errorCode', () async {
      callable.throwError = _TestFirebaseFunctionsException(
        code: 'internal',
        details: const {'errorCode': 'INTERNAL'},
      );
      expect(
        () => adapter.call(),
        throwsA(
          isA<DeleteAccountException>()
              .having((e) => e.code, 'code', 'internal')
              .having((e) => e.errorCode, 'errorCode', 'INTERNAL'),
        ),
      );
    });

    test('maps a missing details map to errorCode UNKNOWN', () async {
      callable.throwError = _TestFirebaseFunctionsException(
        code: 'unauthenticated',
      );
      expect(
        () => adapter.call(),
        throwsA(
          isA<DeleteAccountException>().having(
            (e) => e.errorCode,
            'errorCode',
            'UNKNOWN',
          ),
        ),
      );
    });
  });

  group('DeleteAccountRepository — success/failure mapping', () {
    test('completes normally when the callable returns success', () async {
      final repo = DeleteAccountRepository(
        callable: () async => {'success': true},
      );
      await expectLater(repo.deleteAccount(), completes);
    });

    test('throws when the callable response is not success', () async {
      final repo = DeleteAccountRepository(
        callable: () async => {'success': false},
      );
      await expectLater(
        repo.deleteAccount(),
        throwsA(isA<DeleteAccountException>()),
      );
    });

    test(
      'propagates a DeleteAccountException raised by the callable',
      () async {
        final repo = DeleteAccountRepository(
          callable: () async => throw const DeleteAccountException(
            code: 'internal',
            errorCode: 'INTERNAL',
          ),
        );
        await expectLater(
          repo.deleteAccount(),
          throwsA(
            isA<DeleteAccountException>().having(
              (e) => e.errorCode,
              'errorCode',
              'INTERNAL',
            ),
          ),
        );
      },
    );
  });
}
