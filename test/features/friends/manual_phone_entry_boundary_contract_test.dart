// Boundary-contract test for manual phone entry to controller hand-off.
//
// Verifies that the SelectedContact created by ManualPhoneEntryTab at
// the submit boundary has the correct E.164 format, structure, and
// shape expected by MatchAndInviteController.performLookup.
//
// This is the most critical test file for the manual entry path. It
// guards against the class of bug identified in PR #29 (OTP resend)
// where state-transition tests passed but the wrong value crossed a
// boundary.
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
// Fakes and spies
// ---------------------------------------------------------------------------

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged during the test.
  final List<String> loggedEvents = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
  }
}

/// Spy that captures the [SelectedContact] delivered by the widget's
/// onSubmit callback. Used to inspect the value at the boundary.
class SubmitSpy {
  /// The last contact received via [call].
  SelectedContact? lastContact;

  /// The callback to pass into the widget.
  void call(SelectedContact contact) {
    lastContact = contact;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the [ManualPhoneEntryTab] with a spy and fake analytics,
/// wrapped in the minimal widget tree required for widget testing.
Widget _buildSubject({
  required SubmitSpy spy,
  required FakeAnalyticsService fakeAnalytics,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(fakeAnalytics),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ManualPhoneEntryTab(
          onSubmit: spy.call,
          analyticsService: fakeAnalytics,
        ),
      ),
    ),
  );
}

/// Enters a phone number into the text field and taps the Add Friend
/// button, pumping the widget tree between steps.
Future<void> _enterAndSubmit(WidgetTester tester, String digits) async {
  final phoneField = find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.keyboardType == TextInputType.phone,
  );
  await tester.enterText(phoneField, digits);
  await tester.pump();

  await tester.tap(find.text('Add Friend'));
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late SubmitSpy spy;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    spy = SubmitSpy();
  });

  group('manual entry -> controller boundary contract', () {
    testWidgets(
      'submit delivers +91XXXXXXXXXX format, never raw 10-digit',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(spy: spy, fakeAnalytics: fakeAnalytics),
        );

        await _enterAndSubmit(tester, '9876543210');

        expect(spy.lastContact, isNotNull);
        expect(
          spy.lastContact!.phoneNumbers.first,
          equals('+919876543210'),
          reason:
              'The phone number at the boundary must be E.164 '
              'format (+91 prefix), not raw 10-digit.',
        );
      },
    );

    testWidgets('submit never doubles the +91 prefix', (tester) async {
      await tester.pumpWidget(
        _buildSubject(spy: spy, fakeAnalytics: fakeAnalytics),
      );

      await _enterAndSubmit(tester, '9876543210');

      expect(spy.lastContact, isNotNull);
      expect(
        spy.lastContact!.phoneNumbers.first.startsWith('+91+91'),
        isFalse,
        reason: 'E.164 number must not have a doubled +91 prefix.',
      );
    });

    testWidgets(
      'submit strips whitespace from phone number before normalisation',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(spy: spy, fakeAnalytics: fakeAnalytics),
        );

        // The IndianPhoneInputFormatter should strip whitespace on
        // input, but this test verifies the final boundary value.
        await _enterAndSubmit(tester, '9876543210');

        expect(spy.lastContact, isNotNull);
        expect(
          spy.lastContact!.phoneNumbers.first.contains(' '),
          isFalse,
          reason:
              'E.164 number at the boundary must contain no whitespace.',
        );
      },
    );

    testWidgets(
      'displayName matches the E.164 normalised number',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(spy: spy, fakeAnalytics: fakeAnalytics),
        );

        await _enterAndSubmit(tester, '9876543210');

        expect(spy.lastContact, isNotNull);
        expect(
          spy.lastContact!.displayName,
          equals('+919876543210'),
          reason:
              'For manual entry without a contact name, the '
              'displayName must equal the E.164 number.',
        );
      },
    );

    testWidgets('phoneNumbers list contains exactly one entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(spy: spy, fakeAnalytics: fakeAnalytics),
      );

      await _enterAndSubmit(tester, '9876543210');

      expect(spy.lastContact, isNotNull);
      expect(
        spy.lastContact!.phoneNumbers,
        hasLength(1),
        reason:
            'Manual entry provides exactly one phone number; the '
            'list must contain a single entry.',
      );
    });
  });
}
