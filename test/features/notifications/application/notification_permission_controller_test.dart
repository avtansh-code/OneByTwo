// NotificationPermissionController tests (FR-AC-03).
//
// Covers the Notifier driving the pre-permission dialog flow:
//   - Initial state: notDetermined.
//   - showPrePermissionDialog() → dialogShown; re-call is a no-op
//     (AC-12 session-scoped suppression).
//   - dialogShown + "Not now" → dismissedThisSession; no OS prompt.
//   - dialogShown + "Enable" → calls requestPermission(); on grant
//     → granted + token acquisition; on deny → permanentlyDenied.
//
// Tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/notifications/data/fcm_token_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

NotificationSettings _settings(AuthorizationStatus s) {
  return NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    authorizationStatus: s,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
  );
}

class FakePermissionMessagingAdapter implements PermissionMessagingAdapter {
  AuthorizationStatus nextResult = AuthorizationStatus.authorized;
  int requestCalls = 0;

  @override
  Future<NotificationSettings> requestPermission() async {
    requestCalls += 1;
    return _settings(nextResult);
  }
}

class FakeTokenService implements FcmTokenService {
  String? lastUid;
  bool startedListener = false;
  String? returnToken = 'token-A';

  @override
  String? get currentToken => returnToken;

  @override
  Future<String?> registerToken(String uid) async {
    lastUid = uid;
    return returnToken;
  }

  @override
  void startTokenRefreshListener(String uid) {
    startedListener = true;
  }

  @override
  Future<void> unregisterToken(String uid, String token) async {}

  @override
  Future<void> replaceToken(
    String uid,
    String oldToken,
    String newToken,
  ) async {}

  @override
  Future<void> stopTokenRefreshListener() async {}
}

class FakeAnalyticsService implements AnalyticsService {
  final List<String> loggedEvents = <String>[];
  final List<Map<String, Object>?> loggedParameters = <Map<String, Object>?>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
    loggedParameters.add(parameters);
  }
}

