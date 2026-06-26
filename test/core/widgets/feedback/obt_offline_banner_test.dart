import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_offline_banner.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTOfflineBanner', () {
    testWidgets('online renders nothing (empty state)', (tester) async {
      await pumpThemed(
        tester,
        const OBTOfflineBanner(status: OBTSyncStatus.online),
      );

      expect(find.byType(Icon), findsNothing);
      expect(find.textContaining('offline'), findsNothing);
      expect(find.textContaining('Syncing'), findsNothing);
    });

    testWidgets('offline shows cloud_off + amber bed + announced label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTOfflineBanner(status: OBTSyncStatus.offline),
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(OBTOfflineBanner),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, OBTColors.light.warning);

      // The status is announced as text (never colour alone).
      expect(
        find.bySemanticsLabel(
          'You are offline. Changes will sync when you reconnect.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('pendingSync shows the sync icon and pluralised count', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTOfflineBanner(
          status: OBTSyncStatus.pendingSync,
          pendingCount: 3,
        ),
        // Freeze the sync spin so pumpAndSettle completes deterministically.
        disableAnimations: true,
      );

      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.text('Syncing 3 changes…'), findsOneWidget);
    });

    testWidgets('pendingSync count of 1 is singular', (tester) async {
      await pumpThemed(
        tester,
        const OBTOfflineBanner(
          status: OBTSyncStatus.pendingSync,
          pendingCount: 1,
        ),
        disableAnimations: true,
      );

      expect(find.text('Syncing 1 change…'), findsOneWidget);
    });

    testWidgets('spins a frame when motion enabled (no settle timeout)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTOfflineBanner(
          status: OBTSyncStatus.pendingSync,
          pendingCount: 2,
        ),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        const OBTOfflineBanner(status: OBTSyncStatus.offline),
        brightness: Brightness.dark,
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(OBTOfflineBanner),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, OBTColors.dark.warning);
    });
  });
}
