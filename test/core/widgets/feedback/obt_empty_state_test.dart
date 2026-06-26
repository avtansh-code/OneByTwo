import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTEmptyState', () {
    testWidgets('renders illustration, headline, supporting text and CTA', (
      tester,
    ) async {
      var tapped = 0;
      await pumpThemed(
        tester,
        OBTEmptyState(
          illustration: const Icon(Icons.group_outlined),
          headline: 'No friends yet',
          supportingText: 'Add a friend to start splitting expenses.',
          ctaLabel: 'Add a friend',
          onCta: () => tapped++,
        ),
      );

      expect(find.text('No friends yet'), findsOneWidget);
      expect(
        find.text('Add a friend to start splitting expenses.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Add a friend'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('renders without a CTA when none is supplied', (tester) async {
      await pumpThemed(
        tester,
        const OBTEmptyState(
          illustration: Icon(Icons.inbox_outlined),
          headline: 'Nothing here',
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('NEGATIVE CASE — the CTA is ink on marigold, never white', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTEmptyState(
          illustration: const Icon(Icons.group_outlined),
          headline: 'No friends yet',
          ctaLabel: 'Add a friend',
          onCta: () {},
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final fg = button.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(fg, AppTheme.light.colorScheme.onPrimary);
      expect(
        fg,
        isNot(Colors.white),
        reason: 'White on marigold fails AA; the CTA glyph must be ink.',
      );
    });

    testWidgets('every interactive control is labelled (QA B.4)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTEmptyState(
          illustration: const Icon(Icons.group_outlined),
          headline: 'No friends yet',
          ctaLabel: 'Add a friend',
          onCta: () {},
        ),
      );

      await expectAllInteractiveNodesLabelled(tester);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        const OBTEmptyState(
          illustration: Icon(Icons.inbox_outlined),
          headline: 'Nothing here',
        ),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
