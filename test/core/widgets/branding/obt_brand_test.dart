import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/branding/obt_brand.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTBrandMark', () {
    testWidgets('renders the painted division mark', (tester) async {
      await pumpThemed(tester, const OBTBrandMark());
      expect(find.byType(OBTBrandMark), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('OBTWordmark', () {
    testWidgets('renders One / By / Two with the accent on "By"', (
      tester,
    ) async {
      await pumpThemed(tester, const OBTWordmark());

      expect(find.bySemanticsLabel('One By Two'), findsOneWidget);
      final text = tester.widget<Text>(find.byType(Text));
      final span = text.textSpan! as TextSpan;
      final children = span.children!.cast<TextSpan>();
      expect(children.map((s) => s.text), <String>['One', 'By', 'Two']);
      expect(children[1].style!.color, OBTColors.light.primaryPressed);
    });
  });

  group('OBTBrandLockup', () {
    testWidgets('vertical and horizontal lockups carry one semantic label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          children: <Widget>[
            OBTBrandLockup(),
            OBTBrandLockup(direction: Axis.horizontal),
          ],
        ),
      );
      expect(find.bySemanticsLabel('One By Two'), findsNWidgets(2));
    });
  });

  group('OBTSplashGradient', () {
    testWidgets('NEGATIVE CASE — marigold ramp, ink foreground, never white', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTSplashGradient(
          child: OBTBrandLockup(color: Color(0xFF1A1510)),
        ),
        wrapInScaffold: false,
      );

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OBTSplashGradient),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, <Color>[
        AppTheme.light.colorScheme.primary,
        OBTColors.light.primaryPressed,
      ]);
      expect(gradient.colors, isNot(contains(Colors.white)));
    });

    testWidgets('renders its child', (tester) async {
      await pumpThemed(
        tester,
        const OBTSplashGradient(child: Text('SPLASH')),
        wrapInScaffold: false,
      );
      expect(find.text('SPLASH'), findsOneWidget);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        const OBTSplashGradient(child: OBTBrandLockup()),
        wrapInScaffold: false,
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
