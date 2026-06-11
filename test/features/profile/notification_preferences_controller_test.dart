// FR-PR-03 NotificationPreferencesController state-machine tests.
//
// Mirrors test/features/reminders/application/send_reminder_controller_test.dart:
// fake repository + fake analytics service, no Firebase required.
//
// The controller drives the load/ready/error states for SCR-27 with
// per-toggle 500 ms debounce, optimistic-with-revert, serial write
// queue across debounced flushes, and per-category telemetry. The
// constants used in expectations come from
// notification_preferences_telemetry.dart so test assertions never
// hard-code event names.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/connectivity/connectivity_provider.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_telemetry.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
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

class _FakeUserRepository implements UserRepository {
  UserModel? userToReturn;
  Exception? throwOnGet;

  final List<({String uid, Map<String, bool> prefs})> updateCalls =
      <({String uid, Map<String, bool> prefs})>[];

  /// When set, the [updateNotificationPrefs] call awaits this completer
  /// before resolving. Lets a test artificially delay the first write
  /// so it can verify that the second debounced write does not start
  /// until the first one settles (AC-9).
  Completer<void>? gateCompleter;

  /// When set, [updateNotificationPrefs] throws this exception. The
  /// throw happens AFTER capturing the call into [updateCalls], so the
  /// test can still assert that the write was attempted before
  /// observing the revert.
  Exception? throwOnUpdate;

  @override
  Future<UserModel?> getUser(String uid) async {
    if (throwOnGet != null) throw throwOnGet!;
    return userToReturn;
  }

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {
    updateCalls.add((uid: uid, prefs: Map<String, bool>.from(prefs)));
    if (gateCompleter != null) {
      await gateCompleter!.future;
    }
    if (throwOnUpdate != null) throw throwOnUpdate!;
  }

  // ---------------------------------------------------------------
  // Unused stubs — the controller never calls these.
  // ---------------------------------------------------------------

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadAvatar(String uid, String filePath) async =>
      throw UnimplementedError();

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteAvatar(String uid) async => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uid = 'uid-test';

UserModel _userWithPrefs(Map<String, bool> prefs) {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: 'Test User',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    notificationPrefs: prefs,
  );
}

