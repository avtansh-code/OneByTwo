import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/sheets/obt_stepper_sheet.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTStepperSheet', () {
    testWidgets('renders the title, step counter and the active step body', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTStepperSheet(
          currentStep: 2,
          totalSteps: 3,
          title: 'Add expense',
          stepBodies: <Widget>[
            Text('Step one body'),
            Text('Step two body'),
            Text('Step three body'),
          ],
        ),
        wrapInScaffold: false,
      );

      expect(find.text('Add expense'), findsOneWidget);
      // The numeric counter is conveyed via the dot indicator's semantics
      // label, not visible text.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      handle.dispose();
      expect(find.text('Step two body'), findsOneWidget);
      expect(find.text('Step one body'), findsNothing);
    });

    testWidgets('the visual stepper fills one bar per reached step', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTStepperSheet(
          currentStep: 2,
          totalSteps: 3,
          title: 'Add expense',
          stepBodies: <Widget>[Text('1'), Text('2'), Text('3')],
        ),
        wrapInScaffold: false,
      );

      // Three indicator bars; the (N/3) text counter is replaced by the
      // visual stepper. At least one bar is filled with the primary token.
      final colors = AppTheme.light.colorScheme;
      final barColors = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(barColors.contains(colors.primary), isTrue);
      expect(barColors.contains(colors.surfaceContainerHighest), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button fires onClose', (tester) async {
      var closed = 0;
      await pumpThemed(
        tester,
        OBTStepperSheet(
          currentStep: 1,
          totalSteps: 3,
          title: 'Add expense',
          stepBodies: const <Widget>[Text('1'), Text('2'), Text('3')],
          onClose: () => closed++,
        ),
        wrapInScaffold: false,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets('renders an optional footer', (tester) async {
      await pumpThemed(
        tester,
        const OBTStepperSheet(
          currentStep: 3,
          totalSteps: 3,
          title: 'Add expense',
          stepBodies: <Widget>[Text('1'), Text('2'), Text('3')],
          footer: Text('FOOTER'),
        ),
        wrapInScaffold: false,
      );
      expect(find.text('FOOTER'), findsOneWidget);
    });

    testWidgets(
      'NEGATIVE CASE — no close button is rendered when onClose is null',
      (tester) async {
        await pumpThemed(
          tester,
          const OBTStepperSheet(
            currentStep: 1,
            totalSteps: 3,
            title: 'Add expense',
            stepBodies: <Widget>[Text('1'), Text('2'), Text('3')],
          ),
          wrapInScaffold: false,
        );
        expect(find.byTooltip('Close'), findsNothing);
      },
    );

    testWidgets('every interactive control is labelled (QA B.4)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTStepperSheet(
          currentStep: 1,
          totalSteps: 3,
          title: 'Add expense',
          stepBodies: const <Widget>[Text('1'), Text('2'), Text('3')],
          onClose: () {},
        ),
        wrapInScaffold: false,
      );
      await expectAllInteractiveNodesLabelled(tester);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        const OBTStepperSheet(
          currentStep: 1,
          totalSteps: 3,
          title: 'Add expense',
          stepBodies: <Widget>[Text('1'), Text('2'), Text('3')],
        ),
        wrapInScaffold: false,
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
