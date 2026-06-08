// FR-SE-09 SendReminderController state-machine tests.
//
// Mirrors test/features/settlements/settle_up_controller_test.dart:
// fake repository + fake analytics service, no Firebase required.
//
// The controller drives the in-progress / success / error states for
// the "Send Reminder" button on the OBTSettleUpCard receiving-direction
// variant, sets the reminderCooldownProvider on success or RATE_LIMITED,
// and emits the reminder_send_* client telemetry family with hashed
// friendship_id parameters per ADR-0013.

// ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/reminders/application/reminder_cooldown_provider.dart';
import 'package:onebytwo/features/reminders/application/reminder_telemetry.dart';
import 'package:onebytwo/features/reminders/application/send_reminder_controller.dart';
import 'package:onebytwo/features/reminders/data/reminder_repository.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_error.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_success.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeReminderRepository implements ReminderRepository {
  ReminderSendResult Function()? produceResult;
  String? capturedToUserId;
  String? capturedContextType;
  String? capturedContextId;
  String? capturedMessage;
  int callCount = 0;

  @override
  Future<ReminderSendResult> sendReminder({
    required String toUserId,
    required String contextType,
    required String contextId,
    String? message,
  }) async {
    callCount += 1;
    capturedToUserId = toUserId;
    capturedContextType = contextType;
    capturedContextId = contextId;
    capturedMessage = message;
    return (produceResult ?? () => ReminderSendFailed('UNKNOWN'))();
  }
}

class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }
}

const _friendshipId = 'uid-sender_uid-recipient';
const _recipientUid = 'uid-recipient';

