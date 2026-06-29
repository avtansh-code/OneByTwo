import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/widgets/inputs/obt_locked_phone_field.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  group('OBTLockedPhoneField', () {
    testWidgets('renders +91 and an editable field as one bordered control', (
      tester,
    ) async {
      await tester.pumpWidget(host(const OBTLockedPhoneField()));
      expect(find.text('+91'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // The inner TextField carries no border of its own: a single outer
      // frame wraps both halves so their edges stay aligned (#150).
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.decoration!.border, InputBorder.none);
      expect(tf.decoration!.enabledBorder, InputBorder.none);
      expect(tf.decoration!.focusedBorder, InputBorder.none);
    });

    testWidgets('the +91 chip and the input share top and bottom edges', (
      tester,
    ) async {
      await tester.pumpWidget(host(const OBTLockedPhoneField()));
      final prefixRect = tester.getRect(
        find.ancestor(of: find.text('+91'), matching: find.byType(Container)),
      );
      final fieldRect = tester.getRect(find.byType(TextField));
      expect(prefixRect.top, moreOrLessEquals(fieldRect.top, epsilon: 0.5));
      expect(
        prefixRect.bottom,
        moreOrLessEquals(fieldRect.bottom, epsilon: 0.5),
      );
    });

    testWidgets('applies the Indian formatter plus caller formatters', (
      tester,
    ) async {
      final controller = TextEditingController();
      String? last;
      await tester.pumpWidget(
        host(
          OBTLockedPhoneField(
            controller: controller,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => last = value,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '98abc7654321099');
      final digits = controller.text.replaceAll(RegExp(r'\D'), '');
      expect(digits.length, lessThanOrEqualTo(10));
      expect(last, isNotNull);
      controller.dispose();
    });

    testWidgets('hasError tints the outer frame with the error colour', (
      tester,
    ) async {
      await tester.pumpWidget(host(const OBTLockedPhoneField(hasError: true)));
      final context = tester.element(find.byType(OBTLockedPhoneField));
      final errorColor = Theme.of(context).colorScheme.error;
      final borders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((b) => b.border is Border)
          .map((b) => (b.border! as Border).top.color);
      expect(borders, contains(errorColor));
    });
  });
}
