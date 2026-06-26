import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/sheets/obt_settle_up_sheet.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  OBTSettleUpSheet sheet({
    int suggestedAmountPaise = 50000,
    bool isLoading = false,
    bool isSaving = false,
    bool isSuccess = false,
    String? amountErrorText,
    ValueChanged<int>? onAmountChanged,
    VoidCallback? onRecord,
  }) {
    return OBTSettleUpSheet(
      payerDisplayName: 'You',
      payeeDisplayName: 'Priya',
      suggestedAmountPaise: suggestedAmountPaise,
      onAmountChanged: onAmountChanged ?? (_) {},
      onRecord: onRecord ?? () {},
      isLoading: isLoading,
      isSaving: isSaving,
      isSuccess: isSuccess,
      amountErrorText: amountErrorText,
    );
  }

  group('OBTSettleUpSheet — single suggested payment (Invariant 2)', () {
    testWidgets(
      'shows exactly ONE pre-filled suggested payment, never a debt graph',
      (tester) async {
        await pumpThemed(tester, sheet(), wrapInScaffold: false);

        // One directed payment header: "You pay Priya" + one focal amount.
        expect(find.text('You pay Priya'), findsOneWidget);
        expect(find.text('₹500.00'), findsOneWidget);
        // One record action — not a who-owes-who list of transfers.
        expect(
          find.widgetWithText(FilledButton, 'Record payment'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the focal amount uses the amountHero (48px) slot (#128 B)', (
      tester,
    ) async {
      await pumpThemed(tester, sheet(), wrapInScaffold: false);
      final amount = tester.widget<Text>(find.text('₹500.00'));
      expect(amount.style!.fontSize, 48);
    });

    testWidgets('settled (zero) guard shows "Settled up", no editable amount', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        sheet(suggestedAmountPaise: 0),
        wrapInScaffold: false,
      );

      expect(find.text('Settled up'), findsOneWidget);
      expect(find.text('Nothing to pay Priya.'), findsOneWidget);
      // No editable amount field, no record action when settled.
      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Record payment'), findsNothing);
    });
  });

  group('OBTSettleUpSheet — inert "Pay via UPI" slot (foundation §5)', () {
    testWidgets('is present, "Coming soon", and announced disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, sheet(), wrapInScaffold: false);

      expect(find.text('Pay via UPI'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);

      // The inert slot is announced disabled (has enabled state, not
      // enabled) — isSemantics is the current lenient matcher.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Pay via UPI. Coming soon.')),
        isSemantics(hasEnabledState: true, isEnabled: false),
        reason: 'the UPI slot is inert — announced disabled, not wired',
      );
      handle.dispose();
    });
  });

  group('OBTSettleUpSheet — record + success', () {
    testWidgets('Record fires onRecord; the CTA is ink on marigold', (
      tester,
    ) async {
      var recorded = 0;
      await pumpThemed(
        tester,
        sheet(onRecord: () => recorded++),
        wrapInScaffold: false,
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final fg = button.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(fg, AppTheme.light.colorScheme.onPrimary);
      expect(fg, isNot(Colors.white));

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pump();
      expect(recorded, 1);
    });

    testWidgets('the success moment fires a single HapticFeedback pulse', (
      tester,
    ) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpThemed(tester, sheet(isSuccess: true), wrapInScaffold: false);

      expect(find.text('Payment recorded'), findsOneWidget);
      expect(
        calls.where((m) => m == 'HapticFeedback.vibrate').length,
        1,
        reason: 'the success check fires exactly one haptic pulse',
      );
    });
  });

  group('OBTSettleUpSheet — four states', () {
    testWidgets('loading shows a shimmer skeleton (reduced motion)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        sheet(isLoading: true),
        wrapInScaffold: false,
        disableAnimations: true,
      );
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    });

    testWidgets('error surfaces the inline amount error', (tester) async {
      await pumpThemed(
        tester,
        sheet(amountErrorText: 'Enter an amount above zero'),
        wrapInScaffold: false,
      );
      expect(find.text('Enter an amount above zero'), findsOneWidget);
    });

    testWidgets('every interactive control is labelled (QA B.4)', (
      tester,
    ) async {
      await pumpThemed(tester, sheet(), wrapInScaffold: false);
      await expectAllInteractiveNodesLabelled(tester);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpThemed(
        tester,
        sheet(),
        wrapInScaffold: false,
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
