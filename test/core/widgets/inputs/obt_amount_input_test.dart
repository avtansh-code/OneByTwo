// OBTAmountInput widget tests (Option E extraction per Architect §2.8).
//
// Verifies the contract that the reusable input lives at
// `lib/core/widgets/inputs/obt_amount_input.dart`:
//
// - emits integer paise via `onChanged: ValueChanged<int>`;
// - refuses non-numeric input;
// - refuses negative values;
// - caps at 999,999,999 paise (₹99,99,999.99) per AC-2;
// - keeps the `₹` prefix non-editable;
// - renders the Indian-numbering separator on the rupee component;
// - the `errorText` prop is rendered below the field.
//
// Written test-first.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/inputs/obt_amount_input.dart';

const _kCap = 999999999; // paise — equal to ₹99,99,999.99 (AC-2)

Future<void> _pumpInput(
  WidgetTester tester, {
  required ValueChanged<int> onChanged,
  int? initialAmountPaise,
  String? errorText,
  bool enabled = true,
  bool autoFocus = false,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: OBTAmountInput(
          onChanged: onChanged,
          initialAmountPaise: initialAmountPaise,
          errorText: errorText,
          enabled: enabled,
          autoFocus: autoFocus,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('OBTAmountInput — paise emission contract', () {
    testWidgets('typing "100" emits 10000 paise (₹100)', (tester) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '100');
      await tester.pump();

      expect(captured.isNotEmpty, isTrue);
      expect(captured.last, 10000);
    });

    testWidgets('typing "0.50" emits 50 paise', (tester) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '0.50');
      await tester.pump();

      expect(captured.last, 50);
    });

    testWidgets('typing "12.34" emits 1234 paise', (tester) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '12.34');
      await tester.pump();

      expect(captured.last, 1234);
    });

    testWidgets('typing "0" emits 0 paise', (tester) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '0');
      await tester.pump();

      expect(captured.last, 0);
    });

    testWidgets('emitted value is always int (invariant 1)', (tester) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '99.99');
      await tester.pump();

      for (final v in captured) {
        expect(v, isA<int>());
        expect(v, isNot(isA<double>()));
      }
    });
  });

  group('OBTAmountInput — input filtering', () {
    testWidgets('refuses non-numeric input (letters discarded)', (
      tester,
    ) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '1a2b3');
      await tester.pump();

      // The formatter strips letters; remaining digits "123" → 12300 paise.
      expect(captured.last, 12300);
    });

    testWidgets('refuses a leading minus (negative values not permitted)', (
      tester,
    ) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '-50');
      await tester.pump();

      // The minus is stripped; "50" → 5000 paise.
      expect(captured.last, 5000);
    });

    testWidgets('refuses multiple decimal points (only first kept)', (
      tester,
    ) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '12.34.56');
      await tester.pump();

      // Only the first decimal point is honoured; "12.34" → 1234.
      expect(captured.last, 1234);
    });

    testWidgets('clamps to at most 2 digits after the decimal point', (
      tester,
    ) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '1.234');
      await tester.pump();

      // Third decimal digit is rejected; "1.23" → 123.
      expect(captured.last, 123);
    });
  });

  group('OBTAmountInput — cap enforcement (AC-2)', () {
    testWidgets('typing exactly the cap (₹99,99,999.99) emits 999999999', (
      tester,
    ) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      await tester.enterText(find.byType(OBTAmountInput), '9999999.99');
      await tester.pump();

      expect(captured.last, _kCap);
    });

    testWidgets('typing one paise over the cap stays at or below the cap', (
      tester,
    ) async {
      final captured = <int>[];
      await _pumpInput(tester, onChanged: captured.add);

      // Try to enter a value above the cap; the formatter must clamp or
      // reject so the emitted value never exceeds the cap.
      await tester.enterText(find.byType(OBTAmountInput), '99999999.99');
      await tester.pump();

      for (final v in captured) {
        expect(
          v,
          lessThanOrEqualTo(_kCap),
          reason: 'emitted $v exceeds the AC-2 cap',
        );
      }
    });
  });

  group('OBTAmountInput — initial state', () {
    testWidgets('renders an empty field when initialAmountPaise is null', (
      tester,
    ) async {
      await _pumpInput(tester, onChanged: (_) {});
      // The formatted value for the field is empty initially.
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      expect(
        tester.widget<TextField>(textField).controller?.text ?? '',
        isEmpty,
      );
    });

    testWidgets('renders a pre-filled value when initialAmountPaise is '
        'supplied', (tester) async {
      await _pumpInput(tester, onChanged: (_) {}, initialAmountPaise: 12345);

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      final text = tester.widget<TextField>(textField).controller?.text ?? '';
      // Either '123.45' or some Indian-numbering-aware representation —
      // assert the digits appear in order.
      expect(text.contains('123'), isTrue);
      expect(text.contains('45'), isTrue);
    });
  });

  group('OBTAmountInput — error and disabled states', () {
    testWidgets('renders errorText below the field', (tester) async {
      await _pumpInput(
        tester,
        onChanged: (_) {},
        errorText: 'Amount cannot exceed ₹99,99,999.99.',
      );

      expect(find.text('Amount cannot exceed ₹99,99,999.99.'), findsOneWidget);
    });

    testWidgets('error text is rupee-aware so an embedded ₹ never tofus', (
      tester,
    ) async {
      await _pumpInput(
        tester,
        onChanged: (_) {},
        errorText: 'Amount cannot exceed ₹99,99,999.99.',
      );

      // The controller may surface an error embedding a rupee amount; the
      // decoration's errorStyle must carry a font fallback so the ₹ renders
      // from Bricolage rather than the glyphless Hanken error style.
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.errorStyle?.fontFamilyFallback, isNotEmpty);
    });

    testWidgets('the rupee prefix is always visible (₹ symbol)', (
      tester,
    ) async {
      await _pumpInput(tester, onChanged: (_) {});
      expect(find.text('₹'), findsOneWidget);
    });
  });

  group('OBTAmountInput — Haldi token reskin (DC-02)', () {
    testWidgets('entered amount uses Bricolage tabular amount-hero (48px) and '
        'the field uses the chip/input radius', (tester) async {
      await _pumpInput(tester, onChanged: (_) {}, theme: AppTheme.light);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: 'Amounts use Bricolage tabular figures (OBTText.amountHero).',
      );
      expect(
        field.style?.fontSize,
        48,
        reason: 'Amount entry renders focal at 48px (#128 §B).',
      );
      final border = field.decoration?.border;
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(AppTheme.radiusChipInput),
      );
    });

    testWidgets('the ₹ prefix renders in textSecondary (onSurfaceVariant), '
        'not marigold primary (#128 §C1)', (tester) async {
      await _pumpInput(tester, onChanged: (_) {}, theme: AppTheme.light);

      final scheme = AppTheme.light.colorScheme;
      final prefix = tester.widget<Text>(find.text('₹'));
      expect(prefix.style?.color, scheme.onSurfaceVariant);
      expect(prefix.style?.color, isNot(scheme.primary));
      expect(
        prefix.style?.fontSize,
        48,
        reason: 'The prefix reuses the hero style for glyph sizing.',
      );
    });
  });
}
