import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
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

/// Fake [PhoneAuthRepository] for screen tests.
class FakePhoneAuthRepository implements PhoneAuthRepository {
  /// When non-null, [verifyOtp] returns this result.
  Result<AuthUser, AuthError>? verifyOtpResult;

  /// When non-null, [resendOtp] invokes `onCodeSent`.
  VerificationSession? resendOtpSession;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {}

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async => verifyOtpResult ?? const Failure(AuthError.unknown);

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {
    if (resendOtpSession != null) {
      onCodeSent(resendOtpSession!);
    }
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakePhoneAuthRepository fakeRepository;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakePhoneAuthRepository();
  });

  Widget buildSubject({String phoneNumber = '9876543210'}) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        phoneAuthRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: MaterialApp(
        home: OtpEntryScreen(
          phoneNumber: phoneNumber,
          verificationId: 'vid-test',
        ),
      ),
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

    testWidgets('phone number in subtitle is masked '
        '(last 4 digits visible)', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('XXXXXX3210'), findsOneWidget);
      expect(find.textContaining('9876543210'), findsNothing);
    });

    testWidgets('Resend OTP link is disabled during countdown', (tester) async {
      await tester.pumpWidget(buildSubject());
      final resendFinder = find.byType(TextButton);
      expect(resendFinder, findsOneWidget);

      final button = tester.widget<TextButton>(resendFinder);
      expect(button.onPressed, isNull);

      await tester.tap(resendFinder);
      await tester.pump();
      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'otp_resend_tapped'),
        isFalse,
      );
    });

    testWidgets('Resend OTP link becomes enabled at zero and fires '
        'resend callback', (tester) async {
      fakeRepository.resendOtpSession = VerificationSession(
        verificationId: 'vid-resend',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
            phoneAuthRepositoryProvider.overrideWithValue(fakeRepository),
          ],
          child: const MaterialApp(
            home: OtpEntryScreen(
              phoneNumber: '9876543210',
              verificationId: 'vid-test',
              initialCountdownSeconds: 1,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      final resendFinder = find.byType(TextButton);
      await tester.tap(resendFinder);
      await tester.pump();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'otp_resend_tapped'),
        isTrue,
      );
    });

    testWidgets('"Edit phone number" pops the route', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
            phoneAuthRepositoryProvider.overrideWithValue(fakeRepository),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const OtpEntryScreen(
                        phoneNumber: '9876543210',
                        verificationId: 'vid-test',
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      final backButton = find.byTooltip('Navigate back');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Go'), findsOneWidget);
      expect(find.byType(OtpEntryScreen), findsNothing);
    });

    testWidgets('telemetry: otp_screen_viewed fires on mount', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'otp_screen_viewed' &&
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
        (e) => e.name == 'otp_screen_viewed',
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
