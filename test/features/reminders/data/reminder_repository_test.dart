// FR-SE-09 ReminderRepository unit tests.
//
// Mirrors test/features/friends/matching_repository_test.dart — the
// callable is mocked behind a typedef so no Firebase initialisation
// is needed. The repository wraps the `sendReminderNotification`
// callable and maps Cloud Function exceptions to the typed
// `ReminderSendResult` discriminated union.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/reminders/data/reminder_repository.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_error.dart';

/// Configurable callable that simulates the sendReminderNotification
/// Cloud Function response.
class FakeReminderCallable {
  Map<String, dynamic>? responseData;
  Exception? throwError;
  Map<String, dynamic>? capturedData;
  bool wasCalled = false;

  Future<Map<String, dynamic>> call(Map<String, dynamic> data) async {
    wasCalled = true;
    capturedData = data;
    if (throwError != null) throw throwError!;
    return responseData!;
  }
}

void main() {
  late FakeReminderCallable fakeCallable;
  late ReminderRepository repository;

  setUp(() {
    fakeCallable = FakeReminderCallable();
    repository = ReminderRepository(callable: fakeCallable.call);
  });

  group('ReminderRepository.sendReminder', () {
    test('passes toUserId, contextType, contextId to callable', () async {
      fakeCallable.responseData = {
        'success': true,
        'nextAllowedAtIso': '2026-06-09T12:00:00.000Z',
      };

      await repository.sendReminder(
        toUserId: 'uid-recipient',
        contextType: 'friendship',
        contextId: 'uid-sender_uid-recipient',
      );

      expect(fakeCallable.wasCalled, isTrue);
      expect(fakeCallable.capturedData!['toUserId'], 'uid-recipient');
      expect(fakeCallable.capturedData!['contextType'], 'friendship');
      expect(
        fakeCallable.capturedData!['contextId'],
        'uid-sender_uid-recipient',
      );
      // v1.0 always omits the optional message field.
      expect(fakeCallable.capturedData!.containsKey('message'), isFalse);
    });

    test(
      'maps success response to ReminderSendSuccess with nextAllowedAt',
      () async {
        fakeCallable.responseData = {
          'success': true,
          'nextAllowedAtIso': '2026-06-09T12:00:00.000Z',
        };

        final result = await repository.sendReminder(
          toUserId: 'uid-recipient',
          contextType: 'friendship',
          contextId: 'uid-sender_uid-recipient',
        );

        expect(result, isA<ReminderSendSuccess>());
        final success = result as ReminderSendSuccess;
        expect(
          success.nextAllowedAt.toIso8601String(),
          '2026-06-09T12:00:00.000Z',
        );
      },
    );

    test(
      'maps response with success:false to ReminderSendFailed (defensive)',
      () async {
        fakeCallable.responseData = {
          'success': false,
          'nextAllowedAtIso': '2026-06-09T12:00:00.000Z',
        };

        final result = await repository.sendReminder(
          toUserId: 'uid-recipient',
          contextType: 'friendship',
          contextId: 'uid-sender_uid-recipient',
        );

        expect(result, isA<ReminderSendFailed>());
        expect((result as ReminderSendFailed).errorCode, 'UNKNOWN');
      },
    );

    test(
      'maps response missing nextAllowedAtIso to ReminderSendFailed',
      () async {
        fakeCallable.responseData = {'success': true};

        final result = await repository.sendReminder(
          toUserId: 'uid-recipient',
          contextType: 'friendship',
          contextId: 'uid-sender_uid-recipient',
        );

        expect(result, isA<ReminderSendFailed>());
      },
    );

    test(
      'maps RATE_LIMITED to ReminderSendRateLimited with nextAllowedAt',
      () async {
        fakeCallable.throwError = const ReminderCallableException(
          code: 'resource-exhausted',
          errorCode: 'RATE_LIMITED',
          nextAllowedAtIso: '2026-06-09T00:00:00.000Z',
        );

        final result = await repository.sendReminder(
          toUserId: 'uid-recipient',
          contextType: 'friendship',
          contextId: 'uid-sender_uid-recipient',
        );

        expect(result, isA<ReminderSendRateLimited>());
        final rl = result as ReminderSendRateLimited;
        expect(rl.nextAllowedAt.toIso8601String(), '2026-06-09T00:00:00.000Z');
      },
    );

    test(
      'maps RECIPIENT_DOESNT_OWE to ReminderSendRecipientDoesntOwe',
      () async {
        fakeCallable.throwError = const ReminderCallableException(
          code: 'failed-precondition',
          errorCode: 'RECIPIENT_DOESNT_OWE',
        );

        final result = await repository.sendReminder(
          toUserId: 'uid-recipient',
          contextType: 'friendship',
          contextId: 'uid-sender_uid-recipient',
        );

        expect(result, isA<ReminderSendRecipientDoesntOwe>());
      },
    );

    test(
      'maps RECIPIENT_PREFS_DISABLED to ReminderSendRecipientPrefsDisabled',
      () async {
        fakeCallable.throwError = const ReminderCallableException(
          code: 'failed-precondition',
          errorCode: 'RECIPIENT_PREFS_DISABLED',
        );

        final result = await repository.sendReminder(
          toUserId: 'uid-recipient',
          contextType: 'friendship',
          contextId: 'uid-sender_uid-recipient',
        );

        expect(result, isA<ReminderSendRecipientPrefsDisabled>());
      },
    );

    test('maps RECIPIENT_NO_TOKENS to ReminderSendRecipientNoTokens', () async {
      fakeCallable.throwError = const ReminderCallableException(
        code: 'failed-precondition',
        errorCode: 'RECIPIENT_NO_TOKENS',
      );

      final result = await repository.sendReminder(
        toUserId: 'uid-recipient',
        contextType: 'friendship',
        contextId: 'uid-sender_uid-recipient',
      );

      expect(result, isA<ReminderSendRecipientNoTokens>());
    });

    test('maps FCM_DISPATCH_FAILED to ReminderSendFailed', () async {
      fakeCallable.throwError = const ReminderCallableException(
        code: 'unavailable',
        errorCode: 'FCM_DISPATCH_FAILED',
      );

      final result = await repository.sendReminder(
        toUserId: 'uid-recipient',
        contextType: 'friendship',
        contextId: 'uid-sender_uid-recipient',
      );

      expect(result, isA<ReminderSendFailed>());
      final failed = result as ReminderSendFailed;
      expect(failed.errorCode, 'FCM_DISPATCH_FAILED');
    });

    test('maps an unknown details code to ReminderSendFailed', () async {
      fakeCallable.throwError = const ReminderCallableException(
        code: 'internal',
        errorCode: 'INTERNAL',
      );

      final result = await repository.sendReminder(
        toUserId: 'uid-recipient',
        contextType: 'friendship',
        contextId: 'uid-sender_uid-recipient',
      );

      expect(result, isA<ReminderSendFailed>());
    });

    test('maps a non-callable Exception to ReminderSendFailed', () async {
      fakeCallable.throwError = Exception('network down');

      final result = await repository.sendReminder(
        toUserId: 'uid-recipient',
        contextType: 'friendship',
        contextId: 'uid-sender_uid-recipient',
      );

      expect(result, isA<ReminderSendFailed>());
      final failed = result as ReminderSendFailed;
      expect(failed.errorCode, 'UNKNOWN');
    });
  });
}
