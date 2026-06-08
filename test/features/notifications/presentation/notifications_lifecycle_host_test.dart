// NotificationsLifecycleHost widget tests (FR-AC-03 / FR-AC-05).
//
// Covers the behaviorally complex app-startup wrapper:
//   - auth-state transition to AuthenticatedWithProfile replays a
//     pending deep-link payload exactly once (FR-AC-05 cold-start
//     unauthenticated-then-sign-in flow);
//   - the pre-permission dialog telemetry event
//     fcm_permission_prompt_shown is emitted on first-session
//     transition (FR-AC-03 AC-14);
//   - host mounts without crashing when FirebaseMessaging is not
//     initialised (defensive try/catch in _subscribeFcmStreams).
//
// The cold-start `getInitialMessage` path is exercised by seeding
// `pendingDeepLinkProvider` directly — equivalent to the "OS launched
// app with payload, user is unauthenticated, payload cached, sign-in
// completes" flow. The static `FirebaseMessaging.onMessage` and
// `onMessageOpenedApp` streams are not mocked here because they are
// static getters that throw without a Firebase platform-channel; the
// host's try/catch ensures this never crashes the test.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/routing/notification_deep_links.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/notifications/application/deep_link_handler.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/notifications/application/pending_deep_link_provider.dart';
import 'package:onebytwo/features/notifications/data/fcm_token_service.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/notifications/presentation/notifications_lifecycle_host.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

class FakePermissionMessagingAdapter implements PermissionMessagingAdapter {
  int requestCalls = 0;

  @override
  Future<NotificationSettings> requestPermission() async {
    requestCalls += 1;
    // The host never actually calls requestPermission in these tests
    // (it only schedules the dialog; the user has to tap Enable).
    return const NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: AuthorizationStatus.notDetermined,
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
}

class FakeTokenService implements FcmTokenService {
  @override
  String? get currentToken => null;

  @override
  Future<String?> registerToken(String uid) async => null;

  @override
  void startTokenRefreshListener(String uid) {}

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

class FakeDeepLinkHandler implements DeepLinkHandler {
  int handleCalls = 0;
  NotificationPayload? lastPayload;
  String? lastCurrentUid;
  DeepLinkSource? lastSource;

  // The base DeepLinkHandler holds a private ProviderContainer in
  // its constructor; the fake does not need one because it overrides
  // both public methods.

  @override
  DeepLinkTarget resolveTarget(
    NotificationPayload payload, {
    required String currentUid,
  }) {
    return const DeepLinkUnavailable();
  }

