import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

/// Fake [AnalyticsService] for the smoke test.
class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

/// Fake [PhoneAuthRepository] for the smoke test.
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

/// Fake [UserRepository] for the smoke test.
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

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {}
}

void main() {
  testWidgets('app boots and shows the phone entry screen', (tester) async {
    // Override the auth state provider to skip Firebase initialisation.
    // The auth gate renders PhoneEntryScreen for AuthUnauthenticated.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
          phoneAuthRepositoryProvider.overrideWithValue(
            _FakePhoneAuthRepository(),
          ),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          authStateNotifierProvider.overrideWith(
            (ref) => Stream.value(const AuthUnauthenticated()),
          ),
        ],
        child: const MaterialApp(home: PhoneEntryScreen()),
      ),
    );

    expect(find.text('Enter your mobile number'), findsOneWidget);
  });
}
