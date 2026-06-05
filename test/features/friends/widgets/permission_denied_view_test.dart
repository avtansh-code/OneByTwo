// Widget tests for [PermissionDeniedView].
//
// Covers the three CTAs the widget exposes:
//   - Grant Permission       (non-permanent denial)
//   - Open Settings          (permanent denial)
//   - Type a number instead  (optional fallback, added for AC-6 of
//                             FR-FR-01 Path B)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/friends/presentation/widgets/permission_denied_view.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('PermissionDeniedView', () {
    testWidgets('shows Grant Permission CTA when not permanently denied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionDeniedView(
            isDeniedPermanently: false,
            onGrantPermission: () {},
            onOpenSettings: () {},
          ),
        ),
      );

      expect(find.text('Grant Permission'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('shows Open Settings CTA when permanently denied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PermissionDeniedView(
            isDeniedPermanently: true,
            onGrantPermission: () {},
            onOpenSettings: () {},
          ),
        ),
      );

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Grant Permission'), findsNothing);
    });

    testWidgets('invokes onGrantPermission when Grant CTA tapped', (
      tester,
    ) async {
      var grantCalled = 0;
      await tester.pumpWidget(
        _wrap(
          PermissionDeniedView(
            isDeniedPermanently: false,
            onGrantPermission: () => grantCalled++,
            onOpenSettings: () {},
          ),
        ),
      );

      await tester.tap(find.text('Grant Permission'));
      await tester.pump();

      expect(grantCalled, 1);
    });

    testWidgets('invokes onOpenSettings when Settings CTA tapped', (
      tester,
    ) async {
      var settingsCalled = 0;
      await tester.pumpWidget(
        _wrap(
          PermissionDeniedView(
            isDeniedPermanently: true,
            onGrantPermission: () {},
            onOpenSettings: () => settingsCalled++,
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pump();

      expect(settingsCalled, 1);
    });

    // ─── Type-a-number-instead link (AC-6 fallback) ───────────────────────

    testWidgets(
      'does NOT render Type a number instead link when onTypeNumberInstead '
      'is null (backwards-compatibility default)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            PermissionDeniedView(
              isDeniedPermanently: false,
              onGrantPermission: () {},
              onOpenSettings: () {},
            ),
          ),
        );

        expect(find.text('Type a number instead'), findsNothing);
      },
    );

    testWidgets(
      'renders Type a number instead link when onTypeNumberInstead provided '
      '(non-permanent denial)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            PermissionDeniedView(
              isDeniedPermanently: false,
              onGrantPermission: () {},
              onOpenSettings: () {},
              onTypeNumberInstead: () {},
            ),
          ),
        );

        expect(find.text('Type a number instead'), findsOneWidget);
        // The primary CTA must still be present.
        expect(find.text('Grant Permission'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Type a number instead link when onTypeNumberInstead provided '
      '(permanent denial)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            PermissionDeniedView(
              isDeniedPermanently: true,
              onGrantPermission: () {},
              onOpenSettings: () {},
              onTypeNumberInstead: () {},
            ),
          ),
        );

        expect(find.text('Type a number instead'), findsOneWidget);
        expect(find.text('Open Settings'), findsOneWidget);
      },
    );

    testWidgets('invokes onTypeNumberInstead when fallback link tapped', (
      tester,
    ) async {
      var typeNumberCalled = 0;
      await tester.pumpWidget(
        _wrap(
          PermissionDeniedView(
            isDeniedPermanently: false,
            onGrantPermission: () {},
            onOpenSettings: () {},
            onTypeNumberInstead: () => typeNumberCalled++,
          ),
        ),
      );

      await tester.tap(find.text('Type a number instead'));
      await tester.pump();

      expect(typeNumberCalled, 1);
    });
  });
}
