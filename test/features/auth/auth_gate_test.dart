// Auth Gate Tests
//
// Widget tests for the OneBytwoApp root widget, which acts as the
// auth gate by routing to different screens based on AuthState.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/main.dart';

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
  Future<void> signOut() async {}
}

class _FakeUserRepository implements UserRepository {
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
}

List<Override> _baseOverrides({
  required Stream<AuthState> authStream,
  _FakeAnalyticsService? analytics,
}) {
  return [
    analyticsServiceProvider.overrideWithValue(
      analytics ?? _FakeAnalyticsService(),
    ),
    phoneAuthRepositoryProvider.overrideWithValue(_FakePhoneAuthRepository()),
    userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
    authStateNotifierProvider.overrideWith((ref) => authStream),
  ];
}

// -- Tests -------------------------------------------------------

void main() {
  group('Auth gate (OneBytwoApp)', () {
    testWidgets('loading state renders SplashScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            // Empty stream: provider stays in AsyncLoading.
            authStream: const Stream<AuthState>.empty(),
          ),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pump();

      // Splash screen shows the tagline.
      expect(find.text('Split it. Settle it. Simple.'), findsOneWidget);
    });

    testWidgets('AuthUnauthenticated renders PhoneEntryScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            authStream: Stream.value(const AuthUnauthenticated()),
          ),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter your mobile number'), findsOneWidget);
    });

    testWidgets('AuthenticatedNoProfile renders ProfileSetupScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            authStream: Stream.value(
              const AuthenticatedNoProfile(
                uid: 'uid-123',
                phoneNumber: '+919876543210',
              ),
            ),
          ),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set up your profile'), findsOneWidget);
    });

    testWidgets('AuthenticatedWithProfile renders HomePlaceholderScreen', (
      tester,
    ) async {
      final user = UserModel(
        phoneNumber: '+919876543210',
        displayName: 'Test User',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            authStream: Stream.value(
              AuthenticatedWithProfile(uid: 'uid-123', user: user),
            ),
          ),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('state transition from unauthenticated to authenticated '
        'changes screen', (tester) async {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(authStream: controller.stream),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pump();

      // Initially loading — splash screen.
      expect(find.text('Split it. Settle it. Simple.'), findsOneWidget);

      // Emit unauthenticated.
      controller.add(const AuthUnauthenticated());
      await tester.pumpAndSettle();
      expect(find.text('Enter your mobile number'), findsOneWidget);

      // Emit authenticated with profile.
      final user = UserModel(
        phoneNumber: '+919876543210',
        displayName: 'Test User',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      controller.add(AuthenticatedWithProfile(uid: 'uid-123', user: user));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('error state renders SplashScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            authStream: Stream<AuthState>.error(Exception('Auth error')),
          ),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Error state falls through to SplashScreen.
      expect(find.text('Split it. Settle it. Simple.'), findsOneWidget);
    });
  });
}
