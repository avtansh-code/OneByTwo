import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/profile/application/change_phone_controller.dart';
import 'package:onebytwo/features/profile/presentation/change_phone_screen.dart';

class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakeAccountRepo implements PhoneAccountRepository {
  AuthError? reauthResult;
  AuthError? updateResult;

  @override
  String? currentPhoneNumber() => '+919876543210';

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    void Function(PhoneAuthCredential credential)? onAutoRetrieved,
  }) async {
    onCodeSent(
      VerificationSession(
        verificationId: 'vid',
        phoneNumber: phoneNumber,
        requestedAt: DateTime(2024),
      ),
    );
  }

  @override
  Future<AuthError?> reauthenticate({
    required String verificationId,
    required String code,
  }) async => reauthResult;

  @override
  Future<AuthError?> reauthenticateWithCredential(
    PhoneAuthCredential credential,
  ) async => reauthResult;

  @override
  Future<AuthError?> updatePhoneNumber({
    required String verificationId,
    required String code,
  }) async => updateResult;

  @override
  Future<AuthError?> updatePhoneNumberWithCredential(
    PhoneAuthCredential credential,
  ) async => updateResult;

  @override
  Future<void> refreshIdToken() async {}
}

class _FakeUserRepo implements UserRepository {
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
  Future<String> uploadAvatar(String uid, String filePath) async => '';

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {}

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {}

  @override
  Future<void> deleteAvatar(String uid) async {}
}

void main() {
  late _FakeAccountRepo account;
  late _FakeUserRepo users;

  setUp(() {
    account = _FakeAccountRepo();
    users = _FakeUserRepo();
  });

  ChangePhoneController buildController() => ChangePhoneController(
    uid: 'uid-1',
    currentPhoneNumber: '+919876543210',
    analytics: _FakeAnalyticsService(),
    accountRepository: account,
    userRepository: users,
  );

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      changePhoneControllerProvider.overrideWith((ref) => buildController()),
    ],
    child: MaterialApp(home: child),
  );

  testWidgets('renders the re-auth intro step first', (tester) async {
    await tester.pumpWidget(wrap(const ChangePhoneScreen()));

    expect(find.text('Verify your current number'), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
  });

  testWidgets('walks the full happy path to the success screen and returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChangePhoneScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Step 1: send re-auth code.
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6)); // OTP cells

    // Step 2: enter the re-auth OTP (paste-distribute via first cell).
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
    expect(find.text('Your new number'), findsOneWidget);

    // Step 3: enter the new number and request its OTP.
    await tester.enterText(find.byType(TextField).last, '9123456780');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your new number'), findsOneWidget);

    // Step 4: enter the new-number OTP -> success brand screen.
    await tester.enterText(find.byType(TextField).first, '654321');
    await tester.pumpAndSettle();

    expect(find.text('Phone number updated'), findsOneWidget);
    expect(find.text('Back to Profile'), findsOneWidget);

    // "Back to Profile" pops to the home screen.
    await tester.tap(find.text('Back to Profile'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows an error when the re-auth OTP is wrong', (tester) async {
    account.reauthResult = AuthError.invalidOtp;
    await tester.pumpWidget(wrap(const ChangePhoneScreen()));

    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pumpAndSettle();

    expect(find.text(AuthError.invalidOtp.message), findsOneWidget);
    // Still on the re-auth OTP step (not advanced).
    expect(find.text('Your new number'), findsNothing);
  });
}
