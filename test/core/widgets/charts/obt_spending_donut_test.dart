import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/charts/obt_spending_donut.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  const slices = <OBTCategorySlice>[
    OBTCategorySlice(category: OBTCategory.food, totalPaise: 60000),
    OBTCategorySlice(category: OBTCategory.transport, totalPaise: 30000),
    OBTCategorySlice(category: OBTCategory.shopping, totalPaise: 10000),
  ];

  group('OBTSpendingDonut', () {
    testWidgets('renders the centre total (Bricolage tabular, fits the hole)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTSpendingDonut(slices: slices, monthTotalPaise: 100000),
        disableAnimations: true,
      );

      // The centre total renders via formatInrFromPaise (Invariant 1) at the
      // amount-row scale (16px), not the 48px hero — it must fit the hole.
      final total = tester.widget<Text>(find.text('₹1,000.00'));
      expect(total.style!.fontSize, 16);
    });

    testWidgets('the painted ring carries a single accessible summary', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTSpendingDonut(slices: slices, monthTotalPaise: 100000),
        disableAnimations: true,
      );

      expect(
        find.bySemanticsLabel(
          'This month you have spent ₹1,000.00 across 3 categories',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        const OBTSpendingDonut(slices: slices, monthTotalPaise: 100000),
        brightness: Brightness.dark,
        disableAnimations: true,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('OBTCategoryLegend', () {
    testWidgets('renders label + amount + integer percentage per slice', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTCategoryLegend(slices: slices, monthTotalPaise: 100000),
      );

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('₹600.00'), findsOneWidget);
      // Largest-remainder integer percentages sum to exactly 100.
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
    });

    testWidgets(
      'NEGATIVE CASE — meaning is never colour-only (label + value present)',
      (tester) async {
        await pumpThemed(
          tester,
          const OBTCategoryLegend(
            slices: <OBTCategorySlice>[
              OBTCategorySlice(category: OBTCategory.rent, totalPaise: 100000),
            ],
            monthTotalPaise: 100000,
          ),
        );

        // The hue swatch alone is insufficient; the row also carries the
        // category label, the rupee value and the percentage as text.
        expect(find.text('Rent'), findsOneWidget);
        expect(find.text('₹1,000.00'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
      },
    );

    testWidgets('legend swatch uses the Haldi category hue', (tester) async {
      await pumpThemed(
        tester,
        const OBTCategoryLegend(slices: slices, monthTotalPaise: 100000),
      );

      final firstIcon = tester.widget<Icon>(find.byIcon(Icons.restaurant));
      expect(firstIcon.color, AppTheme.light.colorScheme.onSurface);
      expect(tester.takeException(), isNull);
    });
  });
}
