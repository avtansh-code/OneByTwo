// Splash Screen Tests
//
// Widget tests for the SplashScreen, covering the logo, tagline,
// loading indicator, and the 3-second recovery timeout flow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/auth/presentation/splash_screen.dart';

// -- Fakes -------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  final List<String> loggedEvents = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
  }
}

class _FakePhoneAuthRepository implements PhoneAuthRepository {
  bool signOutCalled = false;

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
  }) async => const Failure(AuthError.unknown);

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

// -- Helpers -----------------------------------------------------

/// Short timeout for tests to avoid slow test suites.
const _testTimeout = Duration(milliseconds: 100);

Widget _buildSplash({
  required _FakeAnalyticsService analytics,
  required _FakePhoneAuthRepository authRepo,
  Duration timeoutDuration = _testTimeout,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      phoneAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
    child: MaterialApp(home: SplashScreen(timeoutDuration: timeoutDuration)),
  );
}

// -- Tests -------------------------------------------------------

void main() {
  group('SplashScreen', () {
    late _FakeAnalyticsService analytics;
    late _FakePhoneAuthRepository authRepo;

    setUp(() {
      analytics = _FakeAnalyticsService();
      authRepo = _FakePhoneAuthRepository();
    });

    testWidgets('renders logo and tagline', (tester) async {
      await tester.pumpWidget(
        _buildSplash(analytics: analytics, authRepo: authRepo),
      );
      await tester.pump();

      // Logo icon.
      expect(find.byIcon(Icons.vertical_split_rounded), findsOneWidget);

      // Tagline text.
      expect(find.text('Split it. Settle it. Simple.'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator initially', (tester) async {
      await tester.pumpWidget(
        _buildSplash(analytics: analytics, authRepo: authRepo),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Recovery text should NOT be visible yet.
      expect(find.text('Having trouble?'), findsNothing);
      expect(find.text('Sign out and start over'), findsNothing);
    });

    testWidgets('shows recovery text after timeout', (tester) async {
      await tester.pumpWidget(
        _buildSplash(analytics: analytics, authRepo: authRepo),
      );
      await tester.pump();

      // Before timeout.
      expect(find.text('Having trouble?'), findsNothing);

      // Advance past the timeout.
      await tester.pump(_testTimeout);

      // Recovery option should now be visible.
      expect(find.text('Having trouble?'), findsOneWidget);
      expect(find.text('Sign out and start over'), findsOneWidget);

      // Loader should be gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('recovery button with default 3-second timeout', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSplash(
          analytics: analytics,
          authRepo: authRepo,
          timeoutDuration: const Duration(seconds: 3),
        ),
      );
      await tester.pump();

      // Not visible at 2 seconds.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Having trouble?'), findsNothing);

      // Visible at 3 seconds.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Having trouble?'), findsOneWidget);
    });

    testWidgets('tapping recovery button calls signOut', (tester) async {
      await tester.pumpWidget(
        _buildSplash(analytics: analytics, authRepo: authRepo),
      );
      await tester.pump();

      // Advance past timeout to show recovery.
      await tester.pump(_testTimeout);

      // Tap the recovery button.
      await tester.tap(find.text('Sign out and start over'));
      await tester.pumpAndSettle();

      expect(authRepo.signOutCalled, isTrue);
    });

    testWidgets('fires app_launched analytics event on init', (tester) async {
      await tester.pumpWidget(
        _buildSplash(analytics: analytics, authRepo: authRepo),
      );
      // The event fires via addPostFrameCallback, so pump once to
      // process it.
      await tester.pump();

      expect(analytics.loggedEvents, contains('app_launched'));
    });
  });
}
