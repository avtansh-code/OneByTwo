// ChangedFieldIndicator widget tests (FR-EX-06 AC-4).
//
// Covers SCR-22 §Edit Flow line 449 (secondary left-border on changed
// fields) AND §Accessibility line 509 (`, changed.` semantic suffix —
// WCAG 1.4.1 information not conveyed by colour alone).

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/expenses/presentation/widgets/changed_field_indicator.dart';

void main() {
  group('ChangedFieldIndicator', () {
    testWidgets(
      'returns the child unchanged when isChanged is false (zero overhead)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ChangedFieldIndicator(
                isChanged: false,
                child: Text('field'),
              ),
            ),
          ),
        );
        expect(
          find.descendant(
            of: find.byType(ChangedFieldIndicator),
            matching: find.byType(Container),
          ),
          findsNothing,
        );
        expect(find.text('field'), findsOneWidget);
      },
    );

    testWidgets('wraps the child with a secondary-coloured left border '
        'when isChanged is true', (tester) async {
      const seedColor = Color(0xFFF4A261);
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          secondary: seedColor,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ChangedFieldIndicator(isChanged: true, child: Text('field')),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(ChangedFieldIndicator),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.left.width, 2);
      expect(border.left.color, theme.colorScheme.secondary);
    });

    testWidgets(
      'announces the ", changed." semantic suffix when isChanged is true '
      '(WCAG 1.4.1 — info not conveyed by colour alone)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ChangedFieldIndicator(
                isChanged: true,
                child: Text('Amount'),
              ),
            ),
          ),
        );

        final semanticsFinder = find.descendant(
          of: find.byType(ChangedFieldIndicator),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').contains('changed'),
          ),
        );
        expect(
          semanticsFinder,
          findsOneWidget,
          reason:
              'Expected a Semantics descendant of ChangedFieldIndicator to '
              'carry the ", changed." label per AC-4 / SCR-22 §Accessibility.',
        );
      },
    );
  });
}
