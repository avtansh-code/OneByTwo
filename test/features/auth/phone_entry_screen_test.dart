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
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

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
  /// When non-null, [requestOtp] invokes `onCodeSent`.
  VerificationSession? requestOtpSession;

  /// When non-null, [requestOtp] invokes `onError`.
  AuthError? requestOtpError;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {
    if (requestOtpError != null) {
      onError(requestOtpError!);
      return;
    }
    if (requestOtpSession != null) {
      onCodeSent(requestOtpSession!);
    }
  }

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async => const Failure(AuthError.unknown);

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakePhoneAuthRepository fakeRepository;

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        phoneAuthRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: const MaterialApp(home: PhoneEntryScreen()),
    );
  }

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakePhoneAuthRepository();
  });

  group('PhoneEntryScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(PhoneEntryScreen), findsOneWidget);
    });

    testWidgets('+91 prefix is visible and not editable', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('🇮🇳 +91'), findsOneWidget);

      final prefixFinder = find.text('🇮🇳 +91');
      final prefixWidget = tester.widget<Text>(prefixFinder);
      expect(prefixWidget, isA<Text>());

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
        find.widgetWithText(FilledButton, 'Send OTP'),
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
        find.widgetWithText(FilledButton, 'Send OTP'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Continue button enables when input is 10 valid digits '
        '(starting with 6-9)', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send OTP'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping Continue with invalid prefix (starts with 5) '
        'shows error message', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '5678901234');
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'Send OTP');
      await tester.tap(button);
      await tester.pump();

      expect(
        find.text('Please enter a valid 10-digit mobile number.'),
        findsOneWidget,
      );
    });

    testWidgets('telemetry signup_started fires on Continue tap '
        'with valid input', (tester) async {
      fakeRepository.requestOtpSession = VerificationSession(
        verificationId: 'vid',
        phoneNumber: '+919876543210',
        requestedAt: DateTime(2025),
      );

      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
      await tester.pump();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'signup_started'),
        isTrue,
      );
    });

    testWidgets('error message is hidden by default', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text('Please enter a valid 10-digit mobile number.'),
        findsNothing,
      );
    });

    testWidgets('heading and subtitle text are displayed', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("What's your number?"), findsOneWidget);
      expect(
        find.text("We'll text a 6-digit code to verify it's you."),
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

    testWidgets('shows OTP-send error as a snackbar (SCR-03)', (tester) async {
      fakeRepository.requestOtpError = AuthError.tooManyRequests;

      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(
        find.widgetWithText(SnackBar, AuthError.tooManyRequests.message),
        findsOneWidget,
      );
    });

    testWidgets('phone_entry_viewed fires on mount with source', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'phone_entry_viewed',
      );
      expect(event.parameters, containsPair('source', 'splash'));
    });

    testWidgets('live formatting shows XXXXX XXXXX grouping (SCR-03)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();

      expect(find.text('98765 43210'), findsOneWidget);
    });

    group('unified +91/input height (issue #150)', () {
      testWidgets('phone input row is an IntrinsicHeight wrapping a '
          'stretched Row', (tester) async {
        await tester.pumpWidget(buildSubject());

        final intrinsicFinder = find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(IntrinsicHeight),
        );
        expect(intrinsicFinder, findsOneWidget);

        final intrinsic = tester.widget<IntrinsicHeight>(intrinsicFinder);
        expect(intrinsic.child, isA<Row>());
        expect(
          (intrinsic.child! as Row).crossAxisAlignment,
          CrossAxisAlignment.stretch,
        );
      });

      testWidgets('the +91 prefix and the input field render at equal '
          'heights', (tester) async {
        await tester.pumpWidget(buildSubject());

        final prefixBox = find
            .ancestor(
              of: find.text('🇮🇳 +91'),
              matching: find.byType(Container),
            )
            .first;
        final prefixHeight = tester.getSize(prefixBox).height;
        final fieldHeight = tester.getSize(find.byType(TextField)).height;

        expect(prefixHeight, greaterThan(0));
        expect(fieldHeight, moreOrLessEquals(prefixHeight, epsilon: 0.5));
      });
    });
  });
}
