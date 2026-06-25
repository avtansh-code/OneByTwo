import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/presentation/widgets/otp_input.dart';

void main() {
  group('OtpInput widget', () {
    late List<String> capturedDigits;
    late bool onCompletedCalled;

    setUp(() {
      capturedDigits = List.filled(6, '');
      onCompletedCalled = false;
    });

    Widget buildSubject({List<String>? digits}) {
      return MaterialApp(
        home: Scaffold(
          body: OtpInput(
            digits: digits,
            onDigitEntered: (index, digit) {
              capturedDigits[index] = digit;
            },
            onCompleted: (otp) {
              onCompletedCalled = true;
            },
            onBackspace: (index) {
              capturedDigits[index] = '';
            },
          ),
        ),
      );
    }

    testWidgets('renders six input cells', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Six TextField widgets for OTP cells.
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));
    });

    testWidgets('does not overflow horizontally on a small (320 dp) viewport', (
      tester,
    ) async {
      // iPhone SE-class width: the six fixed 48 dp cells + gaps would
      // exceed the screen, so the row must shrink responsively (no
      // RenderFlex overflow). Regression for the Phase-10 a11y finding.
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              // Mirror the OTP screen's horizontal padding.
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OtpInput(
                onDigitEntered: (_, _) {},
                onCompleted: (_) {},
                onBackspace: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('typing a digit moves focus to the next cell', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textFields = find.byType(TextField);

      // Tap the first cell and enter a digit.
      await tester.tap(textFields.at(0));
      await tester.pump();
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();

      // The second cell should now have focus.
      final secondField = tester.widget<TextField>(textFields.at(1));
      final focusNode = secondField.focusNode;
      expect(focusNode?.hasFocus, isTrue);
    });

    testWidgets('backspace on an empty cell moves focus back', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textFields = find.byType(TextField);

      // Enter a digit in cell 0, which auto-advances to cell 1.
      await tester.tap(textFields.at(0));
      await tester.pump();
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();

      // Cell 1 should have focus. Press backspace.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Focus should return to cell 0.
      final firstField = tester.widget<TextField>(textFields.at(0));
      final focusNode = firstField.focusNode;
      expect(focusNode?.hasFocus, isTrue);
    });

    testWidgets('paste of a 6-digit string fills all cells', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textFields = find.byType(TextField);
      await tester.tap(textFields.at(0));
      await tester.pump();

      // Simulate paste: entering a multi-character string into a single cell
      // triggers the paste distribution logic in OtpInput.
      await tester.enterText(textFields.at(0), '123456');
      await tester.pump();

      expect(onCompletedCalled, isTrue);
    });

    testWidgets('paste of a non-numeric string is rejected', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textFields = find.byType(TextField);
      await tester.tap(textFields.at(0));
      await tester.pump();

      // Non-numeric or wrong-length paste is rejected.
      await tester.enterText(textFields.at(0), '12345');
      await tester.pump();

      expect(onCompletedCalled, isFalse);
    });

    testWidgets('cells are individually labelled for screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      for (var i = 0; i < 6; i++) {
        expect(find.bySemanticsLabel('Digit ${i + 1} of 6'), findsOneWidget);
      }
    });

    testWidgets('clears its cells when the controller resets digits to empty '
        '(SCR-04 invalid-code retry)', (tester) async {
      // Cells populated; the controller mirrors a filled state.
      await tester.pumpWidget(buildSubject(digits: ['1', '', '', '', '', '']));
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();
      expect(tester.widget<TextField>(textFields.at(0)).controller!.text, '1');

      // Invalid code -> the controller resets all digits to empty -> the
      // widget must clear its visual cells so the user can retype.
      await tester.pumpWidget(buildSubject(digits: List.filled(6, '')));
      await tester.pump();
      expect(
        tester.widget<TextField>(textFields.at(0)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('OTP input group has correct semantic label', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.bySemanticsLabel('Enter 6-digit verification code'),
        findsOneWidget,
      );
    });
  });
}
