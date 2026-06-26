import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/inputs/obt_otp_input.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTOtpInput', () {
    testWidgets('renders six input cells (populated/empty)', (tester) async {
      await pumpThemed(
        tester,
        OBTOtpInput(
          onDigitEntered: (_, _) {},
          onCompleted: (_) {},
          onBackspace: (_) {},
        ),
      );

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('entering a digit fires onDigitEntered and auto-advances', (
      tester,
    ) async {
      final captured = List.filled(6, '');
      await pumpThemed(
        tester,
        OBTOtpInput(
          onDigitEntered: (index, digit) => captured[index] = digit,
          onCompleted: (_) {},
          onBackspace: (_) {},
        ),
      );

      await tester.enterText(find.byType(TextField).first, '4');
      await tester.pump();
      expect(captured[0], '4');
    });

    testWidgets('pasting six digits distributes and completes', (tester) async {
      String? completed;
      await pumpThemed(
        tester,
        OBTOtpInput(
          onDigitEntered: (_, _) {},
          onCompleted: (otp) => completed = otp,
          onBackspace: (_) {},
        ),
      );

      await tester.enterText(find.byType(TextField).first, '135790');
      await tester.pump();
      expect(completed, '135790');
    });

    testWidgets('error state shows the message and danger border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTOtpInput(
          onDigitEntered: (_, _) {},
          onCompleted: (_) {},
          onBackspace: (_) {},
          errorText: 'Incorrect code',
        ),
      );

      expect(find.text('Incorrect code'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      final border = field.decoration!.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, AppTheme.light.colorScheme.error);
    });

    testWidgets(
      'NEGATIVE CASE — pasting fewer than six digits does not complete',
      (tester) async {
        var completedCount = 0;
        await pumpThemed(
          tester,
          OBTOtpInput(
            onDigitEntered: (_, _) {},
            onCompleted: (_) => completedCount++,
            onBackspace: (_) {},
          ),
        );

        await tester.enterText(find.byType(TextField).first, '123');
        await tester.pump();
        expect(completedCount, 0);
      },
    );

    testWidgets('exposes per-cell and group semantic labels (QA B.4)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTOtpInput(
          onDigitEntered: (_, _) {},
          onCompleted: (_) {},
          onBackspace: (_) {},
        ),
      );

      expect(
        find.bySemanticsLabel('Enter 6-digit verification code'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Digit 1 of 6'), findsOneWidget);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        OBTOtpInput(
          onDigitEntered: (_, _) {},
          onCompleted: (_) {},
          onBackspace: (_) {},
        ),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
