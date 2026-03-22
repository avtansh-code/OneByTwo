import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_by_two/core/l10n/generated/app_localizations.dart';
import 'package:one_by_two/presentation/features/auth/screens/welcome_screen.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  /// Wraps [WelcomeScreen] with GoRouter, Riverpod, and l10n so that
  /// all runtime dependencies are satisfied without touching Firebase.
  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, __) => const WelcomeScreen()),
        // Navigation target for the "Get Started" button.
        GoRoute(
          path: '/phone',
          name: 'phone-input',
          builder: (_, __) => const Scaffold(body: Text('Phone Input')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('WelcomeScreen', () {
    group('rendering', () {
      testWidgets('should display app title from l10n', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('One By Two'), findsOneWidget);
      });

      testWidgets('should display subtitle from l10n', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Split expenses the easy way'), findsOneWidget);
      });

      testWidgets('should display Get Started button with l10n text', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert
        expect(
          find.widgetWithText(FilledButton, 'Get Started'),
          findsOneWidget,
        );
      });

      testWidgets('should display receipt icon', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
      });

      testWidgets('should wrap body content in SafeArea', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('should use Scaffold as the root layout', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should have full-width Get Started button', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Assert — the FilledButton is inside a SizedBox with infinite width
        final sizedBoxFinder = find.ancestor(
          of: find.widgetWithText(FilledButton, 'Get Started'),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == double.infinity,
          ),
        );
        expect(sizedBoxFinder, findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets(
        'should navigate to phone input screen when Get Started is tapped',
        (tester) async {
          // Arrange
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          // Act
          await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
          await tester.pumpAndSettle();

          // Assert — navigated to the placeholder phone input route
          expect(find.text('Phone Input'), findsOneWidget);
        },
      );
    });
  });
}
