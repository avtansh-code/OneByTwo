import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/presentation/otp_entry_screen.dart';

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged as `(name, parameters)` tuples.
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }
}

void main() {
  late FakeAnalyticsService fakeAnalytics;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
  });

  Widget buildSubject({String phoneNumber = '9876543210'}) {
    return ProviderScope(
      overrides: [analyticsServiceProvider.overrideWithValue(fakeAnalytics)],
      child: MaterialApp(home: OtpEntryScreen(phoneNumber: phoneNumber)),
    );
  }

  group('OtpEntryScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(OtpEntryScreen), findsOneWidget);
    });

    testWidgets('renders heading "Verify your number"', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Verify your number'), findsOneWidget);
    });

    testWidgets('renders the 30-second countdown initially', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('0:30'), findsOneWidget);
    });

    testWidgets('phone number in subtitle is masked (last 4 digits visible)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      // Should show +91 XXXXXX3210, NOT +91 9876543210.
      expect(find.textContaining('XXXXXX3210'), findsOneWidget);
      expect(find.textContaining('9876543210'), findsNothing);
    });

    testWidgets('Resend OTP link is disabled during countdown', (tester) async {
      await tester.pumpWidget(buildSubject());
      // Find the resend text/button and verify it is disabled.
      final resendFinder = find.text('Resend');
      expect(resendFinder, findsOneWidget);

      // Tapping should not fire any resend event.
      await tester.tap(resendFinder);
      await tester.pump();
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'signup_otp_resend_requested',
        ),
        isFalse,
      );
    });

    testWidgets('Resend OTP link becomes enabled at zero and fires '
        'resend callback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
          ],
          child: MaterialApp(
            home: OtpEntryScreen(
              phoneNumber: '9876543210',
              initialCountdownSeconds: 1,
            ),
          ),
        ),
      );

      // Wait for countdown to expire.
      await tester.pump(const Duration(seconds: 2));

      final resendFinder = find.text('Resend');
      await tester.tap(resendFinder);
      await tester.pump();

      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'signup_otp_resend_requested',
        ),
        isTrue,
      );
    });

    testWidgets('"Edit phone number" pops the route', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => OtpEntryScreen(phoneNumber: '9876543210'),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      // Navigate to OTP screen.
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Tap the back button.
      final backButton = find.byTooltip('Navigate back');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back on the first screen.
      expect(find.text('Go'), findsOneWidget);
      expect(find.byType(OtpEntryScreen), findsNothing);
    });

    testWidgets('telemetry: signup_otp_screen_viewed fires on mount', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'signup_otp_screen_viewed' &&
              e.parameters != null &&
              e.parameters!.containsKey('phone_hash'),
        ),
        isTrue,
      );
    });

    testWidgets('telemetry: phone_hash is NOT the raw phone number', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final viewedEvent = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'signup_otp_screen_viewed',
      );
      expect(viewedEvent.parameters?['phone_hash'], isNot('9876543210'));
      expect(viewedEvent.parameters?['phone_hash'], isA<String>());
    });

    testWidgets('heading has Semantics header annotation', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.bySemanticsLabel('Verify your number'), findsOneWidget);
    });
  });
}