ProviderContainer _container({
  required FakePermissionMessagingAdapter adapter,
  required FakeTokenService service,
  FakeAnalyticsService? analytics,
  KeyValueStore? store,
}) {
  return ProviderContainer(
    overrides: [
      permissionMessagingAdapterProvider.overrideWithValue(adapter),
      fcmTokenServiceProvider.overrideWithValue(service),
      analyticsServiceProvider.overrideWithValue(
        analytics ?? FakeAnalyticsService(),
      ),
      if (store != null) keyValueStoreProvider.overrideWithValue(store),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationPermissionController — initial state', () {
    test('initial state is PermissionState.notDetermined', () {
      final adapter = FakePermissionMessagingAdapter();
      final service = FakeTokenService();
      final container = _container(adapter: adapter, service: service);
      addTearDown(container.dispose);

      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.notDetermined,
      );
    });
  });

  group('NotificationPermissionController — showPrePermissionDialog', () {
    test('first call transitions to dialogShown', () {
      final container = _container(
        adapter: FakePermissionMessagingAdapter(),
        service: FakeTokenService(),
      );
      addTearDown(container.dispose);

      container
          .read(notificationPermissionControllerProvider.notifier)
          .showPrePermissionDialog();

      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.dialogShown,
      );
    });

    test('subsequent calls in the same session are no-ops (AC-12)', () {
      final container = _container(
        adapter: FakePermissionMessagingAdapter(),
        service: FakeTokenService(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      notifier.showPrePermissionDialog();
      notifier.onDismissTapped(); // → dismissedThisSession
      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.dismissedThisSession,
      );

      // Re-show in same session should NOT transition back to dialogShown.
      notifier.showPrePermissionDialog();
      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.dismissedThisSession,
      );
    });

    test('does not trigger the OS permission prompt by itself', () {
      final adapter = FakePermissionMessagingAdapter();
      final container = _container(
        adapter: adapter,
        service: FakeTokenService(),
      );
      addTearDown(container.dispose);

      container
          .read(notificationPermissionControllerProvider.notifier)
          .showPrePermissionDialog();

      expect(adapter.requestCalls, 0);
    });
  });

  group('NotificationPermissionController — onDismissTapped', () {
    test('transitions to dismissedThisSession; OS prompt NOT triggered', () {
      final adapter = FakePermissionMessagingAdapter();
      final container = _container(
        adapter: adapter,
        service: FakeTokenService(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      notifier.showPrePermissionDialog();
      notifier.onDismissTapped();

      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.dismissedThisSession,
      );
      expect(adapter.requestCalls, 0);
    });
  });

  group('NotificationPermissionController — onEnableTapped (granted)', () {
    test('grant path triggers requestPermission, registerToken, '
        'startTokenRefreshListener; state transitions to granted', () async {
      final adapter = FakePermissionMessagingAdapter()
        ..nextResult = AuthorizationStatus.authorized;
      final service = FakeTokenService();
      final container = _container(adapter: adapter, service: service);
      addTearDown(container.dispose);

      final notifier = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      notifier.showPrePermissionDialog();

      await notifier.onEnableTapped(uid: 'uid-me');

      expect(adapter.requestCalls, 1);
      expect(service.lastUid, 'uid-me');
      expect(service.startedListener, isTrue);
      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.granted,
      );
    });

    test(
      'provisional grant is treated as granted (iOS quiet-notif path)',
      () async {
        final adapter = FakePermissionMessagingAdapter()
          ..nextResult = AuthorizationStatus.provisional;
        final service = FakeTokenService();
        final container = _container(adapter: adapter, service: service);
        addTearDown(container.dispose);

        final notifier = container.read(
          notificationPermissionControllerProvider.notifier,
        );
        notifier.showPrePermissionDialog();

        await notifier.onEnableTapped(uid: 'uid-me');

        expect(
          container.read(notificationPermissionControllerProvider),
          PermissionState.granted,
        );
        expect(service.lastUid, 'uid-me');
      },
    );
  });

  group('NotificationPermissionController — onEnableTapped (denied)', () {
    test('denied path transitions to permanentlyDenied; NO token acquired '
        '(AC-13)', () async {
      final adapter = FakePermissionMessagingAdapter()
        ..nextResult = AuthorizationStatus.denied;
      final service = FakeTokenService();
      final container = _container(adapter: adapter, service: service);
      addTearDown(container.dispose);

      final notifier = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      notifier.showPrePermissionDialog();

      await notifier.onEnableTapped(uid: 'uid-me');

      expect(adapter.requestCalls, 1);
      expect(service.lastUid, isNull);
      expect(service.startedListener, isFalse);
      expect(
        container.read(notificationPermissionControllerProvider),
        PermissionState.permanentlyDenied,
      );
    });

    test(
      'notDetermined-returned-by-OS treated as denied (defensive)',
      () async {
        final adapter = FakePermissionMessagingAdapter()
          ..nextResult = AuthorizationStatus.notDetermined;
        final service = FakeTokenService();
        final container = _container(adapter: adapter, service: service);
        addTearDown(container.dispose);

        final notifier = container.read(
          notificationPermissionControllerProvider.notifier,
        );
        notifier.showPrePermissionDialog();

        await notifier.onEnableTapped(uid: 'uid-me');

        expect(service.lastUid, isNull);
        expect(
          container.read(notificationPermissionControllerProvider),
          PermissionState.permanentlyDenied,
        );
      },
    );
  });

  group('NotificationPermissionController — wasPermanentlyDenied flag', () {
    test('wasPermanentlyDenied is false at construction', () {
      final container = _container(
        adapter: FakePermissionMessagingAdapter(),
        service: FakeTokenService(),
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(notificationPermissionControllerProvider.notifier)
            .wasPermanentlyDenied,
        isFalse,
      );
    });

    test('wasPermanentlyDenied is set after a denial', () async {
      final adapter = FakePermissionMessagingAdapter()
        ..nextResult = AuthorizationStatus.denied;
      final container = _container(
        adapter: adapter,
        service: FakeTokenService(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      notifier.showPrePermissionDialog();
      await notifier.onEnableTapped(uid: 'uid-me');

      expect(notifier.wasPermanentlyDenied, isTrue);
    });
  });

  group('NotificationPermissionController — wasPermanentlyDenied '
      'cross-launch persistence (FR-AC-04)', () {
    test('hydrates wasPermanentlyDenied=true from the store at '
        'construction', () async {
      final store = InMemoryKeyValueStore();
      await store.setBool(
        PreferenceKeys.notificationsPermanentlyDenied,
        value: true,
      );
      final container = _container(
        adapter: FakePermissionMessagingAdapter(),
        service: FakeTokenService(),
        store: store,
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(notificationPermissionControllerProvider.notifier)
            .wasPermanentlyDenied,
        isTrue,
      );
    });

    test('fresh install (empty store) hydrates wasPermanentlyDenied=false', () {
      final container = _container(
        adapter: FakePermissionMessagingAdapter(),
        service: FakeTokenService(),
        store: InMemoryKeyValueStore(),
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(notificationPermissionControllerProvider.notifier)
            .wasPermanentlyDenied,
        isFalse,
      );
    });

    test('persists wasPermanentlyDenied on the deny transition', () async {
      final store = InMemoryKeyValueStore();
      final container = _container(
        adapter: FakePermissionMessagingAdapter()
          ..nextResult = AuthorizationStatus.denied,
        service: FakeTokenService(),
        store: store,
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        notificationPermissionControllerProvider.notifier,
      );
      notifier.showPrePermissionDialog();
      await notifier.onEnableTapped(uid: 'uid-me');

      expect(
        store.getBool(PreferenceKeys.notificationsPermanentlyDenied),
        isTrue,
      );
    });

    test('restart simulation: a denial in one session suppresses the '
        'auto-trigger flag after a relaunch (same backing store)', () async {
      final store = InMemoryKeyValueStore();

      // Session 1: the user denies the OS prompt.
      final c1 = _container(
        adapter: FakePermissionMessagingAdapter()
          ..nextResult = AuthorizationStatus.denied,
        service: FakeTokenService(),
        store: store,
      );
      final n1 = c1.read(notificationPermissionControllerProvider.notifier);
      n1.showPrePermissionDialog();
      await n1.onEnableTapped(uid: 'uid-me');
      c1.dispose();

      // Session 2: a fresh container reading the same store hydrates the
      // flag, so the pre-permission dialog auto-trigger stays suppressed.
      final c2 = _container(
        adapter: FakePermissionMessagingAdapter(),
        service: FakeTokenService(),
        store: store,
      );
      addTearDown(c2.dispose);

      expect(
        c2
            .read(notificationPermissionControllerProvider.notifier)
            .wasPermanentlyDenied,
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // FR-AC-03 AC-14 telemetry: fcm_token_registered
  // ---------------------------------------------------------------------------

  group(
    'NotificationPermissionController — fcm_token_registered telemetry',
    () {
      test('emits fcm_token_registered after a successful grant + token '
          'acquisition (AC-14)', () async {
        final analytics = FakeAnalyticsService();
        final container = _container(
          adapter: FakePermissionMessagingAdapter()
            ..nextResult = AuthorizationStatus.authorized,
          service: FakeTokenService()..returnToken = 'token-A',
          analytics: analytics,
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          notificationPermissionControllerProvider.notifier,
        );
        notifier.showPrePermissionDialog();
        await notifier.onEnableTapped(uid: 'uid-me');
        // Allow the unawaited analytics logEvent microtask to flush.
        await Future<void>.delayed(Duration.zero);

        expect(analytics.loggedEvents, contains('fcm_token_registered'));
      });

      test('does NOT emit fcm_token_registered on the denial path (no '
          'token was acquired)', () async {
        final analytics = FakeAnalyticsService();
        final container = _container(
          adapter: FakePermissionMessagingAdapter()
            ..nextResult = AuthorizationStatus.denied,
          service: FakeTokenService(),
          analytics: analytics,
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          notificationPermissionControllerProvider.notifier,
        );
        notifier.showPrePermissionDialog();
        await notifier.onEnableTapped(uid: 'uid-me');
        await Future<void>.delayed(Duration.zero);

        expect(analytics.loggedEvents, isNot(contains('fcm_token_registered')));
      });

      test(
        'does NOT emit fcm_token_registered when registerToken returns '
        'null (OS provisioning failure or APNS-token-not-yet-available)',
        () async {
          final analytics = FakeAnalyticsService();
          final container = _container(
            adapter: FakePermissionMessagingAdapter()
              ..nextResult = AuthorizationStatus.authorized,
            service: FakeTokenService()..returnToken = null,
            analytics: analytics,
          );
          addTearDown(container.dispose);

          final notifier = container.read(
            notificationPermissionControllerProvider.notifier,
          );
          notifier.showPrePermissionDialog();
          await notifier.onEnableTapped(uid: 'uid-me');
          await Future<void>.delayed(Duration.zero);

          expect(
            analytics.loggedEvents,
            isNot(contains('fcm_token_registered')),
          );
        },
      );
    },
  );
}
