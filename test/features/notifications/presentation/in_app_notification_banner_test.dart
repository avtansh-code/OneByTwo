// InAppNotificationBanner widget tests (FR-AC-03).
//
// Covers the foreground banner (wireframes §2):
//   - Renders title + body + category icon per type.
//   - Auto-dismisses after 4 seconds.
//   - Tap → calls onTap(payload).
//   - Swipe up → calls onDismiss.
//   - Min 64dp height (satisfies 48dp tap target).
//   - Semantic label includes title + body + tap/swipe hint.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/notifications/presentation/widgets/in_app_notification_banner.dart';

NotificationPayload _payload({
  NotificationType type = NotificationType.expenseAdded,
  String title = 'Rahul added an expense',
  String body = 'Dinner — Rs.600.',
}) {
  return NotificationPayload(
    type: type,
    contextType: 'friendship',
    contextId: 'uid-a_uid-b',
    itemId: 'expense-1',
    title: title,
    body: body,
    senderName: 'Rahul',
    amountPaise: 60000,
    createdAt: DateTime.utc(2026, 6, 8),
  );
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  required NotificationPayload payload,
  required void Function(NotificationPayload) onTap,
  required VoidCallback onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InAppNotificationBanner(
          payload: payload,
          onTap: onTap,
          onDismiss: onDismiss,
        ),
      ),
    ),
  );
}

void main() {
  group('InAppNotificationBanner — content', () {
    testWidgets('renders title and body text', (tester) async {
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (_) {},
        onDismiss: () {},
      );
      await tester.pump(); // start the entrance animation
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Rahul added an expense'), findsOneWidget);
      expect(find.text('Dinner — Rs.600.'), findsOneWidget);
    });

    testWidgets('renders the expense receipt icon for expense_added', (
      tester,
    ) async {
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (_) {},
        onDismiss: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });

    testWidgets('renders the settlement tick-circle icon for '
        'settlement_received', (tester) async {
      await _pumpBanner(
        tester,
        payload: _payload(type: NotificationType.settlementReceived),
        onTap: (_) {},
        onDismiss: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders the reminder bell icon for reminder', (tester) async {
      await _pumpBanner(
        tester,
        payload: _payload(type: NotificationType.reminder),
        onTap: (_) {},
        onDismiss: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });
  });

  group('InAppNotificationBanner — interaction', () {
    testWidgets('Tap → calls onTap(payload)', (tester) async {
      NotificationPayload? captured;
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (p) => captured = p,
        onDismiss: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byType(InAppNotificationBanner));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.type, NotificationType.expenseAdded);
    });

    testWidgets('Swipe up → calls onDismiss', (tester) async {
      var dismissed = 0;
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (_) {},
        onDismiss: () => dismissed += 1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.fling(
        find.byType(InAppNotificationBanner),
        const Offset(0, -300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(dismissed, greaterThanOrEqualTo(1));
    });

    testWidgets('auto-dismisses after 4 seconds', (tester) async {
      var dismissed = 0;
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (_) {},
        onDismiss: () => dismissed += 1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Not yet auto-dismissed.
      await tester.pump(const Duration(seconds: 3));
      expect(dismissed, 0);

      // Past the 4-second threshold.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    });
  });

  group('InAppNotificationBanner — accessibility', () {
    testWidgets('container is at least 64dp tall (satisfies 48dp tap target)', (
      tester,
    ) async {
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (_) {},
        onDismiss: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final size = tester.getSize(find.byType(InAppNotificationBanner));
      expect(size.height, greaterThanOrEqualTo(64));
    });

    testWidgets('exposes a Semantics label with title + body + hint', (
      tester,
    ) async {
      await _pumpBanner(
        tester,
        payload: _payload(),
        onTap: (_) {},
        onDismiss: () {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Find any Semantics whose label includes both title and body
      // text plus the interaction hint per wireframes §2.4.
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label ?? '')
          .toList();
      final hasFullLabel = labels.any(
        (l) =>
            l.contains('Rahul added an expense') &&
            l.contains('Dinner') &&
            l.contains('Tap to view') &&
            l.contains('Swipe up'),
      );
      expect(
        hasFullLabel,
        isTrue,
        reason:
            'Expected a Semantics(label: "<title>. <body>. Tap to '
            'view details. Swipe up to dismiss.") per wireframes §2.4. '
            'Got labels: $labels',
      );
    });
  });
}
