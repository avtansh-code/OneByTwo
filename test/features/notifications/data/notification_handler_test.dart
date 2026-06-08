// NotificationHandler tests (FR-AC-03 + FR-AC-05).
//
// Verifies the three platform-handler entry points:
//   - handleForegroundMessage(remoteMessage) — parses + invokes the
//     banner-overlay callback.
//   - handleBackgroundTap(remoteMessage) — parses + dispatches via the
//     deep-link handler callback.
//   - handleColdStart(remoteMessage) — if unauthenticated, stores in
//     pendingDeepLinkProvider; if authenticated, dispatches immediately.
//
// Tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/notifications/application/pending_deep_link_provider.dart';
import 'package:onebytwo/features/notifications/data/notification_handler.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

RemoteMessage _validMessage({String type = 'expense_added'}) {
  return RemoteMessage(
    data: <String, dynamic>{
      'type': type,
      'contextType': 'friendship',
      'contextId': 'uid-a_uid-b',
      'itemId': 'expense-1',
      'title': 'Rahul added an expense',
      'body': 'Dinner — Rs.600.',
      'senderName': 'Rahul',
      'amountPaise': '60000',
      'createdAt': '2026-06-08T10:00:00.000Z',
    },
  );
}

RemoteMessage _malformedMessage() {
  return const RemoteMessage(data: <String, dynamic>{'type': 'expense_added'});
}

void main() {
  group('NotificationHandler.handleForegroundMessage', () {
    test('parses the payload and invokes the banner callback', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      NotificationPayload? captured;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (p) async => captured = p,
        onDeepLink: (_) async {},
      );

      await handler.handleForegroundMessage(_validMessage());

      expect(captured, isNotNull);
      expect(captured!.type, NotificationType.expenseAdded);
      expect(captured!.contextId, 'uid-a_uid-b');
    });

    test('silently drops malformed payloads without invoking the '
        'banner callback (defence-in-depth)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var called = false;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (_) async {
          called = true;
        },
        onDeepLink: (_) async {},
      );

      await handler.handleForegroundMessage(_malformedMessage());

      expect(called, isFalse);
    });
  });

  group('NotificationHandler.handleBackgroundTap', () {
    test('parses the payload and invokes the deep-link callback', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      NotificationPayload? captured;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (_) async {},
        onDeepLink: (p) async => captured = p,
      );

      await handler.handleBackgroundTap(
        _validMessage(type: 'settlement_received'),
      );

      expect(captured, isNotNull);
      expect(captured!.type, NotificationType.settlementReceived);
    });

    test('silently drops malformed payloads', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var called = false;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (_) async {},
        onDeepLink: (_) async {
          called = true;
        },
      );

      await handler.handleBackgroundTap(_malformedMessage());

      expect(called, isFalse);
    });
  });

  group('NotificationHandler.handleColdStart', () {
    test('stores the payload in pendingDeepLinkProvider when '
        'unauthenticated (currentUid = null)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var deepLinkCalled = false;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (_) async {},
        onDeepLink: (_) async => deepLinkCalled = true,
      );

      await handler.handleColdStart(_validMessage(), currentUid: null);

      expect(deepLinkCalled, isFalse);
      final pending = container.read(pendingDeepLinkProvider);
      expect(pending, isNotNull);
      expect(pending!.type, NotificationType.expenseAdded);
    });

    test('dispatches via deep-link callback when authenticated (currentUid '
        'is set)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      NotificationPayload? captured;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (_) async {},
        onDeepLink: (p) async => captured = p,
      );

      await handler.handleColdStart(
        _validMessage(type: 'reminder'),
        currentUid: 'uid-me',
      );

      expect(captured, isNotNull);
      expect(captured!.type, NotificationType.reminder);
      // The pending provider stays null in the authenticated path.
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    test('does nothing when payload is malformed (no pending intent, no '
        'deep-link dispatch)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var deepLinkCalled = false;
      final handler = NotificationHandler(
        ref: container,
        onBannerShow: (_) async {},
        onDeepLink: (_) async => deepLinkCalled = true,
      );

      await handler.handleColdStart(_malformedMessage(), currentUid: 'uid-me');

      expect(deepLinkCalled, isFalse);
      expect(container.read(pendingDeepLinkProvider), isNull);
    });
  });
}
