import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/inputs/obt_segmented_split_control.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  Widget control({
    required int totalPaise,
    required int allocatedPaise,
    SplitMethod selected = SplitMethod.equal,
    ValueChanged<SplitMethod>? onMethodSelected,
    ValueChanged<bool>? onBalancedChanged,
    VoidCallback? onNext,
  }) {
    return OBTSegmentedSplitControl(
      selected: selected,
      enabledMethods: const <SplitMethod>{SplitMethod.equal, SplitMethod.exact},
      onMethodSelected: onMethodSelected ?? (_) {},
      totalPaise: totalPaise,
      allocatedPaise: allocatedPaise,
      onBalancedChanged: onBalancedChanged,
      onNext: onNext ?? () {},
    );
  }

  group('OBTSegmentedSplitControl — sum validation (AC-4)', () {
    testWidgets('balanced shows the green "adds up" state, Next enabled', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        control(totalPaise: 100000, allocatedPaise: 100000),
      );

      expect(find.text('Splits add up'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNotNull);

      // The green signal is the balancePositive token.
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
      expect(icon.color, OBTColors.light.balancePositive);
    });

    testWidgets(
      'NEGATIVE CASE — over shows red over state and Next is disabled',
      (tester) async {
        await pumpThemed(
          tester,
          control(totalPaise: 100000, allocatedPaise: 120000),
        );

        // ₹200.00 over (integer paise; rendered via formatInrFromPaise).
        expect(find.text('Over by ₹200.00'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        final next = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(next.onPressed, isNull);

        final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
        expect(icon.color, AppTheme.light.colorScheme.error);
      },
    );

    testWidgets('under shows the red short state and Next disabled', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        control(totalPaise: 100000, allocatedPaise: 75000),
      );

      expect(find.text('Short by ₹250.00'), findsOneWidget);
      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNull);
    });

    testWidgets('onBalancedChanged is notified with the validity', (
      tester,
    ) async {
      bool? balanced;
      await pumpThemed(
        tester,
        control(
          totalPaise: 100000,
          allocatedPaise: 100000,
          onBalancedChanged: (b) => balanced = b,
        ),
      );
      expect(balanced, isTrue);
    });
  });

  group('OBTSegmentedSplitControl — method selection', () {
    testWidgets('tapping an enabled method fires onMethodSelected', (
      tester,
    ) async {
      SplitMethod? picked;
      await pumpThemed(
        tester,
        control(
          totalPaise: 100000,
          allocatedPaise: 100000,
          onMethodSelected: (m) => picked = m,
        ),
      );

      await tester.tap(find.text('Exact'));
      await tester.pump();
      expect(picked, SplitMethod.exact);
    });

    testWidgets(
      'reserved methods are present, "Coming soon" and not interactive',
      (tester) async {
        var fired = 0;
        await pumpThemed(
          tester,
          control(
            totalPaise: 100000,
            allocatedPaise: 100000,
            onMethodSelected: (_) => fired++,
          ),
        );

        // The three reserved methods are rendered.
        expect(find.text('Unequal'), findsOneWidget);
        expect(find.text('%'), findsOneWidget);
        expect(find.text('Shares'), findsOneWidget);

        await tester.tap(find.text('Unequal'));
        await tester.pump();
        expect(fired, 0, reason: 'reserved methods are inert');
      },
    );

    testWidgets('every interactive control is labelled (QA B.4)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        control(totalPaise: 100000, allocatedPaise: 100000),
      );
      // Segments are button-flag nodes (their InkWell tap action is
      // excluded); assert each label directly, including the inert
      // "Coming soon" methods announced disabled.
      expect(find.bySemanticsLabel('Equally'), findsOneWidget);
      expect(find.bySemanticsLabel('Exact'), findsOneWidget);
      expect(find.bySemanticsLabel('Unequal, coming soon'), findsOneWidget);
      await expectAllInteractiveNodesLabelled(tester);
    });

    testWidgets('segments meet the 48dp minimum tap target (SRS 5.6)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        control(totalPaise: 100000, allocatedPaise: 100000),
      );
      await expectAllTapTargetsMeetMinSize(tester);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        control(totalPaise: 100000, allocatedPaise: 50000),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
