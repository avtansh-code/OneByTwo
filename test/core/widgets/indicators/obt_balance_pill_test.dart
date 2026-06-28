import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTBalancePill — one-line [icon] [amount] (Phase2 Components)', () {
    testWidgets('positive: balancePositive + arrow_upward + magnitude, no '
        'in-pill label', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 50000)),
      );

      // The pill is the colour + icon (+ amount); the directional label is
      // NOT inside the pill any more (it is the host row subtitle).
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('you are owed'), findsNothing);
      expect(find.text('owes you'), findsNothing);

      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(icon.color, OBTColors.light.balancePositive);
    });

    testWidgets('negative: balanceNegative + arrow_downward + magnitude '
        '(no minus, no in-pill label)', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: -50000)),
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      // Magnitude only — the sign is carried by icon + colour.
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('you owe'), findsNothing);

      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
      expect(icon.color, OBTColors.light.balanceNegative);
    });

    testWidgets('zero: balanceZero + check + "Settled", no amount, no '
        'subtitle copy', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 0)),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      // The in-pill copy is "Settled" (no amount); the row subtitle owns
      // the lower-case "settled up" label.
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Settled up'), findsNothing);
      expect(find.text('settled up'), findsNothing);

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color, OBTColors.light.balanceZero);
    });

    testWidgets('the amount is exactly one line and never wraps', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 50000)),
      );

      final amount = tester.widget<Text>(find.text('₹500.00'));
      expect(amount.maxLines, 1);
      expect(amount.softWrap, isFalse);
      // The whole [icon] [amount] row sits in a scale-down FittedBox.
      expect(find.byType(FittedBox), findsOneWidget);
    });
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

  group('OBTBalancePill — scales DOWN, never wraps or truncates (QA C.2)', () {
    testWidgets('a long magnitude in a deliberately narrow 80px box stays one '
        'line and scales down with no overflow', (tester) async {
      await pumpThemed(
        tester,
        const Center(
          child: SizedBox(
            width: 80,
            child: OBTBalancePill(netBalancePaise: 523400),
          ),
        ),
      );

      // No overflow — the FittedBox shrinks the row to fit the 80px slot.
      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsOneWidget);
      // Money is rendered whole (scaled down), never ellipsised or clipped.
      expect(find.text('₹5,234.00'), findsOneWidget);
      final amount = tester.widget<Text>(find.text('₹5,234.00'));
      expect(amount.maxLines, 1);
      expect(amount.softWrap, isFalse);
    });

    for (final width in <double>[390, 320]) {
      testWidgets('at ${width.toInt()}px and 2.0x text scale never overflows; '
          'amount whole', (tester) async {
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

  group('OBTBalancePill — accessibility (QA B.3)', () {
    testWidgets('the pill excludes its own semantics so the host row owns the '
        'colour-independent label (no double-read)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const Center(child: OBTBalancePill(netBalancePaise: 50000)),
      );

      // The pill contributes no semantics node (ExcludeSemantics): the
      // amount and direction are announced by the host row instead, so the
      // pill cannot double-read them.
      expect(find.bySemanticsLabel('₹500.00'), findsNothing);
      handle.dispose();
    });
  });
}
