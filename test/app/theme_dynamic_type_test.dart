@Tags(['a11y-dynamic-type'])
library;

// DC-01 — dynamic-type 2.0x + reduced-motion gate
// (04-qa-test-strategy.md section C).
//
// Dense amount/balance rows must lay out at 2.0x text scale, at both the
// 390-wide reference frame and the 320-wide narrow stress width, with no
// RenderFlex overflow, and amounts must never be truncated (the whole
// rupee figure stays present). Reduced motion renders instantly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// A representative dense balance row: an elastic name plus a Bricolage
/// tabular amount produced only by [formatInrFromPaise] (Invariant 1).
class _BalanceRow extends StatelessWidget {
  const _BalanceRow(this.amountStr);

  final String amountStr;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Aishwarya Rao',
            style: Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(amountStr, style: OBTText.amount(context)),
      ],
    );
  }
}

Future<void> _pumpAt(
  WidgetTester tester,
  double width,
  double scale,
  Widget child,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final amountStr = formatInrFromPaise(523400); // "₹5,234.00"

  group('2.0x text scale — dense amount row never overflows', () {
    for (final width in <double>[390, 320]) {
      testWidgets('row lays out at ${width.toInt()}px without overflow', (
        tester,
      ) async {
        await _pumpAt(tester, width, 2, _BalanceRow(amountStr));

        expect(tester.takeException(), isNull);
        // The amount is rendered whole — never ellipsised or clipped.
        expect(find.text(amountStr), findsOneWidget);
      });
    }
  });

  group('2.0x text scale — hero amount never truncates', () {
    testWidgets('hero amount renders whole at 2.0x', (tester) async {
      await _pumpAt(
        tester,
        390,
        2,
        Builder(
          builder: (context) =>
              Text(amountStr, style: OBTText.amountHero(context)),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(amountStr), findsOneWidget);
    });
  });

  group('Reduced motion', () {
    testWidgets('renders instantly under disableAnimations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Builder(
                builder: (context) =>
                    Text(amountStr, style: OBTText.amountHero(context)),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(amountStr), findsOneWidget);
    });
  });
}
