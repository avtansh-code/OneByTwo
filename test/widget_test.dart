import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
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

void main() {
  testWidgets('app boots and shows the phone entry screen', (tester) async {
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

    expect(find.text('Enter your mobile number'), findsOneWidget);
  });
}
