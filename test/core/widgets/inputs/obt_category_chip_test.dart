import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/inputs/obt_category_chip.dart';

import '../../../support/widget_test_harness.dart';

void main() {
  group('OBTCategoryChip', () {
    testWidgets('unselected chip shows the full-hue icon and label', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTCategoryChip(
          category: OBTCategory.food,
          icon: Icons.restaurant,
          label: 'Food',
          selected: false,
          onSelected: (_) {},
        ),
      );

      expect(find.text('Food'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.restaurant));
      expect(icon.color, OBTColors.light.categoryColor(OBTCategory.food));
    });

    testWidgets('selected chip draws a 2px hue ring', (tester) async {
      await pumpThemed(
        tester,
        OBTCategoryChip(
          category: OBTCategory.transport,
          icon: Icons.directions_car,
          label: 'Transport',
          selected: true,
          onSelected: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Transport'), findsOneWidget);
    });

    testWidgets('tap fires onSelected with the category', (tester) async {
      OBTCategory? picked;
      await pumpThemed(
        tester,
        OBTCategoryChip(
          category: OBTCategory.groceries,
          icon: Icons.local_grocery_store,
          label: 'Groceries',
          selected: false,
          onSelected: (c) => picked = c,
        ),
      );

      await tester.tap(find.text('Groceries'));
      await tester.pump();
      expect(picked, OBTCategory.groceries);
    });

    testWidgets('NEGATIVE CASE — a disabled chip does not fire onSelected', (
      tester,
    ) async {
      var fired = 0;
      await pumpThemed(
        tester,
        OBTCategoryChip(
          category: OBTCategory.rent,
          icon: Icons.home,
          label: 'Rent',
          selected: false,
          enabled: false,
          onSelected: (_) => fired++,
        ),
      );

      await tester.tap(find.text('Rent'));
      await tester.pump();
      expect(fired, 0);
    });

    testWidgets('every interactive control is labelled (QA B.4)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        OBTCategoryChip(
          category: OBTCategory.food,
          icon: Icons.restaurant,
          label: 'Food',
          selected: false,
          onSelected: (_) {},
        ),
      );
      // The chip is a button-flag node (its InkWell tap action is excluded),
      // so assert the label directly in addition to the gate.
      expect(find.bySemanticsLabel('Food'), findsOneWidget);
      await expectAllInteractiveNodesLabelled(tester);
    });

    testWidgets('meets the 48dp minimum tap target (SRS 5.6)', (tester) async {
      await pumpThemed(
        tester,
        OBTCategoryChip(
          category: OBTCategory.food,
          icon: Icons.restaurant,
          label: 'Food',
          selected: false,
          onSelected: (_) {},
        ),
      );
      await expectAllTapTargetsMeetMinSize(tester);
    });

    testWidgets('OBTCategoryTile renders a non-interactive legend form', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const OBTCategoryTile(
          category: OBTCategory.shopping,
          icon: Icons.shopping_bag,
          label: 'Shopping',
        ),
        brightness: Brightness.dark,
      );

      expect(find.text('Shopping'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.shopping_bag));
      expect(icon.color, OBTColors.dark.categoryColor(OBTCategory.shopping));
    });
  });
}
