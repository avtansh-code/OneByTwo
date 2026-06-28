import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/profile/application/delete_account_controller.dart';
import 'package:onebytwo/features/profile/data/delete_account_repository.dart';
import 'package:onebytwo/features/profile/presentation/delete_account_screen.dart';

class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakeAccountRepo implements PhoneAccountRepository {
  AuthError? reauthResult;

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
  }) async => null;

  @override
  Future<AuthError?> updatePhoneNumberWithCredential(
    PhoneAuthCredential credential,
  ) async => null;

  @override
  Future<void> refreshIdToken() async {}
}

class _FakeDeleteRepo implements DeleteAccountRepository {
  Exception? throwError;
  Duration? delay;

  @override
  Future<void> deleteAccount() async {
    if (delay != null) await Future<void>.delayed(delay!);
    if (throwError != null) throw throwError!;
  }
}

void main() {
  late _FakeAccountRepo account;
  late _FakeDeleteRepo deleteRepo;
  var signOutCalls = 0;

  setUp(() {
    account = _FakeAccountRepo();
    deleteRepo = _FakeDeleteRepo();
    signOutCalls = 0;
  });

  DeleteAccountController buildController() => DeleteAccountController(
    currentPhoneNumber: '+919876543210',
    analytics: _FakeAnalyticsService(),
    accountRepository: account,
    deleteAccountRepository: deleteRepo,
    signOut: () async => signOutCalls++,
  );

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      deleteAccountControllerProvider.overrideWith((ref) => buildController()),
    ],
    child: MaterialApp(home: child),
  );

  /// Drives the flow to Step C (confirm) via the happy re-auth path.
  Future<void> reachConfirm(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
  }

  testWidgets('Step A renders the warning with Continue and Cancel', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const DeleteAccountScreen()));

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(
      find.textContaining('Data is removed within 30 days'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Continue advances to Step B re-authentication', (tester) async {
    await tester.pumpWidget(wrap(const DeleteAccountScreen()));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your identity'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
  });

  testWidgets('Cancel pops the screen', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeleteAccountScreen(),
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
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('Step C Delete button is gated on an exact DELETE', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const DeleteAccountScreen()));
    await reachConfirm(tester);

    expect(find.text('Confirm deletion'), findsOneWidget);

    FilledButton deleteButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Delete My Account'),
        matching: find.byType(FilledButton),
      ),
    );

    expect(deleteButton().onPressed, isNull, reason: 'disabled by default');

    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-input')),
      'delete',
    );
    await tester.pump();
    expect(deleteButton().onPressed, isNull, reason: 'case-sensitive');

    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-input')),
      'DELETE',
    );
    await tester.pump();
    expect(deleteButton().onPressed, isNotNull, reason: 'exact match enables');
  });

  testWidgets('Step D processing blocks back and shows the progress copy', (
    tester,
  ) async {
    deleteRepo.delay = const Duration(seconds: 1);
    await tester.pumpWidget(wrap(const DeleteAccountScreen()));
    await reachConfirm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-input')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.text('Delete My Account'));
    await tester.pump(); // enter processing (cascade still in flight)

    expect(find.text('Deleting your account...'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.pump(const Duration(seconds: 1)); // let the cascade complete
    await tester.pumpAndSettle();
    expect(find.text('Account deleted'), findsOneWidget);
  });

  testWidgets('Step E success shows the success state then signs out', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const DeleteAccountScreen()));
    await reachConfirm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-input')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.text('Delete My Account'));
    await tester.pumpAndSettle();

    expect(find.text('Account deleted'), findsOneWidget);
    expect(signOutCalls, 0);

    await tester.pump(const Duration(seconds: 3));
    expect(signOutCalls, 1);
  });

  testWidgets('a failure pops with DeleteAccountOutcome.failed', (
    tester,
  ) async {
    deleteRepo.throwError = const DeleteAccountException(
      code: 'internal',
      errorCode: 'INTERNAL',
    );
    DeleteAccountOutcome? popped;

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context)
                      .push<DeleteAccountOutcome>(
                        MaterialPageRoute<DeleteAccountOutcome>(
                          builder: (_) => const DeleteAccountScreen(),
                        ),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await reachConfirm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-input')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.text('Delete My Account'));
    await tester.pumpAndSettle();

    expect(popped, DeleteAccountOutcome.failed);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a max-retries re-auth error surfaces a snackbar', (
    tester,
  ) async {
    account.reauthResult = AuthError.tooManyRequests;
    await tester.pumpWidget(wrap(const DeleteAccountScreen()));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(AuthError.tooManyRequests.message), findsOneWidget);
  });
}
