import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTBalancePill — the colour + icon + label trio (QA B.3)', () {
    testWidgets('positive: balancePositive + arrow_upward + "you are owed"', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 50000)),
      );

      // Independently findable (greyscale / colour-blind survival).
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('you are owed'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);

      // And the colour branch is correct.
      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(icon.color, OBTColors.light.balancePositive);
    });

    testWidgets('negative: balanceNegative + arrow_downward + "you owe"', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: -50000)),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.text('you owe'), findsOneWidget);
      // Magnitude only — the sign is carried by icon + label + colour.
      expect(find.text('₹500.00'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
      expect(icon.color, OBTColors.light.balanceNegative);
    });

    testWidgets('zero: balanceZero + check + "Settled up", no amount', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 0)),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Settled up'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color, OBTColors.light.balanceZero);
    });

    testWidgets('positiveLabelOverride changes the label, not the trio', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Center(
          child: OBTBalancePill(
            netBalancePaise: 12300,
            positiveLabelOverride: 'owes you',
          ),
        ),
      );

      expect(find.text('owes you'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets(
      'NEGATIVE CASE — a colour-only pill (no icon, no label) fails the trio',
      (tester) async {
        // A careless reskin that signals balance by colour alone: this is
        // exactly what the trio test above must reject. Proven here to fail
        // the icon + label finders.
        await pumpThemed(
          tester,
          Center(
            child: Container(
              width: 60,
              height: 24,
              color: OBTColors.light.balancePositive,
            ),
          ),
        );

        expect(find.byIcon(Icons.arrow_upward), findsNothing);
        expect(find.text('you are owed'), findsNothing);
      },
    );
  });

  group('OBTBalancePill — dark theme', () {
    testWidgets('positive uses the dark balancePositive token', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 50000)),
        brightness: Brightness.dark,
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(icon.color, OBTColors.dark.balancePositive);
    });
  });

  group('OBTBalancePill — dynamic type 2.0x (QA C.2)', () {
    for (final width in <double>[390, 320]) {
      testWidgets('row at ${width.toInt()}px never overflows; amount whole', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          const Center(child: OBTBalancePill(netBalancePaise: 523400)),
          textScale: 2,
          surfaceSize: Size(width, 844),
        );

        expect(tester.takeException(), isNull);
        // The amount is rendered whole — never ellipsised or clipped.
        expect(find.text('₹5,234.00'), findsOneWidget);
      });
    }
  });
}
