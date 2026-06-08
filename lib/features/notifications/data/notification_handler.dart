import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/notifications/application/pending_deep_link_provider.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

/// Async callback that shows the foreground in-app banner with the
/// parsed [NotificationPayload].
typedef OnBannerShow = Future<void> Function(NotificationPayload payload);

/// Async callback that dispatches a deep-link navigation for the
/// parsed [NotificationPayload].
typedef OnDeepLink = Future<void> Function(NotificationPayload payload);

/// Routes incoming FCM [RemoteMessage]s to the appropriate client-side
/// handler (foreground banner / background tap / cold-start intent).
///
/// All three handlers share a single defensive-parse contract — a
/// malformed payload (unknown `type`, missing required fields,
/// unparseable date) is silently dropped without raising or invoking
/// any callback. This mirrors the FR-AC-01 parse-failure-is-loud-in-
/// logs / silent-in-UI precedent on the read-side activity feed.
class NotificationHandler {
  /// Creates a [NotificationHandler].
  ///
  /// `ref` is a Riverpod reader used to mutate the
  /// [pendingDeepLinkProvider] state on the cold-start unauthenticated
  /// path. In production this is the [ProviderContainer] held by the
  /// `ProviderScope` at the top of `OneBytwoApp`; in tests it is a
  /// hand-rolled [ProviderContainer].
  const NotificationHandler({
    required this.ref,
    required this.onBannerShow,
    required this.onDeepLink,
  });

  /// Riverpod reader used to mutate [pendingDeepLinkProvider] on the
  /// cold-start unauthenticated path.
  final Refable ref;

  /// Async callback that shows the foreground in-app banner.
  final OnBannerShow onBannerShow;

  /// Async callback that dispatches a deep-link navigation.
  final OnDeepLink onDeepLink;

  /// Handles a foreground FCM data message (app in foreground).
  ///
  /// Parses the payload and invokes `onBannerShow` so the host widget
  /// can mount the in-app notification banner overlay. Silently drops
  /// malformed payloads.
  Future<void> handleForegroundMessage(RemoteMessage message) async {
    final payload = NotificationPayload.fromFcmDataMap(message.data);
    if (payload == null) {
      debugPrint(
        '[NotificationHandler] foreground: dropped malformed payload '
        '${message.data}',
      );
      return;
    }
    await onBannerShow(payload);
  }

  /// Handles a backgrounded-app tap (system tray notification opened).
  ///
  /// Parses the payload and invokes `onDeepLink`. Silently drops
  /// malformed payloads.
  Future<void> handleBackgroundTap(RemoteMessage message) async {
    final payload = NotificationPayload.fromFcmDataMap(message.data);
    if (payload == null) {
      debugPrint(
        '[NotificationHandler] background tap: dropped malformed payload '
        '${message.data}',
      );
      return;
    }
    await onDeepLink(payload);
  }

  /// Handles a cold-start launch from a tapped notification (app fully
  /// terminated). FR-AC-05.
  ///
  /// If `currentUid` is non-null (the user has an authenticated
  /// session restored by FirebaseAuth), dispatches immediately via
  /// `onDeepLink`. Otherwise stores the payload in
  /// [pendingDeepLinkProvider] for replay after the next successful
  /// sign-in.
  Future<void> handleColdStart(
    RemoteMessage message, {
    required String? currentUid,
  }) async {
    final payload = NotificationPayload.fromFcmDataMap(message.data);
    if (payload == null) {
      debugPrint(
        '[NotificationHandler] cold start: dropped malformed payload '
        '${message.data}',
      );
      return;
    }
    if (currentUid != null) {
      await onDeepLink(payload);
    } else {
      ref.read(pendingDeepLinkProvider.notifier).state = payload;
    }
  }
}

/// Top-level background-message handler invoked by FCM in a separate
/// isolate when the app is in the background or terminated. Required
/// by Flutter Firebase docs — the handler MUST be a top-level (or
/// static) function annotated with `@pragma('vm:entry-point')`.
///
/// For v1.0 the handler is a no-op beyond re-initialising Firebase in
/// the background isolate. The FCM data message is delivered to the
/// system tray automatically by the platform; the tap event is then
/// routed through [FirebaseMessaging.onMessageOpenedApp] (warm) or
/// [FirebaseMessaging.getInitialMessage] (cold) when the user opens
/// the app.
///
/// **Note:** Background isolates do NOT share state with the main
/// isolate. Any work performed here cannot touch ProviderScope or
/// Navigator. Persistent state must be written to Firestore / local
/// storage.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Re-initialise Firebase in the background isolate.
  await Firebase.initializeApp();
  debugPrint(
    '[NotificationHandler] background isolate received message '
    '${message.messageId} (data keys: ${message.data.keys.toList()})',
  );
}

/// Minimal interface over Riverpod's [Ref] / [ProviderContainer]
/// `read` method — abstracted so [NotificationHandler] can accept
/// either a [ProviderContainer] (production) or a test container.
///
/// Both [ProviderContainer] and [Ref] expose a `read(provider)` method
/// with the same signature, so we type the handler against a duck-
/// typed callable rather than a concrete class.
typedef Refable = ProviderContainer;
