import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  final List<String> loggedEvents = [];

  @override
  Future<void> logEvent({required String name}) async {
    loggedEvents.add(name);
  }
}

void main() {
  late FakeAnalyticsService fakeAnalytics;

  Widget buildSubject() {
    return ProviderScope(
      overrides: [analyticsServiceProvider.overrideWithValue(fakeAnalytics)],
      child: const MaterialApp(home: PhoneEntryScreen()),
    );
  }

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
  });

  group('PhoneEntryScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(PhoneEntryScreen), findsOneWidget);
    });

    testWidgets('+91 prefix is visible and not editable', (tester) async {
      await tester.pumpWidget(buildSubject());

      // The prefix text is present.
      expect(find.text('+91'), findsOneWidget);

      // The prefix is NOT inside a TextField — it is a separate widget.
      final prefixFinder = find.text('+91');
      final prefixWidget = tester.widget<Text>(prefixFinder);
      expect(prefixWidget, isA<Text>());

      // Verify no EditableText ancestor for the prefix.
      final prefixElement = tester.element(prefixFinder);
      var hasEditableAncestor = false;
      prefixElement.visitAncestorElements((element) {
        if (element.widget is EditableText) {
          hasEditableAncestor = true;
          return false;
        }
        return true;
      });
      expect(hasEditableAncestor, isFalse);
    });

    testWidgets('Continue button is disabled when input is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Continue button is disabled when input is 9 digits', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '987654321');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Continue button enables when input is 10 valid digits '
        '(starting with 6-9)', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping Continue with invalid prefix (starts with 5) '
        'shows error message', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '5678901234');
      await tester.pump();

      // Button should be enabled (10 digits entered).
      final button = find.widgetWithText(FilledButton, 'Continue');
      await tester.tap(button);
      await tester.pump();

      expect(
        find.text('Please enter a valid 10-digit mobile number.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'telemetry signup_started fires on Continue tap with valid input',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextField), '9876543210');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pump();

        expect(fakeAnalytics.loggedEvents, contains('signup_started'));
      },
    );

    testWidgets('error message is hidden by default', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text('Please enter a valid 10-digit mobile number.'),
        findsNothing,
      );
    });

    testWidgets('heading and subtitle text are displayed', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Enter your mobile number'), findsOneWidget);
      expect(
        find.text("We'll send you a 6-digit code to verify."),
        findsOneWidget,
      );
    });

    testWidgets('prefix has correct semantic label', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.bySemanticsLabel('Country code, India, plus 91'),
        findsOneWidget,
      );
    });
  });
}
