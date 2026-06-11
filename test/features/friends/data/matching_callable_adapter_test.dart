// PR #34 / FR-AC-04 MatchingCallableAdapter unit tests.
//
// Tests the production `cloud_functions` → `LookupCallable` shim
// added in PR #55 that translates `FirebaseFunctionsException` into
// the existing `CloudFunctionException` consumed by
// `MatchingRepository.lookupUser`. Per architect §2.5, the existing
// exception's `details` field is a STRING (not a Map) — the adapter
// populates it from `e.details['errorCode']` and falls back to
// `e.code` if the details map is absent. The exception class is NOT
// renamed (defer the harmonisation per architect §2.10 reconciliation 2).

// ignore_for_file: cascade_invocations

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/friends/data/matching_callable_adapter.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';

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
  late MatchingCallableAdapter adapter;

  setUp(() {
    callable = _FakeHttpsCallable();
    adapter = MatchingCallableAdapter(callable);
  });

  group('MatchingCallableAdapter — happy path', () {
    test(
      'forwards phoneNumber to HttpsCallable and returns data verbatim',
      () async {
        callable.response = <String, dynamic>{
          'matched': true,
          'displayName': 'Alice',
          'photoUrl': null,
          'otherUserId': 'uid-alice',
        };

        final result = await adapter.call(<String, dynamic>{
          'phoneNumber': '+919876543210',
        });

        expect(callable.capturedParams, {'phoneNumber': '+919876543210'});
        expect(result, {
          'matched': true,
          'displayName': 'Alice',
          'photoUrl': null,
          'otherUserId': 'uid-alice',
        });
      },
    );
  });

  group('MatchingCallableAdapter — FirebaseFunctionsException translation', () {
    test(
      'RATE_LIMITED → CloudFunctionException(code, details: "RATE_LIMITED")',
      () async {
        callable.throwError = _TestFirebaseFunctionsException(
          code: 'resource-exhausted',
          details: const <String, dynamic>{'errorCode': 'RATE_LIMITED'},
        );

        try {
          await adapter.call(<String, dynamic>{'phoneNumber': '+919876543210'});
          fail('Expected CloudFunctionException');
        } on CloudFunctionException catch (e) {
          expect(e.code, 'resource-exhausted');
          // Details is the STRING from e.details['errorCode'].
          expect(e.details, 'RATE_LIMITED');
        }
      },
    );

    test(
      'INVALID_INPUT → CloudFunctionException with details = string',
      () async {
        callable.throwError = _TestFirebaseFunctionsException(
          code: 'invalid-argument',
          details: const <String, dynamic>{'errorCode': 'INVALID_INPUT'},
        );

        try {
          await adapter.call(<String, dynamic>{'phoneNumber': '+919876543210'});
          fail('Expected CloudFunctionException');
        } on CloudFunctionException catch (e) {
          expect(e.code, 'invalid-argument');
          expect(e.details, 'INVALID_INPUT');
        }
      },
    );

    test(
      'INTERNAL → CloudFunctionException with details = "INTERNAL"',
      () async {
        callable.throwError = _TestFirebaseFunctionsException(
          code: 'internal',
          details: const <String, dynamic>{'errorCode': 'INTERNAL'},
        );

        try {
          await adapter.call(<String, dynamic>{'phoneNumber': '+919876543210'});
          fail('Expected CloudFunctionException');
        } on CloudFunctionException catch (e) {
          expect(e.code, 'internal');
          expect(e.details, 'INTERNAL');
        }
      },
    );

    test('missing details map → details falls back to e.code', () async {
      callable.throwError = _TestFirebaseFunctionsException(
        code: 'unavailable',
      );

      try {
        await adapter.call(<String, dynamic>{'phoneNumber': '+919876543210'});
        fail('Expected CloudFunctionException');
      } on CloudFunctionException catch (e) {
        expect(e.code, 'unavailable');
        // Per architect §2.5 fallback rule.
        expect(e.details, 'unavailable');
      }
    });

    test(
      'opaque (non-FirebaseFunctionsException) failure re-throws as-is',
      () async {
        final opaque = Exception('socket timed out');
        callable.throwError = opaque;

        try {
          await adapter.call(<String, dynamic>{'phoneNumber': '+919876543210'});
          fail('Expected the original exception to surface');
        } on CloudFunctionException {
          fail('Should not translate non-FirebaseFunctionsException');
        } on Exception catch (e) {
          expect(identical(e, opaque), isTrue);
        }
      },
    );
  });
}
