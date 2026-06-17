// ignore_for_file: cascade_invocations
import 'package:firebase_auth/firebase_auth.dart'
    show PhoneAuthCredential, PhoneAuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/profile/application/delete_account_controller.dart';
import 'package:onebytwo/features/profile/application/delete_account_telemetry.dart';
import 'package:onebytwo/features/profile/data/delete_account_repository.dart';

/// Records logged analytics events.
class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  List<String> get names => loggedEvents.map((e) => e.name).toList();

  Map<String, Object>? paramsOf(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;
}

/// Configurable fake [PhoneAccountRepository] (re-auth surface only).
class FakePhoneAccountRepository implements PhoneAccountRepository {
  String currentNumber = '+919876543210';
  AuthError? requestOtpError;
  AuthError? reauthResult;
  PhoneAuthCredential? autoRetrievedCredential;

  final List<String> requestedPhones = [];
  String? lastReauthCode;

  @override
  String? currentPhoneNumber() => currentNumber;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    void Function(PhoneAuthCredential credential)? onAutoRetrieved,
  }) async {
    requestedPhones.add(phoneNumber);
    if (requestOtpError != null) {
      onError(requestOtpError!);
      return;
    }
    if (autoRetrievedCredential != null) {
      onAutoRetrieved?.call(autoRetrievedCredential!);
      return;
    }
    onCodeSent(
      VerificationSession(
        verificationId: 'vid-${requestedPhones.length}',
        phoneNumber: phoneNumber,
        requestedAt: DateTime(2024),
      ),
    );
  }

  @override
  Future<AuthError?> reauthenticate({
    required String verificationId,
    required String code,
  }) async {
    lastReauthCode = code;
    return reauthResult;
  }

  @override
  Future<AuthError?> reauthenticateWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return reauthResult;
  }

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

/// Configurable fake [DeleteAccountRepository].
class FakeDeleteAccountRepository implements DeleteAccountRepository {
  int calls = 0;

  /// When non-null, [deleteAccount] throws this.
  Exception? throwError;

  /// When set, [deleteAccount] delays this long before completing (used to
  /// trigger the controller timeout).
  Duration? delay;

  @override
  Future<void> deleteAccount() async {
    calls++;
    if (delay != null) await Future<void>.delayed(delay!);
    if (throwError != null) throw throwError!;
  }
}

class _Harness {
  _Harness({Duration deleteTimeout = const Duration(seconds: 30)}) {
    controller = DeleteAccountController(
      currentPhoneNumber: account.currentNumber,
      analytics: analytics,
      accountRepository: account,
      deleteAccountRepository: deleteRepo,
      signOut: () async => signOutCalls++,
      deleteTimeout: deleteTimeout,
    );
  }

  final analytics = FakeAnalyticsService();
  final account = FakePhoneAccountRepository();
  final deleteRepo = FakeDeleteAccountRepository();
  int signOutCalls = 0;
  late final DeleteAccountController controller;

  /// Advances the controller to Step C (confirm) via the happy re-auth path.
  Future<void> reachConfirm() async {
    controller.continueFromWarning();
    await controller.sendReauthOtp();
    await controller.submitReauthOtp('123456');
  }
}

