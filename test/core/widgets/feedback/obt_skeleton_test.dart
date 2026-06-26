import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTSkeleton — silhouette variants', () {
    testWidgets('bare skeleton renders under reduced motion (frozen)', (
      tester,
    ) async {
      // disableAnimations freezes the shimmer to a static frame, so
      // pumpAndSettle completes (no perpetual controller).
      await pumpThemed(
        tester,
        const SizedBox(width: 120, child: OBTSkeleton(height: 16)),
        disableAnimations: true,
      );

      expect(find.byType(OBTSkeleton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('circle / row / card / list silhouettes render', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          children: <Widget>[
            OBTSkeletonCircle(diameter: 40),
            OBTSkeletonCard(),
            OBTSkeletonRow(),
            OBTSkeletonList(itemCount: 3),
          ],
        ),
        disableAnimations: true,
      );

      expect(find.byType(OBTSkeletonCircle), findsWidgets);
      expect(find.byType(OBTSkeletonRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        const OBTSkeletonList(itemCount: 2),
        brightness: Brightness.dark,
        disableAnimations: true,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('animates a single frame when motion is enabled', (
      tester,
    ) async {
      // settle: false avoids a pumpAndSettle timeout on the repeating
      // shimmer controller.
      await pumpThemed(
        tester,
        const SizedBox(width: 120, child: OBTSkeleton(height: 16)),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });

  group('OBTSkeleton — accessibility', () {
    testWidgets('list announces a single "Loading…" live region', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTSkeletonList(itemCount: 3),
        disableAnimations: true,
      );

      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    });

    testWidgets(
      'NEGATIVE CASE — a bare decorative skeleton makes no announcement',
      (tester) async {
        await pumpThemed(
          tester,
          const SizedBox(width: 120, child: OBTSkeleton(height: 16)),
          disableAnimations: true,
        );

        // The shape is purely decorative (ExcludeSemantics): no live region.
        expect(find.bySemanticsLabel('Loading…'), findsNothing);
      },
    );
  });
}
