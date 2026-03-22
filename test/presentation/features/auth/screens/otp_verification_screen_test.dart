import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_by_two/core/l10n/generated/app_localizations.dart';
import 'package:one_by_two/presentation/features/auth/screens/otp_verification_screen.dart';
import 'package:one_by_two/presentation/providers/auth_providers.dart';
import 'package:pinput/pinput.dart';

// ---------------------------------------------------------------------------
// Fakes for provider overrides
// ---------------------------------------------------------------------------

/// Fake [SendOtpNotifier] that immediately succeeds with a new verification ID.
///
/// Used by regression tests to simulate a successful OTP resend without
/// requiring Firebase.
class FakeSendOtpNotifier extends SendOtpNotifier {
  @override
  FutureOr<String?> build() => null;

  @override
  Future<void> sendOtp(String phoneNumber) async {
    state = const AsyncData('new-verification-id');
  }
}

/// Fake [VerifyOtpNotifier] that records the verification ID it receives.
///
/// Allows regression tests to assert which verificationId the screen passed
/// to the verification flow — stale (from route params) or fresh (from
/// a successful resend).
class FakeVerifyOtpNotifier extends VerifyOtpNotifier {
  /// The last verification ID passed to [verifyOtp].
  static String? lastVerificationId;

  @override
  FutureOr<String?> build() => null;

  @override
  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    lastVerificationId = verificationId;
    // Don't set state to AsyncData(uid) — avoids triggering navigation
    // in tests that don't set up the downstream providers.
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  /// Wraps [OtpVerificationScreen] with GoRouter (including [initialExtra]),
  /// Riverpod, and l10n.
  ///
  /// The screen reads `GoRouterState.of(context).extra` to obtain
  /// `verificationId` and `phone`. Passing [extra] sets these values via
  /// GoRouter's `initialExtra` so the screen renders with realistic data.
  ///
  /// The [verifyOtpNotifierProvider] and [sendOtpNotifierProvider] both
  /// auto-initialise to `AsyncData(null)` — no Firebase dependency.
  Widget buildSubject({Map<String, String>? extra}) {
    final router = GoRouter(
      initialLocation: '/test',
      initialExtra: extra,
      routes: [
        GoRoute(
          path: '/test',
          builder: (_, __) => const OtpVerificationScreen(),
        ),
        // Navigation targets used by the screen.
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/profile-setup',
          name: 'profile-setup',
          builder: (_, __) => const Scaffold(body: Text('Profile Setup')),
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
  // Constants from the screen under test
  // ---------------------------------------------------------------------------

  /// Default phone used across most tests.
  const testPhone = '+919876543210';

  /// Expected masked output for [testPhone]: "+91 •••••• 3210".
  const maskedPhone = '+91 \u2022\u2022\u2022\u2022\u2022\u2022 3210';

  /// Default verification ID (not used for rendering, but the screen expects
  /// it in extra).
  const testVerificationId = 'test-verification-id';

  /// Default extra map passed via GoRouter.
  const defaultExtra = <String, String>{
    'verificationId': testVerificationId,
    'phone': testPhone,
  };

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('OtpVerificationScreen', () {
    group('rendering', () {
      testWidgets('should display title from l10n', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        // Use pump() throughout OTP screen tests — the screen's periodic
        // resend timer causes pumpAndSettle() to time out.
        await tester.pump();

        // Assert
        expect(find.text('Verify your number'), findsOneWidget);
      });

      testWidgets('should display subtitle with masked phone number', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Assert — subtitle includes masked phone:
        // "Enter the 6-digit code sent to +91 •••••• 3210"
        expect(
          find.text('Enter the 6-digit code sent to $maskedPhone'),
          findsOneWidget,
        );
      });

      testWidgets('should display subtitle with empty phone when no extra', (
        tester,
      ) async {
        // Arrange & Act — no extra provided, phone defaults to ''
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Assert — _maskPhone('') returns '' (length < 4), subtitle ends
        // with the empty string.
        expect(find.text('Enter the 6-digit code sent to '), findsOneWidget);
      });

      testWidgets('should display Pinput widget for OTP entry', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Assert
        expect(find.byType(Pinput), findsOneWidget);
      });

      testWidgets('should display Verify button with l10n text', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Assert
        expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
      });

      testWidgets('should display resend countdown text on initial render', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Assert — initial value is otpResendDelaySeconds = 30
        expect(find.text('Resend code in 30s'), findsOneWidget);
      });

      testWidgets('should display an AppBar', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Assert
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('should wrap content in SafeArea', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Assert
        expect(find.byType(SafeArea), findsAtLeastNWidgets(1));
      });
    });

