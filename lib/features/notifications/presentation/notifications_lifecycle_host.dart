import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/notifications/application/deep_link_handler.dart';
import 'package:onebytwo/features/notifications/application/firebase_messaging_provider.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/notifications/application/pending_deep_link_provider.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/notifications/presentation/pre_permission_dialog.dart';
import 'package:onebytwo/features/notifications/presentation/widgets/in_app_notification_banner.dart';

/// FR-AC-03 / FR-AC-05 app-startup wrapper.
///
/// Sits below `MaterialApp` via `MaterialApp.builder` so it has access
/// to the platform `Overlay`, `Navigator`, and `ScaffoldMessenger`.
///
/// Responsibilities:
///   - Subscribes to `FirebaseMessaging.onMessage` (foreground) and
///     renders the [InAppNotificationBanner] via an `OverlayEntry`
///     (AC-9).
///   - Subscribes to `FirebaseMessaging.onMessageOpenedApp` (system
///     notification tap while backgrounded) and dispatches to the
///     [DeepLinkHandler] (AC-10).
///   - Calls `FirebaseMessaging.instance.getInitialMessage()` once on
///     mount to handle the cold-start case (AC-11).
///   - Listens to [authStateProvider]; on the first transition
///     to [AuthenticatedWithProfile] per session:
///       1. Replays any pending deep-link cached in
///          [pendingDeepLinkProvider] (FR-AC-05 unauthenticated-then-
///          sign-in flow).
///       2. Schedules the "Stay in the loop" pre-permission dialog if
///          not yet shown this session AND not permanently denied
///          (AC-1, AC-12, AC-13).
class NotificationsLifecycleHost extends ConsumerStatefulWidget {
  /// Creates a [NotificationsLifecycleHost] around [child].
  const NotificationsLifecycleHost({required this.child, super.key});

  /// The routed home content (Splash / PhoneEntry / ProfileSetup /
  /// HomePlaceholder), wrapped here so notifications surface on top.
  final Widget child;

  @override
  ConsumerState<NotificationsLifecycleHost> createState() =>
      _NotificationsLifecycleHostState();
}

class _NotificationsLifecycleHostState
    extends ConsumerState<NotificationsLifecycleHost> {
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  OverlayEntry? _bannerOverlay;
  bool _coldStartHandled = false;
  bool _dialogShownThisSession = false;
  AuthState? _lastAuthState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeFcmStreams();
      _handleColdStart();
    });
  }

  void _subscribeFcmStreams() {
    try {
      _onMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _onBackgroundedTap,
      );
    } catch (e, st) {
      // Defensive — in test environments without Firebase initialised,
      // the static getters throw a FirebaseException. The host is a
      // boot-time scaffold that must not crash the app shell; the FCM
      // delivery surface degrades gracefully.
      debugPrint(
        '[NotificationsLifecycleHost] FCM streams unavailable: $e\n$st',
      );
    }
  }

  Future<void> _handleColdStart() async {
    if (_coldStartHandled) return;
    _coldStartHandled = true;
    try {
      final messaging = ref.read(firebaseMessagingProvider);
      final initial = await messaging.getInitialMessage();
      if (initial == null) return;
      final payload = NotificationPayload.fromFcmDataMap(initial.data);
      if (payload == null) return;
      final authState = ref.read(authStateProvider).valueOrNull;
      if (authState is AuthenticatedWithProfile) {
        await _dispatchDeepLink(
          payload,
          DeepLinkSource.coldStart,
          authState.uid,
        );
      } else {
        // Cache for replay after sign-in (FR-AC-05).
        ref.read(pendingDeepLinkProvider.notifier).state = payload;
      }
    } catch (e, st) {
      debugPrint('[NotificationsLifecycleHost] cold start failed: $e\n$st');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final payload = NotificationPayload.fromFcmDataMap(message.data);
    if (payload == null) return;
    _showBanner(payload);
  }

  Future<void> _onBackgroundedTap(RemoteMessage message) async {
    final payload = NotificationPayload.fromFcmDataMap(message.data);
    if (payload == null) return;
    final authState = ref.read(authStateProvider).valueOrNull;
    if (authState is AuthenticatedWithProfile) {
      await _dispatchDeepLink(
        payload,
        DeepLinkSource.background,
        authState.uid,
      );
    } else {
      ref.read(pendingDeepLinkProvider.notifier).state = payload;
    }
  }

  void _showBanner(NotificationPayload payload) {
    _bannerOverlay?.remove();
    _bannerOverlay = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (entryContext) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: InAppNotificationBanner(
              payload: payload,
              onTap: (p) async {
                _bannerOverlay?.remove();
                _bannerOverlay = null;
                final authState = ref.read(authStateProvider).valueOrNull;
                if (authState is! AuthenticatedWithProfile) return;
                await _dispatchDeepLink(
                  p,
                  DeepLinkSource.foreground,
                  authState.uid,
                );
              },
              onDismiss: () {
                _bannerOverlay?.remove();
                _bannerOverlay = null;
              },
            ),
          ),
        ),
      ),
    );
    _bannerOverlay = entry;
    overlay.insert(entry);
  }

  Future<void> _dispatchDeepLink(
    NotificationPayload payload,
    DeepLinkSource source,
    String currentUid,
  ) async {
    final handler = ref.read(deepLinkHandlerProvider);
    await handler.handleDeepLink(
      payload: payload,
      context: context,
      currentUid: currentUid,
      source: source,
    );
  }

  void _onAuthStateChanged(AuthState? prev, AuthState? next) {
    if (next is! AuthenticatedWithProfile) {
      _lastAuthState = next;
      return;
    }
    final wasAuthenticated = prev is AuthenticatedWithProfile;
    _lastAuthState = next;
    if (wasAuthenticated) return;

    // First-time transition into AuthenticatedWithProfile this session.
    final uid = next.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _replayPendingDeepLink(uid);
      _maybeShowPrePermissionDialog(uid);
    });
  }

  Future<void> _replayPendingDeepLink(String uid) async {
    final pending = ref.read(pendingDeepLinkProvider);
    if (pending == null) return;
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    if (!mounted) return;
    await _dispatchDeepLink(pending, DeepLinkSource.coldStart, uid);
  }

  void _maybeShowPrePermissionDialog(String uid) {
    if (_dialogShownThisSession) return;
    final controller = ref.read(
      notificationPermissionControllerProvider.notifier,
    );
    if (controller.wasPermanentlyDenied) return;
    final state = ref.read(notificationPermissionControllerProvider);
    if (state != PermissionState.notDetermined) return;

    _dialogShownThisSession = true;
    controller.showPrePermissionDialog();
    // FR-AC-03 telemetry contract: emit fcm_permission_prompt_shown
    // just before the dialog is surfaced. The only producer in v1.0 is
    // the first-session auth-transition trigger; future producers
    // (e.g. a manual "enable notifications" CTA on the Profile screen
    // shipped with FR-PR-03) MUST emit with trigger='manual'.
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'fcm_permission_prompt_shown',
            parameters: const {'trigger': 'first_session'},
          ),
    );
    unawaited(
      showPrePermissionDialog(
        context: context,
        onEnable: () {
          unawaited(controller.onEnableTapped(uid: uid));
        },
        onDismiss: controller.onDismissTapped,
      ),
    );
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _bannerOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      final prevState = prev?.valueOrNull;
      final nextState = next.valueOrNull;
      if (nextState == null) return;
      if (identical(prevState, nextState)) return;
      _onAuthStateChanged(prevState ?? _lastAuthState, nextState);
    });
    return widget.child;
  }
}
