// Matching repository unit tests.
//
// Tests the MatchingRepository which calls the lookupUserByPhoneNumber
// Cloud Function and maps responses to domain MatchResult variants.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';

/// Configurable callable that simulates the Cloud Function response.
///
/// Captures the data passed to the function and returns a configurable
/// result or throws a configurable exception.
class FakeLookupCallable {
  /// The response data to return when called.
  Map<String, dynamic>? responseData;

  /// If set, throws this exception instead of returning [responseData].
  Exception? throwError;

  /// Captured call data for verification.
  Map<String, dynamic>? capturedData;

  /// Whether the callable was invoked.
  bool wasCalled = false;

  /// The callable function to pass to [MatchingRepository].
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) async {
    wasCalled = true;
    capturedData = data;
    if (throwError != null) throw throwError!;
    return responseData!;
  }
}

void main() {
  late FakeLookupCallable fakeCallable;
  late MatchingRepository repository;

  setUp(() {
    fakeCallable = FakeLookupCallable();
    repository = MatchingRepository(lookupCallable: fakeCallable.call);
  });

  group('MatchingRepository.lookupUser', () {
    test('passes the phone number in E.164 format to the callable', () async {
      fakeCallable.responseData = {'matched': false};

      await repository.lookupUser('+919876543210');

      expect(fakeCallable.wasCalled, isTrue);
      expect(fakeCallable.capturedData, isNotNull);
      expect(fakeCallable.capturedData!['phoneNumber'], '+919876543210');
    });

    test('maps matched response without photoUrl to Matched variant', () async {
      fakeCallable.responseData = {
        'matched': true,
        'displayName': 'Test User',
        'photoUrl': null,
        'otherUserId': 'uid-xyz',
      };

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<Matched>());
      final matched = result as Matched;
      expect(matched.displayName, 'Test User');
      expect(matched.photoUrl, isNull);
      expect(matched.otherUserId, 'uid-xyz');
    });

    test('maps matched response with photoUrl to Matched variant', () async {
      fakeCallable.responseData = {
        'matched': true,
        'displayName': 'Test User',
        'photoUrl': 'https://example.com/photo.jpg',
        'otherUserId': 'uid-xyz',
      };

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<Matched>());
      final matched = result as Matched;
      expect(matched.displayName, 'Test User');
      expect(matched.photoUrl, 'https://example.com/photo.jpg');
      expect(matched.otherUserId, 'uid-xyz');
    });

    test('maps unmatched response to Unmatched variant', () async {
      fakeCallable.responseData = {'matched': false};

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<Unmatched>());
    });

    test('maps INVALID_INPUT function error to Failed variant', () async {
      fakeCallable.throwError = CloudFunctionException(
        code: 'invalid-argument',
        details: 'INVALID_INPUT',
      );

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<Failed>());
      expect((result as Failed).errorCode, 'INVALID_INPUT');
    });

    test('maps RATE_LIMITED function error to RateLimited variant', () async {
      fakeCallable.throwError = CloudFunctionException(
        code: 'resource-exhausted',
        details: 'RATE_LIMITED',
      );

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<RateLimited>());
    });

    test('maps INTERNAL function error to Failed variant', () async {
      fakeCallable.throwError = CloudFunctionException(
        code: 'internal',
        details: 'INTERNAL',
      );

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<Failed>());
      expect((result as Failed).errorCode, 'INTERNAL');
    });

    test('maps generic exception to Failed with INTERNAL code', () async {
      fakeCallable.throwError = Exception('Network error');

      final result = await repository.lookupUser('+919876543210');

      expect(result, isA<Failed>());
      expect((result as Failed).errorCode, 'INTERNAL');
    });

    test('call data contains only phoneNumber key', () async {
      fakeCallable.responseData = {'matched': false};

      await repository.lookupUser('+919876543210');

      expect(fakeCallable.capturedData!.keys, ['phoneNumber']);
    });
  });
}
