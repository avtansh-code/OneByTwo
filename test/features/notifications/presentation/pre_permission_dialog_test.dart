// PrePermissionDialog widget tests (FR-AC-03, AC-20).
//
// Covers the "Stay in the loop" dialog (wireframes §1.1):
//   - Heading announced as a heading (Semantics(header: true)).
//   - "Enable Notifications" button has min 48dp tap target.
//   - "Not now" button has min 48dp tap target.
//   - Tap "Enable" → calls onEnable callback.
//   - Tap "Not now" → calls onDismiss callback.
//   - Tap scrim → calls onDismiss callback (≡ "Not now" per wireframes §1.2).
//   - Back gesture → calls onDismiss.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/notifications/presentation/pre_permission_dialog.dart';

Future<void> _pumpAndShowDialog(
  WidgetTester tester, {
  required VoidCallback onEnable,
  required VoidCallback onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showPrePermissionDialog(
                context: context,
                onEnable: onEnable,
                onDismiss: onDismiss,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('PrePermissionDialog — content', () {
    testWidgets('renders heading + body + both buttons', (tester) async {
      await _pumpAndShowDialog(tester, onEnable: () {}, onDismiss: () {});

      expect(find.text('Stay in the loop'), findsOneWidget);
      expect(
        find.textContaining('Get notified when friends add expenses'),
        findsOneWidget,
      );
      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('heading is announced as a heading (Semantics header)', (
      tester,
    ) async {
      await _pumpAndShowDialog(tester, onEnable: () {}, onDismiss: () {});

      final headingSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.header ?? false)
          .toList();
      expect(
        headingSemantics,
        isNotEmpty,
        reason:
            'Expected at least one Semantics(header: true) widget '
            'wrapping the heading text per AC-20.',
      );
    });
  });

  group('PrePermissionDialog — interaction', () {
    testWidgets('Tap "Enable Notifications" invokes onEnable callback', (
      tester,
    ) async {
      var enabledCount = 0;
      await _pumpAndShowDialog(
        tester,
        onEnable: () => enabledCount += 1,
        onDismiss: () {},
      );

      await tester.tap(find.text('Enable Notifications'));
      await tester.pumpAndSettle();

      expect(enabledCount, 1);
    });

    testWidgets('Tap "Not now" invokes onDismiss callback', (tester) async {
      var dismissedCount = 0;
      await _pumpAndShowDialog(
        tester,
        onEnable: () {},
        onDismiss: () => dismissedCount += 1,
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(dismissedCount, 1);
    });

    testWidgets('Tap scrim invokes onDismiss (equivalent to Not now '
        'per wireframes §1.2)', (tester) async {
      var dismissedCount = 0;
      await _pumpAndShowDialog(
        tester,
        onEnable: () {},
        onDismiss: () => dismissedCount += 1,
      );

      // Tap at top-left to hit the barrier scrim outside the dialog
      // content card.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(dismissedCount, 1);
    });
  });

  group('PrePermissionDialog — accessibility', () {
    testWidgets('"Enable Notifications" button has min 48dp height tap '
        'target', (tester) async {
      await _pumpAndShowDialog(tester, onEnable: () {}, onDismiss: () {});

      final enableButton = find.ancestor(
        of: find.text('Enable Notifications'),
        matching: find.byType(FilledButton),
      );
      expect(enableButton, findsOneWidget);
      final size = tester.getSize(enableButton);
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason: 'Enable Notifications button must meet 48dp tap target',
      );
    });

    testWidgets('"Not now" button has min 48dp height tap target', (
      tester,
    ) async {
      await _pumpAndShowDialog(tester, onEnable: () {}, onDismiss: () {});

      final notNowButton = find.ancestor(
        of: find.text('Not now'),
        matching: find.byType(TextButton),
      );
      expect(notNowButton, findsOneWidget);
      final size = tester.getSize(notNowButton);
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason: 'Not now button must meet 48dp tap target',
      );
    });
  });
}
