// OBTSettleUpCard widget tests (FR-SE-07 / FR-SE-09).
//
// Covers both directional variants:
//   - Settling-direction (existing): CTA reads "Settle Up", fires
//     onSettleUp on tap.
//   - Receiving-direction (FR-SE-09): CTA reads "Send Reminder",
//     fires onSendReminder on tap. When nextAllowedAt is in the
//     future, the button is disabled with a cooldown caption.
//
// Written test-first; the receiving-direction parameters will fail
// to compile until the OBTSettleUpCard extension lands.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/friends/presentation/widgets/obt_settle_up_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('OBTSettleUpCard — settling-direction (default)', () {
    testWidgets('renders Settle Up CTA and fires onSettleUp on tap', (
      tester,
    ) async {
      var settleTapped = 0;
      await tester.pumpWidget(
        _wrap(
          OBTSettleUpCard(
            payerDisplayName: 'You',
            payerPhotoUrl: null,
            payeeDisplayName: 'Priya',
            payeePhotoUrl: null,
            suggestedAmountPaise: 50000,
            onSettleUp: () => settleTapped += 1,
          ),
        ),
      );

      expect(find.text('Settle Up'), findsOneWidget);
      expect(find.text('Send Reminder'), findsNothing);
      expect(find.text('\u20B9500.00'), findsOneWidget);

      await tester.tap(find.text('Settle Up'));
      await tester.pump();
      expect(settleTapped, 1);
    });
  });

  group('OBTSettleUpCard — receiving-direction (FR-SE-09)', () {
    testWidgets('renders Send Reminder CTA when isReceivingDirection=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OBTSettleUpCard(
            payerDisplayName: 'Priya',
            payerPhotoUrl: null,
            payeeDisplayName: 'You',
            payeePhotoUrl: null,
            suggestedAmountPaise: 50000,
            onSettleUp: () {},
            isReceivingDirection: true,
            onSendReminder: () {},
          ),
        ),
      );

      expect(find.text('Send Reminder'), findsOneWidget);
      expect(find.text('Settle Up'), findsNothing);
      expect(find.text('\u20B9500.00'), findsOneWidget);
    });

    testWidgets('tapping Send Reminder fires onSendReminder', (tester) async {
      var reminderTapped = 0;
      await tester.pumpWidget(
        _wrap(
          OBTSettleUpCard(
            payerDisplayName: 'Priya',
            payerPhotoUrl: null,
            payeeDisplayName: 'You',
            payeePhotoUrl: null,
            suggestedAmountPaise: 50000,
            onSettleUp: () {},
            isReceivingDirection: true,
            onSendReminder: () => reminderTapped += 1,
          ),
        ),
      );

      await tester.tap(find.text('Send Reminder'));
      await tester.pump();
      expect(reminderTapped, 1);
    });

    testWidgets('button is disabled and shows cooldown caption when '
        'nextAllowedAt is in the future', (tester) async {
      final future = DateTime.now().add(const Duration(hours: 5, minutes: 32));
      var reminderTapped = 0;
      await tester.pumpWidget(
        _wrap(
          OBTSettleUpCard(
            payerDisplayName: 'Priya',
            payerPhotoUrl: null,
            payeeDisplayName: 'You',
            payeePhotoUrl: null,
            suggestedAmountPaise: 50000,
            onSettleUp: () {},
            isReceivingDirection: true,
            onSendReminder: () => reminderTapped += 1,
            nextAllowedAt: future,
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      // Caption with hours + minutes count down.
      final captionFinder = find.textContaining('Next reminder in');
      expect(captionFinder, findsOneWidget);
    });

    testWidgets('button is enabled when nextAllowedAt is in the past', (
      tester,
    ) async {
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      await tester.pumpWidget(
        _wrap(
          OBTSettleUpCard(
            payerDisplayName: 'Priya',
            payerPhotoUrl: null,
            payeeDisplayName: 'You',
            payeePhotoUrl: null,
            suggestedAmountPaise: 50000,
            onSettleUp: () {},
            isReceivingDirection: true,
            onSendReminder: () {},
            nextAllowedAt: past,
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('Next reminder in'), findsNothing);
    });
  });

  group('OBTSettleUpCard — Haldi token reskin (DC-02)', () {
    testWidgets('card uses the card radius, the CTA uses the button radius, '
        'and the amount is Bricolage tabular', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OBTSettleUpCard(
              payerDisplayName: 'You',
              payerPhotoUrl: null,
              payeeDisplayName: 'Priya',
              payeePhotoUrl: null,
              suggestedAmountPaise: 50000,
              onSettleUp: () {},
            ),
          ),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(
        (card.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppTheme.radiusCard),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final shape = button.style?.shape?.resolve(<WidgetState>{});
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppTheme.radiusButton),
      );

      final amount = tester.widget<Text>(find.text('\u20B9500.00'));
      expect(
        amount.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('cooldown caption uses the textTertiary meta colour', (
      tester,
    ) async {
      final future = DateTime.now().add(const Duration(hours: 2));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OBTSettleUpCard(
              payerDisplayName: 'Priya',
              payerPhotoUrl: null,
              payeeDisplayName: 'You',
              payeePhotoUrl: null,
              suggestedAmountPaise: 50000,
              onSettleUp: () {},
              isReceivingDirection: true,
              onSendReminder: () {},
              nextAllowedAt: future,
            ),
          ),
        ),
      );

      final caption = tester.widget<Text>(
        find.textContaining('Next reminder in'),
      );
      expect(caption.style?.color, OBTColors.light.textTertiary);
    });
  });
}