ProviderContainer _createContainer({
  required FakeReminderRepository repo,
  required FakeAnalyticsService analytics,
}) {
  return ProviderContainer(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
}

void main() {
  group('SendReminderController.send', () {
    test('happy path emits Sending → Success and sets cooldownProvider',
        () async {
      final repo = FakeReminderRepository()
        ..produceResult = () => ReminderSendSuccess(
              nextAllowedAt: DateTime.utc(2026, 6, 9, 12),
            );
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      final transitions = <SendReminderState>[];
      container.listen<SendReminderState>(
        sendReminderControllerProvider(_friendshipId),
        (_, next) => transitions.add(next),
        fireImmediately: true,
      );

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      expect(repo.callCount, 1);
      expect(repo.capturedToUserId, _recipientUid);
      expect(repo.capturedContextId, _friendshipId);
      expect(transitions.first, isA<SendReminderIdle>());
      expect(
        transitions.any((s) => s is SendReminderSending),
        isTrue,
      );
      expect(transitions.last, isA<SendReminderSuccess>());

      // Cooldown provider was set to the server-returned nextAllowedAt.
      expect(
        container.read(reminderCooldownProvider(_friendshipId)),
        equals(DateTime.utc(2026, 6, 9, 12)),
      );

      // Telemetry: reminder_send_tapped + reminder_send_succeeded.
      final names = analytics.events.map((e) => e.name).toList();
      expect(names, contains(ReminderTelemetry.tapped));
      expect(names, contains(ReminderTelemetry.succeeded));
      final succeeded = analytics.events.firstWhere(
        (e) => e.name == ReminderTelemetry.succeeded,
      );
      expect(
        succeeded.parameters?[ReminderTelemetry.paramFriendshipIdHash],
        equals(hashFriendshipId(_friendshipId)),
      );
    });

    test('RATE_LIMITED transitions to Error + sets cooldown to server time',
        () async {
      final nextAt = DateTime.utc(2026, 6, 8, 23, 30);
      final repo = FakeReminderRepository()
        ..produceResult = () => ReminderSendRateLimited(nextAllowedAt: nextAt);
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      final state = container.read(
        sendReminderControllerProvider(_friendshipId),
      );
      expect(state, isA<SendReminderError>());
      final err = state as SendReminderError;
      expect(err.error, isA<ReminderSendRateLimited>());

      // Cooldown provider matches the server's nextAllowedAt.
      expect(
        container.read(reminderCooldownProvider(_friendshipId)),
        equals(nextAt),
      );

      final names = analytics.events.map((e) => e.name).toList();
      expect(names, contains(ReminderTelemetry.rateLimited));
      final rl = analytics.events.firstWhere(
        (e) => e.name == ReminderTelemetry.rateLimited,
      );
      expect(rl.parameters?[ReminderTelemetry.paramNextAllowedInSeconds],
          isA<int>());
    });

    test('RECIPIENT_PREFS_DISABLED → Error + prefs telemetry; no cooldown set',
        () async {
      final repo = FakeReminderRepository()
        ..produceResult = () => const ReminderSendRecipientPrefsDisabled();
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      final state = container.read(
        sendReminderControllerProvider(_friendshipId),
      );
      expect(state, isA<SendReminderError>());
      expect(
        (state as SendReminderError).error,
        isA<ReminderSendRecipientPrefsDisabled>(),
      );
      expect(
        container.read(reminderCooldownProvider(_friendshipId)),
        isNull,
      );
      expect(
        analytics.events.map((e) => e.name),
        contains(ReminderTelemetry.recipientPrefsDisabled),
      );
    });

    test('RECIPIENT_NO_TOKENS → Error + no-tokens telemetry', () async {
      final repo = FakeReminderRepository()
        ..produceResult = () => const ReminderSendRecipientNoTokens();
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      expect(
        analytics.events.map((e) => e.name),
        contains(ReminderTelemetry.recipientNoTokens),
      );
    });

    test('RECIPIENT_DOESNT_OWE → Error + doesnt-owe telemetry', () async {
      final repo = FakeReminderRepository()
        ..produceResult = () => const ReminderSendRecipientDoesntOwe();
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      expect(
        analytics.events.map((e) => e.name),
        contains(ReminderTelemetry.recipientDoesntOwe),
      );
    });

    test('ReminderSendFailed → Error + failed telemetry with error_code',
        () async {
      final repo = FakeReminderRepository()
        ..produceResult = () => ReminderSendFailed('FCM_DISPATCH_FAILED');
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      final failed = analytics.events.firstWhere(
        (e) => e.name == ReminderTelemetry.failed,
      );
      expect(failed.parameters?[ReminderTelemetry.paramErrorCode],
          equals('FCM_DISPATCH_FAILED'));
    });

    test('telemetry never logs raw friendshipId — PII guard', () async {
      final repo = FakeReminderRepository()
        ..produceResult = () => ReminderSendSuccess(
              nextAllowedAt: DateTime.utc(2026, 6, 9, 12),
            );
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      await controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );

      final serialized = analytics.events
          .map((e) => '${e.name}::${e.parameters}')
          .join('|');
      expect(serialized, isNot(contains(_friendshipId)));
      expect(serialized, contains(hashFriendshipId(_friendshipId)));
    });

    test('concurrent send() calls — second is short-circuited while sending',
        () async {
      var resolvedFirst = false;
      final repo = FakeReminderRepository()
        ..produceResult = () {
          resolvedFirst = true;
          return ReminderSendSuccess(
            nextAllowedAt: DateTime.utc(2026, 6, 9, 12),
          );
        };
      final analytics = FakeAnalyticsService();
      final container = _createContainer(repo: repo, analytics: analytics);
      addTearDown(container.dispose);
      final controller = container
          .read(sendReminderControllerProvider(_friendshipId).notifier);

      final first = controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );
      // Second concurrent call should be a no-op while the first is in
      // flight.
      final second = controller.send(
        toUserId: _recipientUid,
        contextType: 'friendship',
        contextId: _friendshipId,
      );
      await Future.wait([first, second]);
      expect(resolvedFirst, isTrue);
      expect(repo.callCount, 1);
    });
  });
}
