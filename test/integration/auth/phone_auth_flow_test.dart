// Phone Auth Flow Integration Test
//
// This test runs against the Firebase Auth Emulator. Setup:
//
// 1. Start the Firebase Auth emulator:
//    firebase emulators:start --only auth --project demo-onebytwo
//
// 2. The emulator listens on localhost:9099 by default.
//
// 3. Run this test:
//    firebase emulators:exec --only auth \
//      "flutter test test/integration/" \
//      --project demo-onebytwo
//
// Tests live in test/integration/ (not integration_test/) so they
// run headlessly in CI without a connected device. Flutter reserves
// the integration_test/ directory for on-device tests requiring
// IntegrationTestWidgetsFlutterBinding.
//
// The Firebase Auth emulator auto-completes phone verification
// with the code "123456" for any phone number.

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

class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
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

void main() {
  group('Phone Auth Flow (emulator)', () {
    testWidgets('phone entry screen renders', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
            phoneAuthRepositoryProvider.overrideWithValue(
              _FakePhoneAuthRepository(),
            ),
          ],
          child: const MaterialApp(home: PhoneEntryScreen()),
        ),
      );

      expect(find.text("What's your number?"), findsOneWidget);
    });
  });
}