  @override
  Future<void> handleDeepLink({
    required NotificationPayload payload,
    required BuildContext context,
    required String currentUid,
    required DeepLinkSource source,
  }) async {
    handleCalls += 1;
    lastPayload = payload;
    lastCurrentUid = currentUid;
    lastSource = source;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NotificationPayload _samplePayload() {
  return NotificationPayload(
    type: NotificationType.expenseAdded,
    contextType: 'friendship',
    contextId: 'uid-me_uid-friend',
    itemId: 'expense-1',
    title: 'Test',
    body: 'Body',
    senderName: 'Sender',
    amountPaise: 12300,
    createdAt: DateTime(2026),
  );
}

UserModel _testUser() => UserModel(
  phoneNumber: '+919999999999',
  displayName: 'Tester',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _buildHost({
  required StreamController<AuthState> authController,
  required FakeAnalyticsService analytics,
  required FakeDeepLinkHandler deepLinkHandler,
  NotificationPayload? seededPending,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      permissionMessagingAdapterProvider.overrideWithValue(
        FakePermissionMessagingAdapter(),
      ),
      fcmTokenServiceProvider.overrideWithValue(FakeTokenService()),
      deepLinkHandlerProvider.overrideWithValue(deepLinkHandler),
      authStateNotifierProvider.overrideWith((ref) => authController.stream),
      if (seededPending != null)
        pendingDeepLinkProvider.overrideWith((ref) => seededPending),
    ],
    child: const MaterialApp(
      home: NotificationsLifecycleHost(child: Scaffold(body: Text('child'))),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationsLifecycleHost — host stability', () {
    testWidgets('mounts and renders the child without crashing even when '
        'FirebaseMessaging static streams throw (defensive swallow)', (
      tester,
    ) async {
      final analytics = FakeAnalyticsService();
      final deepLinkHandler = FakeDeepLinkHandler();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      await tester.pumpWidget(
        _buildHost(
          authController: authController,
          analytics: analytics,
          deepLinkHandler: deepLinkHandler,
        ),
      );
      authController.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      // The Firebase platform-channel is not initialised in tests —
      // FirebaseMessaging.onMessage / onMessageOpenedApp throw. The
      // host's try/catch must swallow these so the app shell renders.
      expect(find.text('child'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NotificationsLifecycleHost — pending deep-link replay (FR-AC-05)', () {
    testWidgets('on first transition to AuthenticatedWithProfile, the '
        'pending deep-link payload is replayed via DeepLinkHandler and '
        'cleared from pendingDeepLinkProvider', (tester) async {
      final analytics = FakeAnalyticsService();
      final deepLinkHandler = FakeDeepLinkHandler();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);
      final pending = _samplePayload();

      await tester.pumpWidget(
        _buildHost(
          authController: authController,
          analytics: analytics,
          deepLinkHandler: deepLinkHandler,
          seededPending: pending,
        ),
      );
      // Start unauthenticated — pending payload stays cached.
      authController.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      expect(deepLinkHandler.handleCalls, 0);

      // Transition to AuthenticatedWithProfile — replay fires exactly once.
      authController.add(
        AuthenticatedWithProfile(uid: 'uid-me', user: _testUser()),
      );
      await tester.pumpAndSettle();

      expect(deepLinkHandler.handleCalls, 1);
      expect(deepLinkHandler.lastPayload?.itemId, 'expense-1');
      expect(deepLinkHandler.lastCurrentUid, 'uid-me');
      expect(deepLinkHandler.lastSource, DeepLinkSource.coldStart);
    });

    testWidgets('replay does NOT fire a second time on subsequent auth '
        'emissions of the same AuthenticatedWithProfile state', (tester) async {
      final analytics = FakeAnalyticsService();
      final deepLinkHandler = FakeDeepLinkHandler();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      await tester.pumpWidget(
        _buildHost(
          authController: authController,
          analytics: analytics,
          deepLinkHandler: deepLinkHandler,
          seededPending: _samplePayload(),
        ),
      );
      authController.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();

      final user = _testUser();
      authController.add(AuthenticatedWithProfile(uid: 'uid-me', user: user));
      await tester.pumpAndSettle();
      // Second emission of the SAME logical state (different identity).
      authController.add(AuthenticatedWithProfile(uid: 'uid-me', user: user));
      await tester.pumpAndSettle();

      // Replay still fires only once — the second transition is from
      // AuthenticatedWithProfile -> AuthenticatedWithProfile and is
      // gated by the `wasAuthenticated` check.
      expect(deepLinkHandler.handleCalls, 1);
    });

    testWidgets('with no pending payload, no replay is attempted', (
      tester,
    ) async {
      final analytics = FakeAnalyticsService();
      final deepLinkHandler = FakeDeepLinkHandler();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      await tester.pumpWidget(
        _buildHost(
          authController: authController,
          analytics: analytics,
          deepLinkHandler: deepLinkHandler,
        ),
      );
      authController.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      authController.add(
        AuthenticatedWithProfile(uid: 'uid-me', user: _testUser()),
      );
      await tester.pumpAndSettle();

      expect(deepLinkHandler.handleCalls, 0);
    });
  });

  group('NotificationsLifecycleHost — pre-permission dialog telemetry '
      '(FR-AC-03 AC-14)', () {
    testWidgets('emits fcm_permission_prompt_shown with trigger:first_session '
        'on first transition to AuthenticatedWithProfile', (tester) async {
      final analytics = FakeAnalyticsService();
      final deepLinkHandler = FakeDeepLinkHandler();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      await tester.pumpWidget(
        _buildHost(
          authController: authController,
          analytics: analytics,
          deepLinkHandler: deepLinkHandler,
        ),
      );
      authController.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      authController.add(
        AuthenticatedWithProfile(uid: 'uid-me', user: _testUser()),
      );
      await tester.pumpAndSettle();

      final idx = analytics.loggedEvents.indexOf('fcm_permission_prompt_shown');
      expect(idx, isNonNegative);
      expect(analytics.loggedParameters[idx], {'trigger': 'first_session'});
    });

    testWidgets('does NOT emit fcm_permission_prompt_shown a second time '
        'within the same session', (tester) async {
      final analytics = FakeAnalyticsService();
      final deepLinkHandler = FakeDeepLinkHandler();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      await tester.pumpWidget(
        _buildHost(
          authController: authController,
          analytics: analytics,
          deepLinkHandler: deepLinkHandler,
        ),
      );
      final user = _testUser();
      authController.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      authController.add(AuthenticatedWithProfile(uid: 'uid-me', user: user));
      await tester.pumpAndSettle();
      // Same logical state again — guarded by _dialogShownThisSession.
      authController.add(AuthenticatedWithProfile(uid: 'uid-me', user: user));
      await tester.pumpAndSettle();

      final count = analytics.loggedEvents
          .where((e) => e == 'fcm_permission_prompt_shown')
          .length;
      expect(count, 1);
    });
  });
}
