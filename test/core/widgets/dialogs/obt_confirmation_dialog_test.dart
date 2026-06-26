// OBTConfirmationDialog widget tests (FR-EX-06 architect §2.5).
//
// Mirrors the OBTAmountInput leaf-widget test precedent from PR #38:
// tests the design-system catalogue contract for confirmation dialogs.
//
// The dialog itself owns no state; cancel / confirm callbacks are
// supplied by the caller. The [OBTConfirmationDialog.show] helper
// wraps showDialog<bool>(...) so call sites can `await` a boolean.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/dialogs/obt_confirmation_dialog.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('OBTConfirmationDialog — rendering', () {
    testWidgets('renders title and body text', (tester) async {
      await tester.pumpWidget(
        _host(
          const OBTConfirmationDialog(
            title: 'Delete expense?',
            body: 'This cannot be undone.',
            confirmLabel: 'Delete',
          ),
        ),
      );

      expect(find.text('Delete expense?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel label defaults to "Cancel" and is overridable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const OBTConfirmationDialog(
            title: 't',
            body: 'b',
            confirmLabel: 'Confirm',
            cancelLabel: 'Keep editing',
          ),
        ),
      );

      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('OBTConfirmationDialog — callbacks', () {
    testWidgets('tapping cancel invokes onCancel', (tester) async {
      var cancelTaps = 0;
      var confirmTaps = 0;
      await tester.pumpWidget(
        _host(
          OBTConfirmationDialog(
            title: 't',
            body: 'b',
            confirmLabel: 'Confirm',
            onCancel: () => cancelTaps++,
            onConfirm: () => confirmTaps++,
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelTaps, 1);
      expect(confirmTaps, 0);
    });

    testWidgets('tapping confirm invokes onConfirm', (tester) async {
      var cancelTaps = 0;
      var confirmTaps = 0;
      await tester.pumpWidget(
        _host(
          OBTConfirmationDialog(
            title: 't',
            body: 'b',
            confirmLabel: 'Confirm',
            onCancel: () => cancelTaps++,
            onConfirm: () => confirmTaps++,
          ),
        ),
      );

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(cancelTaps, 0);
      expect(confirmTaps, 1);
    });
  });

  group('OBTConfirmationDialog — destructive styling', () {
    testWidgets(
      'isDestructive: true flips confirm button background to error colour',
      (tester) async {
        // Pick an error colour that is provably distinct from the
        // light-scheme default so the resolved background uniquely
        // proves the wiring (avoids redundant-argument lint).
        const errorColor = Color(0xFF8B0000);
        final theme = ThemeData.from(
          colorScheme: const ColorScheme.light(error: errorColor),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: OBTConfirmationDialog(
                title: 't',
                body: 'b',
                confirmLabel: 'Delete',
                isDestructive: true,
              ),
            ),
          ),
        );

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Delete'),
        );
        final bg = button.style?.backgroundColor?.resolve(<WidgetState>{});
        expect(
          bg,
          errorColor,
          reason:
              'When destructive, the confirm button background must come '
              'from theme.colorScheme.error.',
        );
      },
    );

    testWidgets(
      'confirm button carries semantic hint "Destructive action." when '
      'destructive',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const OBTConfirmationDialog(
              title: 't',
              body: 'b',
              confirmLabel: 'Delete',
              isDestructive: true,
            ),
          ),
        );

        final semantics = tester.getSemantics(find.text('Delete'));
        expect(
          semantics.hint,
          contains('Destructive action.'),
          reason:
              'SCR-22 §Accessibility requires the destructive confirm '
              'button to advertise its destructive intent.',
        );
      },
    );

    testWidgets('no destructive semantic hint when isDestructive: false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const OBTConfirmationDialog(
            title: 't',
            body: 'b',
            confirmLabel: 'Save',
          ),
        ),
      );

      final semantics = tester.getSemantics(find.text('Save'));
      expect(semantics.hint, isNot(contains('Destructive')));
    });
  });

  group('OBTConfirmationDialog.show — Future<bool> contract', () {
    testWidgets('returns true when the user taps confirm', (tester) async {
      late Future<bool> futureResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    futureResult = OBTConfirmationDialog.show(
                      ctx,
                      title: 'Delete expense?',
                      body: 'This cannot be undone.',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await futureResult, isTrue);
    });

    testWidgets('returns false when the user taps cancel', (tester) async {
      late Future<bool> futureResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    futureResult = OBTConfirmationDialog.show(
                      ctx,
                      title: 't',
                      body: 'b',
                      confirmLabel: 'Confirm',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await futureResult, isFalse);
    });

    testWidgets('returns false when the scrim is tapped (barrier dismiss)', (
      tester,
    ) async {
      late Future<bool> futureResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    futureResult = OBTConfirmationDialog.show(
                      ctx,
                      title: 't',
                      body: 'b',
                      confirmLabel: 'Confirm',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the modal barrier (just above the dialog) to dismiss.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(await futureResult, isFalse);
    });
  });

  group('OBTConfirmationDialog — Haldi token reskin (DC-02)', () {
    testWidgets('dialog shape uses the card radius and the title uses the '
        'Bricolage heading slot', (tester) async {
      await tester.pumpWidget(
        _host(
          const OBTConfirmationDialog(
            title: 't',
            body: 'b',
            confirmLabel: 'OK',
          ),
        ),
      );

      final context = tester.element(find.byType(AlertDialog));
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppTheme.radiusCard));
      expect(dialog.titleTextStyle, Theme.of(context).textTheme.headlineMedium);
    });
  });
}