    group('button state', () {
      testWidgets('should have Verify button disabled initially', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump();

        // Act — no OTP entered

        // Assert
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Verify'),
        );
        expect(button.onPressed, isNull);
      });
    });

    group('resend timer', () {
      testWidgets('should decrement resend timer after 1 second', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump(); // initial frame

        // Sanity — starts at 30
        expect(find.text('Resend code in 30s'), findsOneWidget);

        // Act — advance 1 second
        await tester.pump(const Duration(seconds: 1));

        // Assert — decremented to 29
        expect(find.text('Resend code in 29s'), findsOneWidget);
      });

      testWidgets('should show Resend Code button after timer expires', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pump(); // initial frame

        // Act — advance past the full countdown (30 seconds)
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Assert — countdown text is gone, "Resend Code" TextButton appears
        expect(find.text('Resend code in 30s'), findsNothing);
        expect(find.widgetWithText(TextButton, 'Resend Code'), findsOneWidget);
      });
    });

    group('regression: stale verificationId after resend', () {
      // Reset static state before each test.
      setUp(() {
        FakeVerifyOtpNotifier.lastVerificationId = null;
      });

      /// Wraps [OtpVerificationScreen] with GoRouter, Riverpod (with fake
      /// notifier overrides), and l10n. Used exclusively by regression tests
      /// in this group.
      Widget buildSubjectWithFakes({Map<String, String>? extra}) {
        final router = GoRouter(
          initialLocation: '/test',
          initialExtra: extra,
          routes: [
            GoRoute(
              path: '/test',
              builder: (_, __) => const OtpVerificationScreen(),
            ),
            GoRoute(
              path: '/',
              name: 'home',
              builder: (_, __) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/profile-setup',
              name: 'profile-setup',
              builder: (_, __) => const Scaffold(body: Text('Profile Setup')),
            ),
          ],
        );

        return ProviderScope(
          overrides: [
            sendOtpNotifierProvider.overrideWith(FakeSendOtpNotifier.new),
            verifyOtpNotifierProvider.overrideWith(FakeVerifyOtpNotifier.new),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
      }

      testWidgets(
        'should use new verificationId for verification after OTP resend',
        (tester) async {
          // Arrange — screen receives 'old-verification-id' via route extra.
          await tester.pumpWidget(
            buildSubjectWithFakes(
              extra: const <String, String>{
                'verificationId': 'old-verification-id',
                'phone': '+919876543210',
              },
            ),
          );
          await tester.pump();

          // Wait for resend timer to expire (30 s).
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(
            find.widgetWithText(TextButton, 'Resend Code'),
            findsOneWidget,
          );

          // Act — tap "Resend Code". FakeSendOtpNotifier.sendOtp sets the
          // provider state to AsyncData('new-verification-id').
          await tester.tap(find.widgetWithText(TextButton, 'Resend Code'));
          await tester.pump(); // rebuild from _resendOtp's _startResendTimer
          await tester.pump(); // rebuild from listener's setState

          // Enter a 6-digit OTP and tap Verify.
          await tester.enterText(find.byType(Pinput), '123456');
          await tester.pump(); // _onPinChanged → _isOtpComplete = true
          await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
          await tester.pump();

          // Assert — the NEW verificationId was used, not the stale one.
          // Before the fix, this was 'old-verification-id' because the
          // screen always read from GoRouterState.extra.
          expect(
            FakeVerifyOtpNotifier.lastVerificationId,
            equals('new-verification-id'),
            reason:
                'After OTP resend, verification must use the new '
                'verificationId, not the stale one from route params.',
          );
        },
      );

      testWidgets('should restart resend timer when OTP resend succeeds', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          buildSubjectWithFakes(
            extra: const <String, String>{
              'verificationId': 'old-verification-id',
              'phone': '+919876543210',
            },
          ),
        );
        await tester.pump();

        // Wait for the resend timer to expire.
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Act — tap "Resend Code".
        await tester.tap(find.widgetWithText(TextButton, 'Resend Code'));
        await tester.pump(); // rebuild from _resendOtp
        await tester.pump(); // rebuild from listener

        // Assert — timer restarted, countdown text visible again.
        expect(find.text('Resend code in 30s'), findsOneWidget);

        // After 1 second, it should decrement normally.
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Resend code in 29s'), findsOneWidget);
      });
    });
  });
}
