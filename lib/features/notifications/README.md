# Notifications

Feature-folder that owns the client side of push and in-app
notifications: FCM permission priming and token lifecycle (FR-AC-04),
the foreground in-app banner (FR-AC-03), and notification deep-link
dispatch including the cold-start case (FR-AC-05).

The actual notification messages are composed and sent server-side
(`functions/src/notifications/`, region `asia-south1`); this feature
only requests permission, manages the device token, renders foreground
banners, and routes taps into the app.

## Implemented scope

### FR-AC-04 — FCM token lifecycle

- `data/fcm_token_service.dart` — `FcmTokenService` plus two fakeable
  seams: `FcmMessagingAdapter` (wraps `FirebaseMessaging.getToken()` /
  `onTokenRefresh`) and `FcmTokenStore` / `FirestoreFcmTokenStore`
  (writes `users/{uid}.fcmTokens` via `arrayUnion` / `arrayRemove`, and
  an atomic `replaceTokenAtomically` batch on refresh so the document
  never has neither value). Exposed via `fcmTokenServiceProvider`.
- `application/sign_out_with_fcm_cleanup.dart` —
  `signOutWithFcmCleanup(WidgetRef)` unregisters the current device
  token **before** `PhoneAuthRepository.signOut()` (which wraps
  `FirebaseAuth.signOut()`) (AC-3). The cleanup never blocks sign-out; on
  failure the stale token is pruned server-side via the 410 path.

### FR-AC-03 — Permission priming, foreground banner

- `application/notification_permission_controller.dart` — the
  `PermissionState` state machine (`notDetermined` → `dialogShown` →
  `requesting` → `granted` / `denied` / `permanentlyDenied`, plus
  `dismissedThisSession`), driven by `NotificationPermissionController`
  (a Riverpod `Notifier<PermissionState>` exposed as
  `notificationPermissionControllerProvider`). The OS prompt is reached
  through the fakeable `PermissionMessagingAdapter`
  (`permissionMessagingAdapterProvider`). **Note:** `shared_preferences`
  is not in the lockfile, so the `wasPermanentlyDenied` flag is
  in-memory only for v1.0 — "do not re-show on next launch" is
  approximated as "do not re-show this session" (documented deviation,
  tracked by a TODO).
- `presentation/pre_permission_dialog.dart` —
  `showPrePermissionDialog(...)`, the "Stay in the loop" priming dialog.
- `presentation/widgets/in_app_notification_banner.dart` —
  `InAppNotificationBanner`, the foreground card that slides in, auto-
  dismisses after 4 s (paused while a screen reader is active), and
  routes tap / swipe-up.

### FR-AC-05 — Deep-link dispatch and cold start

- `domain/notification_payload.dart` — `NotificationType` (closed set:
  `expenseAdded`, `expenseEdited`, `expenseDeleted`,
  `settlementReceived`, `reminder`, `groupInvite`) and the immutable
  `NotificationPayload` with a strict `fromFcmDataMap` factory that
  drops unknown / malformed envelopes silently rather than rendering a
  half-parsed banner.
- `application/deep_link_handler.dart` — `DeepLinkHandler` plus the
  `DeepLinkSource` enum (`foreground` / `background` / `coldStart`).
  Dispatches a parsed payload to the right screen via the shared
  `core/routing/notification_deep_links.dart` resolver and emits the
  `fcm_notification_tapped` event (with a `source` parameter). Exposed
  via `deepLinkHandlerProvider`.
- `application/pending_deep_link_provider.dart` —
  `pendingDeepLinkProvider` (`StateProvider<NotificationPayload?>`).
  Holds a deep-link intent captured at cold start while the user is
  unauthenticated; replayed once auth reaches `AuthenticatedWithProfile`.
- `presentation/notifications_lifecycle_host.dart` —
  `NotificationsLifecycleHost`, mounted below `MaterialApp` via
  `MaterialApp.builder` (in `lib/main.dart`). Subscribes to
  `FirebaseMessaging.onMessage` (foreground → banner overlay),
  `onMessageOpenedApp` (background tap), and `getInitialMessage()`
  (cold start), and listens to `authStateNotifierProvider` to replay the
  pending deep link and schedule the pre-permission dialog once per
  session.

The top-level background handler
(`firebaseMessagingBackgroundHandler`) is registered in `main.dart`
before `runApp`, annotated `@pragma('vm:entry-point')`.

`application/firebase_messaging_provider.dart` exposes
`firebaseMessagingProvider` (`Provider<FirebaseMessaging>`) for DI.

## Layout

```
application/
  deep_link_handler.dart                 # DeepLinkHandler + DeepLinkSource + provider
  firebase_messaging_provider.dart       # Provider<FirebaseMessaging>
  notification_permission_controller.dart # NotifierProvider + PermissionState
  pending_deep_link_provider.dart        # StateProvider<NotificationPayload?> (cold start)
  sign_out_with_fcm_cleanup.dart         # FR-AC-04 AC-3 token unregister-before-signout
data/
  fcm_token_service.dart                 # service + FcmMessagingAdapter + FcmTokenStore
  notification_handler.dart              # payload parse + onBannerShow / cold-start
domain/
  notification_payload.dart              # NotificationType + strict-parsing payload
presentation/
  notifications_lifecycle_host.dart      # MaterialApp.builder host (foreground/background/cold)
  pre_permission_dialog.dart             # "Stay in the loop" priming dialog
  widgets/
    in_app_notification_banner.dart      # foreground banner overlay
```

## Invariants honoured

- **Invariant 1 (integer paise):** N/A — banners render the server-
  supplied title/body text; this feature performs no monetary
  arithmetic.
- **Invariant 2 (`simplifiedBalances` server-maintained):** this feature
  only touches `users/{uid}.fcmTokens`; it never reads or writes
  `simplifiedBalances`.
- **Invariant 3 (system share sheet only):** N/A — no share surface.
- **Invariant 4 (single Firebase project):** all token writes go to the
  single production project. The FCM emulator is not part of the
  Firebase Emulator Suite, so tests mock at the SDK boundary via
  Riverpod overrides (`permissionMessagingAdapterProvider`,
  `fcmTokenServiceProvider`, `firebaseMessagingProvider`).

## Hand-off boundaries

- **Out (write):** notification messages are composed and sent by the
  Cloud Functions in `functions/src/notifications/`; stale-token (410)
  cleanup is also server-side.
- **In (shared):** deep-link routing reuses the `DeepLinkTarget` resolver
  in `core/routing/notification_deep_links.dart`; the activity feed
  (`features/activity/`) uses the same resolver.
- **In (hosting):** the lifecycle host, pre-permission dialog and banner
  overlay are mounted via `MaterialApp.builder` in `lib/main.dart`.
- **Telemetry:** `fcm_notification_tapped` carries a `source` value
  (`foreground` / `background` / `cold_start`); any
  `friendship_id`-derived value is hashed via
  `core/telemetry/event_id_hash.dart` (ADR-0013).
