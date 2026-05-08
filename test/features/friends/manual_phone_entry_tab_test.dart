// Widget tests for ManualPhoneEntryTab.
//
// Exercises the manual phone entry form that will appear in the
// "Enter Number" tab of the refactored AddFriendScreen. The widget
// under test is expected to live at:
//   lib/features/friends/presentation/widgets/manual_phone_entry_tab.dart
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';
import 'package:onebytwo/features/friends/presentation/widgets/manual_phone_entry_tab.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged during the test.
  final List<String> loggedEvents = [];

  /// Parameters logged alongside each event.
  final List<Map<String, Object>?> loggedParams = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
    loggedParams.add(parameters);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Captures the [SelectedContact] passed by the widget's onSubmit callback.
class SubmitCapture {
  /// The last contact received via [call].
  SelectedContact? lastContact;

  /// Number of times [call] has been invoked.
  int callCount = 0;

  /// The callback to pass into the widget.
  void call(SelectedContact contact) {
    lastContact = contact;
    callCount++;
  }
}

/// Builds the [ManualPhoneEntryTab] wrapped in the minimal widget tree
/// required for testing.
Widget _buildSubject({
  required SubmitCapture submitCapture,
  required FakeAnalyticsService fakeAnalytics,
  String? currentUserPhone,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(fakeAnalytics),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ManualPhoneEntryTab(
          onSubmit: submitCapture.call,
          analyticsService: fakeAnalytics,
          currentUserPhone: currentUserPhone,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late SubmitCapture submitCapture;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    submitCapture = SubmitCapture();
  });

  group('ManualPhoneEntryTab', () {
    testWidgets('renders locked +91 prefix', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      expect(find.text('+91'), findsOneWidget);
    });

    testWidgets('renders phone number input field', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      // The text field should use a phone keyboard type.
      final textFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.phone,
      );
      expect(textFieldFinder, findsOneWidget);
    });

    testWidgets('renders Add Friend button', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      expect(find.text('Add Friend'), findsOneWidget);
    });

    testWidgets('Add Friend button is disabled when input is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      // Find the button and verify it is disabled (onPressed is null).
      final buttonFinder = find.widgetWithText(FilledButton, 'Add Friend');
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('Add Friend button is disabled with fewer than 10 digits', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      // Enter fewer than 10 digits.
      final phoneField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.phone,
      );
      await tester.enterText(phoneField, '98765');
      await tester.pump();

      final buttonFinder = find.widgetWithText(FilledButton, 'Add Friend');
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('Add Friend button is enabled with valid 10-digit input', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      final phoneField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.phone,
      );
      await tester.enterText(phoneField, '9876543210');
      await tester.pump();

      final buttonFinder = find.widgetWithText(FilledButton, 'Add Friend');
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
      'tapping Add Friend with valid input calls onSubmit with '
      'E.164 SelectedContact',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            submitCapture: submitCapture,
            fakeAnalytics: fakeAnalytics,
          ),
        );

        final phoneField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.keyboardType == TextInputType.phone,
        );
        await tester.enterText(phoneField, '9876543210');
        await tester.pump();

        await tester.tap(find.text('Add Friend'));
        await tester.pump();

        expect(submitCapture.callCount, 1);
        expect(
          submitCapture.lastContact,
          const SelectedContact(
            displayName: '+919876543210',
            phoneNumbers: ['+919876543210'],
          ),
        );
      },
    );

    testWidgets('validation error shown for invalid start digit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      final phoneField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.phone,
      );
      await tester.enterText(phoneField, '1234567890');
      await tester.pump();

      // Attempt to submit — should show validation error.
      await tester.tap(find.text('Add Friend'));
      await tester.pump();

      // The validator error message from validateIndianMobile.
      expect(
        find.text('Please enter a valid 10-digit mobile number.'),
        findsOneWidget,
      );
      // The callback should not have been invoked.
      expect(submitCapture.callCount, 0);
    });

    testWidgets(
      'fires friend_manual_entry_submitted telemetry on valid submit',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            submitCapture: submitCapture,
            fakeAnalytics: fakeAnalytics,
          ),
        );

        final phoneField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.keyboardType == TextInputType.phone,
        );
        await tester.enterText(phoneField, '9876543210');
        await tester.pump();

        await tester.tap(find.text('Add Friend'));
        await tester.pump();

        expect(
          fakeAnalytics.loggedEvents,
          contains('friend_manual_entry_submitted'),
        );
      },
    );

    testWidgets(
      'fires friend_manual_entry_validation_failed telemetry on '
      'invalid submit',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            submitCapture: submitCapture,
            fakeAnalytics: fakeAnalytics,
          ),
        );

        final phoneField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.keyboardType == TextInputType.phone,
        );
        await tester.enterText(phoneField, '1234567890');
        await tester.pump();

        await tester.tap(find.text('Add Friend'));
        await tester.pump();

        expect(
          fakeAnalytics.loggedEvents,
          contains('friend_manual_entry_validation_failed'),
        );

        // Verify error_code parameter is present.
        final eventIndex = fakeAnalytics.loggedEvents.indexOf(
          'friend_manual_entry_validation_failed',
        );
        expect(eventIndex, isNot(-1));
        final params = fakeAnalytics.loggedParams[eventIndex];
        expect(params, isNotNull);
        expect(params, containsPair('error_code', isA<String>()));
      },
    );

    testWidgets('renders helper text', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      expect(
        find.text('Enter a 10-digit Indian mobile number.'),
        findsOneWidget,
      );
    });

    testWidgets('no PII in any telemetry event parameter', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          submitCapture: submitCapture,
          fakeAnalytics: fakeAnalytics,
        ),
      );

      final phoneField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.phone,
      );

      // Submit a valid number.
      await tester.enterText(phoneField, '9876543210');
      await tester.pump();
      await tester.tap(find.text('Add Friend'));
      await tester.pump();

      // Also trigger a validation failure.
      await tester.enterText(phoneField, '1234567890');
      await tester.pump();
      await tester.tap(find.text('Add Friend'));
      await tester.pump();

      // PII strings that must never appear in telemetry.
      const piiStrings = [
        '9876543210',
        '+919876543210',
        '1234567890',
        '+911234567890',
      ];

      for (final params in fakeAnalytics.loggedParams) {
        if (params == null) continue;
        for (final value in params.values) {
          for (final pii in piiStrings) {
            expect(
              value.toString().contains(pii),
              isFalse,
              reason:
                  'Telemetry parameter value "$value" must '
                  'not contain PII: $pii',
            );
          }
        }
        for (final key in params.keys) {
          for (final pii in piiStrings) {
            expect(
              key.contains(pii),
              isFalse,
              reason:
                  'Telemetry parameter key "$key" must '
                  'not contain PII: $pii',
            );
          }
        }
      }

      for (final eventName in fakeAnalytics.loggedEvents) {
        for (final pii in piiStrings) {
          expect(
            eventName.contains(pii),
            isFalse,
            reason:
                'Telemetry event name "$eventName" must '
                'not contain PII: $pii',
          );
        }
      }
    });
  });
}
