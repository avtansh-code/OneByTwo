import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/notifications/application/firebase_messaging_provider.dart';
import 'package:onebytwo/features/notifications/data/fcm_token_service.dart';

/// State machine for the pre-permission dialog (FR-AC-03 AC-12, AC-13).
enum PermissionState {
  /// Initial — no dialog shown yet this session.
  notDetermined,

  /// "Stay in the loop" dialog is visible.
  dialogShown,

  /// User dismissed via "Not now" / scrim / back gesture this session.
  /// Suppression is SESSION-SCOPED — cleared on app restart so the
  /// dialog has another chance to land on the next launch.
  dismissedThisSession,

  /// OS-level requestPermission() in flight.
  requesting,

  /// OS-level permission granted.
  granted,

  /// OS-level permission denied.
  denied,

  /// OS-level permission denied AND the local "do not re-show
  /// automatically" flag is set. The user may still re-enable via the
  /// notification-preferences screen (FR-PR-03 — separate PR).
  permanentlyDenied,
}

/// Minimal adapter over [FirebaseMessaging] for the permission method
/// the [NotificationPermissionController] consumes.
// ignore: one_member_abstracts
abstract class PermissionMessagingAdapter {
  /// Prompts the OS for push permission and returns the resulting
  /// [NotificationSettings].
  Future<NotificationSettings> requestPermission();
}

/// Production adapter wrapping [FirebaseMessaging.requestPermission].
class FirebaseMessagingPermissionAdapter implements PermissionMessagingAdapter {
  /// Creates a [FirebaseMessagingPermissionAdapter].
  const FirebaseMessagingPermissionAdapter(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission();
  }
}

/// Provides the [PermissionMessagingAdapter] in DI. Override in tests
/// with a fake.
final permissionMessagingAdapterProvider = Provider<PermissionMessagingAdapter>(
  (ref) =>
      FirebaseMessagingPermissionAdapter(ref.watch(firebaseMessagingProvider)),
);

/// Drives the pre-permission dialog flow.
///
/// Flow:
///   1. `showPrePermissionDialog` — transitions to `dialogShown`.
///      Idempotent within a session: subsequent calls do not
///      transition.
///   2. `onDismissTapped` — transitions to `dismissedThisSession`. Used
///      by all three dismiss paths (Not now, scrim tap, back gesture).
///   3. `onEnableTapped` — triggers the OS prompt via the messaging
///      adapter. On grant, acquires a token via the [FcmTokenService]
///      and starts the refresh listener. On deny, transitions to
///      `permanentlyDenied` and persists the local `wasPermanentlyDenied`
///      flag.
///
/// **Local persistence (FR-AC-04):** the `wasPermanentlyDenied` flag is
/// persisted across launches via the [KeyValueStore] seam
/// (`shared_preferences` under the hood). It is hydrated in [build] at
/// construction and written on the deny/error transitions, so the
/// "permanently denied — do not re-show on next launch" semantic is
/// honoured after an app restart. The session-scoped suppression states
/// (`dismissedThisSession`) remain session-only by design.
class NotificationPermissionController extends Notifier<PermissionState> {
  bool _wasPermanentlyDenied = false;

  /// Whether the OS prompt has been denied at least once on this
  /// installation. Used by the auth-state listener in `OneBytwoApp` to
  /// suppress the dialog auto-trigger.
  bool get wasPermanentlyDenied => _wasPermanentlyDenied;

  @override
  PermissionState build() {
    _wasPermanentlyDenied =
        ref
            .read(keyValueStoreProvider)
            .getBool(PreferenceKeys.notificationsPermanentlyDenied) ??
        false;
    return PermissionState.notDetermined;
  }

  /// Surfaces the pre-permission dialog. Idempotent within a session.
  void showPrePermissionDialog() {
    if (state != PermissionState.notDetermined) {
      // Session-scoped suppression (AC-12).
      return;
    }
    state = PermissionState.dialogShown;
  }

  /// Records the user's "Not now" / scrim-tap / back-gesture dismissal.
  void onDismissTapped() {
    state = PermissionState.dismissedThisSession;
  }

  /// Triggers the OS-level permission prompt. On grant, acquires the
  /// FCM token and starts the refresh listener via [FcmTokenService].
  ///
  /// [uid] is the current user's UID — required so the granted-path
  /// can write to `users/{uid}.fcmTokens`.
  Future<void> onEnableTapped({required String uid}) async {
    state = PermissionState.requesting;
    final adapter = ref.read(permissionMessagingAdapterProvider);
    try {
      final settings = await adapter.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await _acquireTokenAndWire(uid);
        state = PermissionState.granted;
      } else {
        await _markPermanentlyDenied();
      }
    } catch (e, st) {
      debugPrint('[PermissionController] requestPermission failed: $e\n$st');
      await _markPermanentlyDenied();
    }
  }

  /// Sets, persists, and reflects the permanently-denied flag. Persisting
  /// before the state transition guarantees the cross-launch suppression
  /// survives an immediate process kill (FR-AC-04 "next launch").
  Future<void> _markPermanentlyDenied() async {
    _wasPermanentlyDenied = true;
    await ref
        .read(keyValueStoreProvider)
        .setBool(PreferenceKeys.notificationsPermanentlyDenied, value: true);
    state = PermissionState.permanentlyDenied;
  }

  Future<void> _acquireTokenAndWire(String uid) async {
    final tokenService = ref.read(fcmTokenServiceProvider);
    final token = await tokenService.registerToken(uid);
    tokenService.startTokenRefreshListener(uid);
    // FR-AC-03 telemetry contract: emit fcm_token_registered only when
    // registerToken() actually returned a token (i.e. the OS provisioned
    // one and the Firestore arrayUnion succeeded). Per AC-14, the event
    // carries no UID-derived parameters — Firebase Analytics already
    // attributes the event to the signed-in user implicitly.
    if (token != null) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(name: 'fcm_token_registered'),
      );
    }
  }
}

/// Provider for [NotificationPermissionController].
final notificationPermissionControllerProvider =
    NotifierProvider<NotificationPermissionController, PermissionState>(
      NotificationPermissionController.new,
    );