NotificationPreferencesController _controller({
  required _FakeUserRepository repository,
  required _FakeAnalyticsService analytics,
  String uid = _uid,
  IsOnline? isOnline,
}) {
  return NotificationPreferencesController(
    repository: repository,
    analytics: analytics,
    isOnline: isOnline ?? (() async => true),
    uid: uid,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationPreferencesController — initial load', () {
    test('initial state is Loading before _load completes', () async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();

      final controller = _controller(repository: repo, analytics: analytics);
      addTearDown(controller.dispose);

      expect(controller.state, isA<NotificationPreferencesLoading>());
    });

    test('read success transitions to Ready with persisted prefs', () async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': false,
          'settlement': true,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();

      final controller = _controller(repository: repo, analytics: analytics);
      addTearDown(controller.dispose);

      // Flush microtasks so the constructor's _load() completes.
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, isA<NotificationPreferencesReady>());
      final ready = controller.state as NotificationPreferencesReady;
      expect(ready.prefs['newExpense'], isFalse);
      expect(ready.prefs['settlement'], isTrue);
      expect(ready.prefs['reminder'], isTrue);
      expect(ready.savingKeys, isEmpty);
    });

    test('read failure transitions to Error with a message', () async {
      final repo = _FakeUserRepository()
        ..throwOnGet = Exception('Firestore offline');
      final analytics = _FakeAnalyticsService();

      final controller = _controller(repository: repo, analytics: analytics);
      addTearDown(controller.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(controller.state, isA<NotificationPreferencesError>());
      final err = controller.state as NotificationPreferencesError;
      expect(err.message, isNotEmpty);
    });

    test('read returning null user transitions to Error', () async {
      final repo = _FakeUserRepository()..userToReturn = null;
      final analytics = _FakeAnalyticsService();

      final controller = _controller(repository: repo, analytics: analytics);
      addTearDown(controller.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(controller.state, isA<NotificationPreferencesError>());
    });
  });

  group('NotificationPreferencesController — setReminder', () {
    test(
      'flip optimistically updates prefs + savingKeys; after 500 ms '
      'debounce, calls updateNotificationPrefs once and clears savingKey',
      () {
        fakeAsync((async) {
          final repo = _FakeUserRepository()
            ..userToReturn = _userWithPrefs({
              'newExpense': true,
              'settlement': true,
              'reminder': true,
            });
          final analytics = _FakeAnalyticsService();
          final controller = _controller(
            repository: repo,
            analytics: analytics,
          );
          addTearDown(controller.dispose);

          async.flushMicrotasks();
          expect(controller.state, isA<NotificationPreferencesReady>());

          controller.setReminder(false);

          // Optimistic flip is immediate.
          final justAfterTap = controller.state as NotificationPreferencesReady;
          expect(justAfterTap.prefs['reminder'], isFalse);
          expect(justAfterTap.savingKeys, contains('reminder'));

          // No write yet.
          expect(repo.updateCalls, isEmpty);

          // Halfway through the debounce — still no write.
          async.elapse(const Duration(milliseconds: 300));
          expect(repo.updateCalls, isEmpty);

          // After 500 ms total — write fires and the savingKey clears.
          async.elapse(const Duration(milliseconds: 250));
          async.flushMicrotasks();
          expect(repo.updateCalls.length, 1);
          expect(repo.updateCalls.single.uid, _uid);
          expect(repo.updateCalls.single.prefs, {'reminder': false});

          final settled = controller.state as NotificationPreferencesReady;
          expect(settled.prefs['reminder'], isFalse);
          expect(settled.savingKeys, isEmpty);

          // Telemetry: exactly one notification_pref_changed event.
          final changed = analytics.events
              .where((e) => e.name == notificationPrefChangedEvent)
              .toList();
          expect(changed.length, 1);
          expect(
            changed.single.parameters?[notificationPrefCategoryParam],
            notificationPrefCategoryReminder,
          );
          expect(
            changed.single.parameters?[notificationPrefEnabledParam],
            isFalse,
          );
        });
      },
    );

    test('setNewExpense and setSettlement also persist with their keys', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(repository: repo, analytics: analytics);
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        controller.setNewExpense(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(repo.updateCalls.last.prefs, {'newExpense': false});
        final changed1 = analytics.events
            .where((e) => e.name == notificationPrefChangedEvent)
            .last;
        expect(
          changed1.parameters?[notificationPrefCategoryParam],
          notificationPrefCategoryNewExpense,
        );

        controller.setSettlement(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(repo.updateCalls.last.prefs, {'settlement': false});
        final changed2 = analytics.events
            .where((e) => e.name == notificationPrefChangedEvent)
            .last;
        expect(
          changed2.parameters?[notificationPrefCategoryParam],
          notificationPrefCategorySettlement,
        );
      });
    });
  });

  group('NotificationPreferencesController — AC-5 per-toggle isolation', () {
    test('flip A at t=0 then B at t=100ms: A writes at t=500ms before B', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(repository: repo, analytics: analytics);
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        // t=0: flip newExpense.
        controller.setNewExpense(false);
        // t=100ms: flip settlement.
        async.elapse(const Duration(milliseconds: 100));
        controller.setSettlement(false);

        // t=499ms: neither has fired yet (A's debounce is 0 → 500ms,
        // B's is 100 → 600ms).
        async.elapse(const Duration(milliseconds: 399));
        expect(repo.updateCalls, isEmpty);

        // t=500ms: A's debounce fires; B's has not.
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(repo.updateCalls.length, 1);
        expect(repo.updateCalls.single.prefs, {'newExpense': false});

        // t=600ms: B's debounce fires.
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(repo.updateCalls.length, 2);
        expect(repo.updateCalls.last.prefs, {'settlement': false});
      });
    });
  });

  group('NotificationPreferencesController — AC-6 rapid same-toggle', () {
    test('flip OFF/ON/OFF/ON within 200ms → exactly one write with ON', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(repository: repo, analytics: analytics);
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        controller.setReminder(false); // t=0
        async.elapse(const Duration(milliseconds: 50));
        controller.setReminder(true); // t=50
        async.elapse(const Duration(milliseconds: 50));
        controller.setReminder(false); // t=100
        async.elapse(const Duration(milliseconds: 50));
        controller.setReminder(true); // t=150

        // Wait beyond the debounce window of the LAST flip.
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();

        // Only ONE write — for the final state (true).
        expect(repo.updateCalls.length, 1);
        expect(repo.updateCalls.single.prefs, {'reminder': true});

        // Only ONE telemetry event.
        final changed = analytics.events
            .where((e) => e.name == notificationPrefChangedEvent)
            .toList();
        expect(changed.length, 1);
        expect(changed.single.parameters?[notificationPrefEnabledParam], true);
      });
    });
  });

  group('NotificationPreferencesController — AC-9 serial write queue', () {
    test('two debounced writes are serialised: write B awaits write A', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(repository: repo, analytics: analytics);
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        // Hold the first write open.
        final gate = Completer<void>();
        repo.gateCompleter = gate;

        // t=0 flip newExpense (debounce fires at t=500ms).
        controller.setNewExpense(false);
        // t=100ms flip settlement (debounce fires at t=600ms).
        async.elapse(const Duration(milliseconds: 100));
        controller.setSettlement(false);

        // t=500ms: A's debounce fires — adapter invoked, but the gate
        // blocks completion. updateCalls already captured the entry
        // because the fake captures BEFORE awaiting the gate.
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(repo.updateCalls.length, 1);
        expect(repo.updateCalls.single.prefs, {'newExpense': false});

        // t=600ms: B's debounce fires. Because the serial queue
        // chains B onto A, B has NOT been started yet — only A is
        // sitting in the gate.
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(repo.updateCalls.length, 1);

        // Release the gate. A completes; B then runs.
        gate.complete();
        repo.gateCompleter = null;
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();

        expect(repo.updateCalls.length, 2);
        expect(repo.updateCalls.last.prefs, {'settlement': false});
      });
    });
  });

  group('NotificationPreferencesController — AC-7 persist failure', () {
    test(
      'write throws → optimistic flip reverts; notification_pref_error fires',
      () {
        fakeAsync((async) {
          final repo = _FakeUserRepository()
            ..userToReturn = _userWithPrefs({
              'newExpense': true,
              'settlement': true,
              'reminder': true,
            })
            ..throwOnUpdate = Exception('Firestore write rejected');
          final analytics = _FakeAnalyticsService();
          final controller = _controller(
            repository: repo,
            analytics: analytics,
          );
          addTearDown(controller.dispose);

          async.flushMicrotasks();

          controller.setNewExpense(false);
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();

          // The write was attempted.
          expect(repo.updateCalls.length, 1);

          // State reverted to the persisted value (true).
          final reverted = controller.state as NotificationPreferencesReady;
          expect(reverted.prefs['newExpense'], isTrue);
          expect(reverted.savingKeys, isEmpty);

          // notification_pref_error fired with the category.
          final errors = analytics.events
              .where((e) => e.name == notificationPrefErrorEvent)
              .toList();
          expect(errors.length, 1);
          expect(
            errors.single.parameters?[notificationPrefCategoryParam],
            notificationPrefCategoryNewExpense,
          );
          expect(
            errors.single.parameters?[notificationPrefErrorCodeParam],
            isA<String>(),
          );

          // The success event did NOT fire.
          expect(
            analytics.events.where(
              (e) => e.name == notificationPrefChangedEvent,
            ),
            isEmpty,
          );
        });
      },
    );
  });

  group('NotificationPreferencesController — PII guard', () {
    test('no uid / userId appears in any analytics payload', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(repository: repo, analytics: analytics);
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        controller.setReminder(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        for (final event in analytics.events) {
          final params = event.parameters ?? <String, Object>{};
          expect(params.containsKey('userId'), isFalse, reason: event.name);
          expect(params.containsKey('uid'), isFalse, reason: event.name);
          expect(
            params.containsKey('friendship_id'),
            isFalse,
            reason: event.name,
          );
          expect(
            params.containsKey('friendship_id_hash'),
            isFalse,
            reason: event.name,
          );
          // The raw uid string must not appear as a parameter VALUE.
          for (final v in params.values) {
            expect(v.toString(), isNot(equals(_uid)), reason: event.name);
          }
        }
      });
    });
  });

  group('NotificationPreferencesController — AC-10 offline banner', () {
    test('first offline flip latches offlineWriteJustQueued true and stays '
        'latched', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(
          repository: repo,
          analytics: analytics,
          isOnline: () async => false,
        );
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        final initial = controller.state as NotificationPreferencesReady;
        expect(initial.offlineWriteJustQueued, isFalse);

        controller.setReminder(false);
        async.flushMicrotasks();

        // The offline signal latches after the async check resolves.
        final latched = controller.state as NotificationPreferencesReady;
        expect(latched.offlineWriteJustQueued, isTrue);
        // Optimistic flip still works.
        expect(latched.prefs['reminder'], isFalse);

        // The flag stays latched after the debounce + persist cycle.
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final settled = controller.state as NotificationPreferencesReady;
        expect(settled.offlineWriteJustQueued, isTrue);
      });
    });

    test('second offline flip in same session does not re-emit the signal', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(
          repository: repo,
          analytics: analytics,
          isOnline: () async => false,
        );
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        // Subscribe to state changes so we can count signal transitions.
        var signalTransitions = 0;
        bool? previousFlag;
        controller.addListener((s) {
          if (s is NotificationPreferencesReady) {
            if (previousFlag == false && s.offlineWriteJustQueued) {
              signalTransitions++;
            }
            previousFlag = s.offlineWriteJustQueued;
          }
        });

        controller.setReminder(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        controller.setNewExpense(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        controller.setSettlement(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(
          signalTransitions,
          1,
          reason:
              'AC-10 single-fire-per-session: only the first false→true '
              'transition fires; subsequent offline flips must not '
              're-emit the signal',
        );
      });
    });

    test(
      'online flip never sets offlineWriteJustQueued (no false positives)',
      () {
        fakeAsync((async) {
          final repo = _FakeUserRepository()
            ..userToReturn = _userWithPrefs({
              'newExpense': true,
              'settlement': true,
              'reminder': true,
            });
          final analytics = _FakeAnalyticsService();
          final controller = _controller(
            repository: repo,
            analytics: analytics,
            isOnline: () async => true,
          );
          addTearDown(controller.dispose);

          async.flushMicrotasks();

          controller.setReminder(false);
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();

          final settled = controller.state as NotificationPreferencesReady;
          expect(settled.offlineWriteJustQueued, isFalse);
        });
      },
    );

    test('connectivity check throwing does not surface offline banner '
        '(graceful degradation)', () {
      fakeAsync((async) {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();
        final controller = _controller(
          repository: repo,
          analytics: analytics,
          isOnline: () async => throw Exception('platform channel missing'),
        );
        addTearDown(controller.dispose);

        async.flushMicrotasks();

        controller.setReminder(false);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final settled = controller.state as NotificationPreferencesReady;
        expect(settled.offlineWriteJustQueued, isFalse);
      });
    });
  });
}