void main() {
  group('DeleteAccountController — lifecycle and Step A', () {
    test('fires delete_account_started on creation', () {
      final h = _Harness();
      expect(h.analytics.names, contains(DeleteAccountTelemetry.started));
      expect(h.controller.state.step, DeleteAccountStep.warning);
    });

    test('continueFromWarning advances to reauthIntro and logs the event', () {
      final h = _Harness();
      h.controller.continueFromWarning();
      expect(h.controller.state.step, DeleteAccountStep.reauthIntro);
      expect(
        h.analytics.names,
        contains(DeleteAccountTelemetry.warningContinued),
      );
    });

    test('cancelFromWarning logs the cancelled event', () {
      final h = _Harness();
      h.controller.cancelFromWarning();
      expect(
        h.analytics.names,
        contains(DeleteAccountTelemetry.warningCancelled),
      );
    });
  });

  group('DeleteAccountController — Step B re-authentication', () {
    test('sendReauthOtp requests an OTP for the current number and advances '
        'to reauthOtp', () async {
      final h = _Harness();
      h.controller.continueFromWarning();
      await h.controller.sendReauthOtp();
      expect(h.account.requestedPhones, ['+919876543210']);
      expect(h.controller.state.step, DeleteAccountStep.reauthOtp);
      expect(h.controller.state.verificationId, isNotNull);
    });

    test('submitReauthOtp success advances to confirm and logs '
        'reauth_completed', () async {
      final h = _Harness();
      h.controller.continueFromWarning();
      await h.controller.sendReauthOtp();
      await h.controller.submitReauthOtp('123456');
      expect(h.account.lastReauthCode, '123456');
      expect(h.controller.state.step, DeleteAccountStep.confirm);
      expect(
        h.analytics.names,
        contains(DeleteAccountTelemetry.reauthCompleted),
      );
    });

    test('wrong OTP shows an inline error and stays on reauthOtp (no failed '
        'event)', () async {
      final h = _Harness();
      h.account.reauthResult = AuthError.invalidOtp;
      h.controller.continueFromWarning();
      await h.controller.sendReauthOtp();
      await h.controller.submitReauthOtp('000000');
      expect(h.controller.state.step, DeleteAccountStep.reauthOtp);
      expect(h.controller.state.errorMessage, AuthError.invalidOtp.message);
      expect(h.controller.state.snackbarMessage, isNull);
      expect(h.analytics.names, isNot(contains(DeleteAccountTelemetry.failed)));
    });

    test('max-retries (tooManyRequests) surfaces a one-shot snackbar, not an '
        'inline error', () async {
      final h = _Harness();
      h.account.reauthResult = AuthError.tooManyRequests;
      h.controller.continueFromWarning();
      await h.controller.sendReauthOtp();
      await h.controller.submitReauthOtp('000000');
      expect(
        h.controller.state.snackbarMessage,
        AuthError.tooManyRequests.message,
      );
      expect(h.controller.state.errorMessage, isNull);
      h.controller.clearSnackbar();
      expect(h.controller.state.snackbarMessage, isNull);
    });

    test('max-retries on the OTP REQUEST surfaces the snackbar and makes no '
        'delete call (AC-3 request path)', () async {
      final h = _Harness();
      h.account.requestOtpError = AuthError.tooManyRequests;
      h.controller.continueFromWarning();
      await h.controller.sendReauthOtp();
      expect(
        h.controller.state.snackbarMessage,
        AuthError.tooManyRequests.message,
      );
      expect(h.controller.state.errorMessage, isNull);
      expect(h.controller.state.step, DeleteAccountStep.reauthIntro);
      expect(h.deleteRepo.calls, 0);
    });

    test('Android instant verification re-authenticates and advances to '
        'confirm', () async {
      final h = _Harness();
      h.controller.continueFromWarning();
      h.controller.debugFireReauthAutoRetrieved(
        PhoneAuthProvider.credential(verificationId: 'vid', smsCode: '123456'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(h.controller.state.step, DeleteAccountStep.confirm);
      expect(
        h.analytics.names,
        contains(DeleteAccountTelemetry.reauthCompleted),
      );
    });
  });

  group('DeleteAccountController — Step C type-DELETE gate', () {
    test('confirmationMatches is true only for an exact, trimmed DELETE', () {
      final h = _Harness();
      h.controller.updateConfirmationText('delete');
      expect(h.controller.state.confirmationMatches, isFalse);
      h.controller.updateConfirmationText('DELETE ME');
      expect(h.controller.state.confirmationMatches, isFalse);
      h.controller.updateConfirmationText('  DELETE  ');
      expect(h.controller.state.confirmationMatches, isTrue);
      h.controller.updateConfirmationText('DELETE');
      expect(h.controller.state.confirmationMatches, isTrue);
    });

    test('confirmDeletion is a no-op while the gate is unsatisfied', () async {
      final h = _Harness();
      await h.reachConfirm();
      h.controller.updateConfirmationText('delete');
      await h.controller.confirmDeletion();
      expect(h.deleteRepo.calls, 0);
      expect(h.controller.state.step, DeleteAccountStep.confirm);
    });
  });

  group('DeleteAccountController — Step D cascade', () {
    test(
      'success advances to success and logs confirmed + completed',
      () async {
        final h = _Harness();
        await h.reachConfirm();
        h.controller.updateConfirmationText('DELETE');
        await h.controller.confirmDeletion();
        expect(h.deleteRepo.calls, 1);
        expect(h.controller.state.step, DeleteAccountStep.success);
        expect(h.analytics.names, contains(DeleteAccountTelemetry.confirmed));
        expect(h.analytics.names, contains(DeleteAccountTelemetry.completed));
      },
    );

    test('a typed failure advances to failed and logs the catalogue '
        'error_code', () async {
      final h = _Harness();
      h.deleteRepo.throwError = const DeleteAccountException(
        code: 'internal',
        errorCode: 'INTERNAL',
      );
      await h.reachConfirm();
      h.controller.updateConfirmationText('DELETE');
      await h.controller.confirmDeletion();
      expect(h.controller.state.step, DeleteAccountStep.failed);
      expect(h.analytics.paramsOf(DeleteAccountTelemetry.failed), {
        DeleteAccountTelemetry.paramErrorCode: 'INTERNAL',
      });
    });

    test(
      'a 30-second timeout advances to failed with error_code timeout',
      () async {
        final h = _Harness(deleteTimeout: const Duration(milliseconds: 20));
        h.deleteRepo.delay = const Duration(milliseconds: 200);
        await h.reachConfirm();
        h.controller.updateConfirmationText('DELETE');
        await h.controller.confirmDeletion();
        expect(h.controller.state.step, DeleteAccountStep.failed);
        expect(h.analytics.paramsOf(DeleteAccountTelemetry.failed), {
          DeleteAccountTelemetry.paramErrorCode: 'timeout',
        });
      },
    );

    test('never logs the uid or phone number in any event parameter', () async {
      final h = _Harness();
      h.deleteRepo.throwError = const DeleteAccountException(
        code: 'internal',
        errorCode: 'INTERNAL',
      );
      await h.reachConfirm();
      h.controller.updateConfirmationText('DELETE');
      await h.controller.confirmDeletion();
      for (final event in h.analytics.loggedEvents) {
        final serialised = event.parameters?.toString() ?? '';
        expect(serialised.contains('+91'), isFalse);
        expect(serialised.contains('919876543210'), isFalse);
      }
    });
  });

  group('DeleteAccountController — Step E sign-out', () {
    test('signOutAfterDeletion invokes the injected sign-out', () async {
      final h = _Harness();
      await h.controller.signOutAfterDeletion();
      expect(h.signOutCalls, 1);
    });
  });

  group('DeleteAccountController — back navigation', () {
    test('goBack from warning returns false (caller pops)', () {
      final h = _Harness();
      expect(h.controller.goBack(), isFalse);
      expect(
        h.analytics.names,
        contains(DeleteAccountTelemetry.warningCancelled),
      );
    });

    test('goBack steps reauthIntro -> warning', () {
      final h = _Harness();
      h.controller.continueFromWarning();
      expect(h.controller.goBack(), isTrue);
      expect(h.controller.state.step, DeleteAccountStep.warning);
    });

    test(
      'goBack steps confirm -> reauthIntro and clears the typed text',
      () async {
        final h = _Harness();
        await h.reachConfirm();
        h.controller.updateConfirmationText('DELETE');
        expect(h.controller.goBack(), isTrue);
        expect(h.controller.state.step, DeleteAccountStep.reauthIntro);
        expect(h.controller.state.confirmationText, '');
      },
    );

    test('goBack is blocked (handled) during success', () async {
      final h = _Harness();
      await h.reachConfirm();
      h.controller.updateConfirmationText('DELETE');
      await h.controller.confirmDeletion();
      expect(h.controller.state.step, DeleteAccountStep.success);
      expect(h.controller.goBack(), isTrue);
      expect(h.controller.state.step, DeleteAccountStep.success);
    });
  });
}
