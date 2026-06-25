// OBTFloatingActionButton widget tests — the design-system primitive
// for the persistent Add-Expense FAB.
//
// Mirrors the structure of the OBTBottomNav test suite (PR #56) and
// asserts the design contract from
// `docs/design/02-design-system/components.md §3 OBTFloatingActionButton`:
//   - icon `Icons.add`
//   - `backgroundColor: Theme.colorScheme.primary` (Haldi marigold)
//   - `foregroundColor: Theme.colorScheme.onPrimary` (ink, never white)
//   - shape `RoundedRectangleBorder` at radius `AppTheme.radiusPill`
//   - semantic label "Add new expense"
//   - tooltip "Add new expense"
//   - tap target ≥ 56 dp on both axes
//   - default `heroTag` == `'addExpenseFAB'`
//   - constructor override accepts a custom `heroTag`
//
// AC coverage: AC-2 (design contract) and AC-3 (hero-tag default +
// override).

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/nav/obt_floating_action_button.dart';

void main() {
  group('OBTFloatingActionButton — visual contract (AC-2)', () {
    testWidgets('renders Icons.add inside the FAB', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      expect(find.byType(OBTFloatingActionButton), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.icon, Icons.add);
    });

    testWidgets('backgroundColor resolves to Theme.colorScheme.primary', (
      tester,
    ) async {
      const customPrimary = Color(0xFFCAFE00);
      final theme = ThemeData.from(
        colorScheme: const ColorScheme.light(primary: customPrimary),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, customPrimary);
    });

    testWidgets('foregroundColor is Theme.colorScheme.onPrimary (ink), never '
        'white', (tester) async {
      const customOnPrimary = Color(0xFF2A211B); // Haldi ink.
      final theme = ThemeData.from(
        colorScheme: const ColorScheme.light(onPrimary: customOnPrimary),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.foregroundColor, customOnPrimary);
      expect(
        fab.foregroundColor,
        isNot(Colors.white),
        reason:
            'White on marigold measures ~2.5:1 and fails WCAG 2.1 AA; '
            'the glyph must be ink (onPrimary).',
      );
    });

    testWidgets('shape is a RoundedRectangleBorder at the pill radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      final shape = fab.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppTheme.radiusPill));
    });

    testWidgets('semantic label "Add new expense" is exposed on the icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      // The semantic label flows from the Icon(semanticLabel: ...)
      // through Flutter's Semantics tree.
      expect(find.bySemanticsLabel('Add new expense'), findsOneWidget);
    });

    testWidgets('tooltip "Add new expense" is wired on the FAB', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, 'Add new expense');
      expect(find.byTooltip('Add new expense'), findsOneWidget);
    });

    testWidgets('tap target is at least 56 dp on both axes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      final size = tester.getSize(find.byType(OBTFloatingActionButton));
      expect(
        size.width,
        greaterThanOrEqualTo(56.0),
        reason: 'FAB width must be ≥ 56 dp (components.md §3)',
      );
      expect(
        size.height,
        greaterThanOrEqualTo(56.0),
        reason: 'FAB height must be ≥ 56 dp (components.md §3)',
      );
    });
  });

  group('OBTFloatingActionButton — tap handling', () {
    testWidgets('invokes onPressed when tapped', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(
              onPressed: () => callCount += 1,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(OBTFloatingActionButton));
      await tester.pump();

      expect(callCount, 1);
    });
  });

  group('OBTFloatingActionButton — hero tag (AC-3)', () {
    testWidgets('default heroTag is "addExpenseFAB"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(onPressed: () {}),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.heroTag, 'addExpenseFAB');

      // Also assert on the primitive's own property.
      final primitive = tester.widget<OBTFloatingActionButton>(
        find.byType(OBTFloatingActionButton),
      );
      expect(primitive.heroTag, 'addExpenseFAB');
    });

    testWidgets('respects a custom heroTag constructor argument', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: OBTFloatingActionButton(
              heroTag: 'friendDetailFab',
              onPressed: () {},
            ),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.heroTag, 'friendDetailFab');

      final primitive = tester.widget<OBTFloatingActionButton>(
        find.byType(OBTFloatingActionButton),
      );
      expect(primitive.heroTag, 'friendDetailFab');
    });
  });
}
