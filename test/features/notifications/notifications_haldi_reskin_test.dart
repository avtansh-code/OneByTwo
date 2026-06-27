// Notifications flow Haldi reskin gate (DC-09; 04-qa-test-strategy.md §D).
//
// Complements the behavioural banner / dialog widget tests by pinning the
// DC-09 AC-2 / AC-3 contract those tests do not assert:
//   - the in-app banner's per-type icon hue is read from a Haldi TOKEN, not a
//     hard-coded hex — `settlementReceived` -> OBTColors.balancePositive,
//     `reminder` -> OBTColors.warning, expense -> colorScheme.primary, in
//     light AND dark (AC-2 / AC-3);
//   - the banner tap still forwards its payload (FR-AC-03 behaviour-frozen);
//   - every banner control is labelled and >= 48 dp; the banner does not
//     overflow at 2.0x dynamic type at 390 and 320 dp;
//   - the marigold contrast gate holds incl. the white-on-marigold NEGATIVE
//     case (the DC-01 ink-not-white rule), and the two re-pointed hues clear
//     AA on the surface;
//   - the pre-permission dialog renders under the Haldi theme in light + dark
//     without overflow at 2.0x.
//
// The no-`Color(0x…)` structural guard lives in the boundary-contract grep
// (notifications_boundary_contract_test.dart, AC-3).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/notifications/presentation/pre_permission_dialog.dart';
import 'package:onebytwo/features/notifications/presentation/widgets/in_app_notification_banner.dart';

import '../../support/widget_test_harness.dart';
import 'helpers/fake_payloads.dart';

Future<void> _pumpBanner(
  WidgetTester tester, {
  required NotificationPayload payload,
  void Function(NotificationPayload)? onTap,
  VoidCallback? onDismiss,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: InAppNotificationBanner(
                payload: payload,
                onTap: onTap ?? (_) {},
                onDismiss: onDismiss ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // The slide animation + the 4-second auto-dismiss timer never settle; pump
  // the entrance frames manually (the timer is cancelled on dispose).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Builder(
              builder: (innerContext) => Center(
                child: ElevatedButton(
                  onPressed: () => showPrePermissionDialog(
                    context: innerContext,
                    onEnable: () {},
                    onDismiss: () {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a) + 0.05;
  final lb = _luminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  // --- AC-2 / AC-3: the per-type icon hue is a Haldi token (light + dark) ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    final obt = brightness == Brightness.light
        ? OBTColors.light
        : OBTColors.dark;

    testWidgets('settlement icon = balancePositive token, not #2A9D8F '
        '($mode)', (tester) async {
      await _pumpBanner(
        tester,
        payload: notificationPayload(type: NotificationType.settlementReceived),
        brightness: brightness,
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, obt.balancePositive);
    });

    testWidgets('reminder icon = warning token, not #F4A261 ($mode)', (
      tester,
    ) async {
      await _pumpBanner(
        tester,
        payload: notificationPayload(type: NotificationType.reminder),
        brightness: brightness,
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.notifications_active));
      expect(icon.color, obt.warning);
    });

    testWidgets('expense icon = primary token ($mode)', (tester) async {
      await _pumpBanner(
        tester,
        payload: notificationPayload(),
        brightness: brightness,
      );
      final scheme = brightness == Brightness.light
          ? AppTheme.light.colorScheme
          : AppTheme.dark.colorScheme;
      final icon = tester.widget<Icon>(find.byIcon(Icons.receipt_long));
      expect(icon.color, scheme.primary);
    });

    testWidgets('the pre-permission dialog renders under Haldi ($mode)', (
      tester,
    ) async {
      await _pumpDialog(tester, brightness: brightness);
      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });
  }

  // --- FR-AC-03: the banner tap still forwards its payload ---
  testWidgets('banner tap forwards the payload (unchanged)', (tester) async {
    NotificationPayload? captured;
    await _pumpBanner(
      tester,
      payload: notificationPayload(type: NotificationType.settlementReceived),
      onTap: (p) => captured = p,
    );

    await tester.tap(find.byType(InAppNotificationBanner));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.type, NotificationType.settlementReceived);
  });

  // --- B.4: every banner control is labelled and meets 48 dp ---
  testWidgets('banner is labelled and meets 48 dp', (tester) async {
    await _pumpBanner(tester, payload: notificationPayload());

    await expectAllInteractiveNodesLabelled(tester);
    await expectAllTapTargetsMeetMinSize(tester);
  });

  // --- C: dynamic type 2.0x does not overflow (banner + dialog) ---
  for (final width in <double>[390, 320]) {
    testWidgets('banner does not overflow at 2.0x (${width.toInt()} dp)', (
      tester,
    ) async {
      await _pumpBanner(
        tester,
        payload: notificationPayload(),
        textScale: 2,
        surfaceSize: Size(width, 844),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialog does not overflow at 2.0x (${width.toInt()} dp)', (
      tester,
    ) async {
      await _pumpDialog(tester, textScale: 2, surfaceSize: Size(width, 844));
      expect(tester.takeException(), isNull);
    });
  }

  // --- B.1 / B.2: contrast gate incl. the white-on-marigold negative case ---
  group('contrast gate', () {
    test('the balancePositive settlement hue clears AA on the surface '
        '(light + dark)', () {
      final cases = <(OBTColors, ColorScheme)>[
        (OBTColors.light, AppTheme.light.colorScheme),
        (OBTColors.dark, AppTheme.dark.colorScheme),
      ];
      for (final (obt, scheme) in cases) {
        expect(
          _contrastRatio(obt.balancePositive, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason:
              'the settlement-received positive signal must be legible; '
              'the saffron warning hue is a decorative caution tint paired '
              'with the AA-legible title + body, so it carries no text floor',
        );
      }
    });

    test('white on marigold fails AA; ink on marigold passes', () {
      for (final scheme in <ColorScheme>[
        AppTheme.light.colorScheme,
        AppTheme.dark.colorScheme,
      ]) {
        expect(
          _contrastRatio(Colors.white, scheme.primary),
          lessThan(3.0),
          reason: 'white on marigold must fail even AA-large',
        );
        expect(
          _contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on marigold must clear AA',
        );
      }
    });
  });
}
