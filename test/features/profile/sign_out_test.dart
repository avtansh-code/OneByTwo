// Sign-out Flow Tests
//
// Widget tests for the sign-out flow on ProfileScreen,
// covering the confirmation dialog, cancellation, successful
// sign-out, and error handling (FR-AU-07 + FR-AU-08).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/core/widgets/dialogs/obt_confirmation_dialog.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/profile/presentation/profile_screen.dart';

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
  bool shouldFail = false;

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
    if (shouldFail) {
      throw Exception('Sign out failed');
    }
    signOutCalled = true;
  }
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {}

  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {}

  @override
  Future<String> uploadAvatar(String uid, String filePath) async =>
      'https://example.com/avatar.jpg';

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {}

  @override
  Future<void> deleteAvatar(String uid) async {}

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {}
}

// -- Helpers -----------------------------------------------------

final _testUser = UserModel(
  phoneNumber: '+919876543210',
  displayName: 'Test User',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

Widget _buildProfile({
  required _FakeAnalyticsService analytics,
  required _FakePhoneAuthRepository authRepo,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      phoneAuthRepositoryProvider.overrideWithValue(authRepo),
      userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          AuthenticatedWithProfile(uid: 'uid-123', user: _testUser),
        ),
      ),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

// -- Tests -------------------------------------------------------

void main() {
  group('ProfileScreen sign-out flow', () {
    late _FakeAnalyticsService analytics;
    late _FakePhoneAuthRepository authRepo;

    setUp(() {
      analytics = _FakeAnalyticsService();
      authRepo = _FakePhoneAuthRepository();
    });

    testWidgets('Sign Out row is visible', (tester) async {
      await tester.pumpWidget(
        _buildProfile(analytics: analytics, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('displays user info from auth state', (tester) async {
      await tester.pumpWidget(
        _buildProfile(analytics: analytics, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      // Initials in avatar.
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('tapping Sign Out shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        _buildProfile(analytics: analytics, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // The hand-rolled AlertDialog is now the shared OBTConfirmationDialog
      // (DC-10); sign-out is not destructive, so the confirm stays marigold.
      expect(find.byType(OBTConfirmationDialog), findsOneWidget);

      // Dialog title.
      expect(find.text('Sign out?'), findsOneWidget);

      // Dialog body.
      expect(
        find.text(
          "You'll need your +91 number and a fresh code to sign back in. "
          'Your expenses and groups stay safe.',
        ),
        findsOneWidget,
      );

      // Dialog actions.
      expect(find.text('Cancel'), findsOneWidget);
      // 'Sign Out' in the dialog button (+ the ListTile behind).
      expect(find.text('Sign out'), findsNWidgets(2));
    });

    testWidgets(
      'tapping Cancel dismisses dialog and fires sign_out_cancelled',
      (tester) async {
        await tester.pumpWidget(
          _buildProfile(analytics: analytics, authRepo: authRepo),
        );
        await tester.pumpAndSettle();

        // Open dialog.
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        // Tap Cancel.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed.
        expect(find.text('Sign out?'), findsNothing);

        // Analytics event fired.
        expect(analytics.loggedEvents, contains('sign_out_cancelled'));

        // signOut should NOT have been called.
        expect(authRepo.signOutCalled, isFalse);

        // User should still be on the profile screen.
        expect(find.text('Edit profile'), findsOneWidget);
      },
    );

    testWidgets('dismissing via the barrier does not log sign_out_cancelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildProfile(analytics: analytics, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // Open dialog.
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);

      // Dismiss by tapping the scrim outside the dialog (not Cancel).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog dismissed, but — like the previous AlertDialog — a barrier
      // dismiss logs nothing (no telemetry behaviour change).
      expect(find.text('Sign out?'), findsNothing);
      expect(analytics.loggedEvents, isNot(contains('sign_out_cancelled')));
      expect(authRepo.signOutCalled, isFalse);
    });

    testWidgets('tapping Sign Out (confirm) calls signOut and fires '
        'sign_out_completed', (tester) async {
      await tester.pumpWidget(
        _buildProfile(analytics: analytics, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // Open dialog.
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // Tap the confirm Sign Out button (the FilledButton in the
      // dialog, which is the last 'Sign Out' text widget).
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      // signOut was called.
      expect(authRepo.signOutCalled, isTrue);

      // Analytics event fired.
      expect(analytics.loggedEvents, contains('sign_out_completed'));
    });

    testWidgets('sign-out failure shows error snackbar', (tester) async {
      authRepo.shouldFail = true;

      await tester.pumpWidget(
        _buildProfile(analytics: analytics, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // Open dialog.
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // Tap confirm.
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      // Error snackbar should be shown.
      expect(
        find.text('Could not sign out. Please try again.'),
        findsOneWidget,
      );

      // signOutCalled remains false because the fake threw.
      expect(authRepo.signOutCalled, isFalse);
    });
  });
}
