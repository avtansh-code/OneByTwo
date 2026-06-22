import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/profile/application/delete_account_telemetry.dart';
import 'package:onebytwo/features/profile/data/delete_account_repository.dart';

/// The steps of the FR-AU-09 account-deletion flow (SCR-28 Part B).
enum DeleteAccountStep {
  /// Step A: the permanent-deletion warning (Continue / Cancel).
  warning,

  /// Step B intro: the current number is shown read-only with a
  /// "Send verification code" action.
  reauthIntro,

  /// Step B OTP entry for the CURRENT number (re-authentication leg).
  reauthOtp,

  /// Step C: type-`DELETE` final confirmation.
  confirm,

  /// Step D: the `deleteUserAccount` cascade is running (back blocked).
  processing,

  /// Step E: the account was deleted; the screen shows success then
  /// signs out to the Phone Entry screen.
  success,

  /// Terminal failure of Step D — the screen returns to Profile View with
  /// a Contact Support snackbar.
  failed,
}

/// The exact-match confirmation token required in Step C (case-sensitive).
const String kDeleteConfirmationWord = 'DELETE';

/// Immutable state for the account-deletion flow (FR-AU-09).
class DeleteAccountState {
  /// Creates a [DeleteAccountState].
  const DeleteAccountState({
    required this.currentPhoneNumber,
    this.step = DeleteAccountStep.warning,
    this.verificationId,
    this.confirmationText = '',
    this.isLoading = false,
    this.errorMessage,
    this.snackbarMessage,
  });

  /// The user's current verified E.164 phone number (the re-auth target,
  /// shown read-only in Step B).
  final String currentPhoneNumber;

  /// The current step of the flow.
  final DeleteAccountStep step;

  /// The verification ID for the in-progress re-auth OTP leg.
  final String? verificationId;

  /// The raw Step C confirmation-text input.
  final String confirmationText;

  /// Whether a Firebase or Cloud Function operation is in progress.
  final bool isLoading;

  /// Non-null when an operation failed and the message should display
  /// inline (e.g. a wrong re-auth OTP).
  final String? errorMessage;

  /// Non-null when a one-shot snackbar should be shown (e.g. the
  /// max-retries error at re-authentication, per SCR-28).
  final String? snackbarMessage;

  /// Whether the Step C confirmation text matches `DELETE` exactly
  /// (case-sensitive, trimmed of surrounding whitespace).
  bool get confirmationMatches =>
      confirmationText.trim() == kDeleteConfirmationWord;

  /// Creates a copy with the given fields replaced.
  DeleteAccountState copyWith({
    DeleteAccountStep? step,
    String? Function()? verificationId,
    String? confirmationText,
    bool? isLoading,
    String? Function()? errorMessage,
    String? Function()? snackbarMessage,
  }) {
    return DeleteAccountState(
      currentPhoneNumber: currentPhoneNumber,
      step: step ?? this.step,
      verificationId: verificationId != null
          ? verificationId()
          : this.verificationId,
      confirmationText: confirmationText ?? this.confirmationText,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      snackbarMessage: snackbarMessage != null
          ? snackbarMessage()
          : this.snackbarMessage,
    );
  }
}

/// Controller for the FR-AU-09 account-deletion flow (SCR-28 Part B).
///
/// Drives the five-step state machine (warning -> re-authentication ->
/// type-`DELETE` confirmation -> processing -> success). The Step B
/// re-authentication REUSES the FR-PR-02 [PhoneAccountRepository]
/// (`requestOtp` + `reauthenticate`) — it never calls `signInWithCredential`.
/// The cascade itself runs server-side in the `deleteUserAccount` callable;
/// on success the controller signs out so the root auth gate clears the
/// stack to the Phone Entry screen. See ADR-0016.
class DeleteAccountController extends StateNotifier<DeleteAccountState> {
  /// Creates a [DeleteAccountController].
  ///
  /// Fires `delete_account_started` on creation (Step A opens).
  DeleteAccountController({
    required String currentPhoneNumber,
    required AnalyticsService analytics,
    required PhoneAccountRepository accountRepository,
    required DeleteAccountRepository deleteAccountRepository,
    required Future<void> Function() signOut,
    Duration deleteTimeout = const Duration(seconds: 30),
  }) : _analytics = analytics,
       _accountRepository = accountRepository,
       _deleteAccountRepository = deleteAccountRepository,
       _signOut = signOut,
       _deleteTimeout = deleteTimeout,
       super(DeleteAccountState(currentPhoneNumber: currentPhoneNumber)) {
    unawaited(_analytics.logEvent(name: DeleteAccountTelemetry.started));
  }

  final AnalyticsService _analytics;
  final PhoneAccountRepository _accountRepository;
  final DeleteAccountRepository _deleteAccountRepository;
  final Future<void> Function() _signOut;
  final Duration _deleteTimeout;

  /// Guards against a late Android instant-verification credential racing
  /// an in-flight manual submit (mirrors the FR-PR-02 controller).
  bool _verifying = false;

  // --- Step A: warning ---

  /// Advances from the Step A warning to Step B re-authentication.
  void continueFromWarning() {
    if (state.step != DeleteAccountStep.warning) return;
    unawaited(
      _analytics.logEvent(name: DeleteAccountTelemetry.warningContinued),
    );
    state = state.copyWith(
      step: DeleteAccountStep.reauthIntro,
      errorMessage: () => null,
    );
  }

  /// Records the Step A cancellation telemetry (the screen then pops).
  void cancelFromWarning() {
    unawaited(
      _analytics.logEvent(name: DeleteAccountTelemetry.warningCancelled),
    );
  }

  /// Handles the back affordance per SCR-28 step semantics.
  ///
  /// Returns `true` when the back was handled by moving to a previous step
  /// and `false` when the caller should pop the screen (Step A -> Profile).
  /// Back is a no-op (handled, blocked) during processing / success /
  /// failure.
  bool goBack() {
    switch (state.step) {
      case DeleteAccountStep.warning:
        cancelFromWarning();
        return false;
      case DeleteAccountStep.reauthIntro:
        state = state.copyWith(
          step: DeleteAccountStep.warning,
          errorMessage: () => null,
          verificationId: () => null,
        );
        return true;
      case DeleteAccountStep.reauthOtp:
        state = state.copyWith(
          step: DeleteAccountStep.reauthIntro,
          errorMessage: () => null,
          verificationId: () => null,
        );
        return true;
      case DeleteAccountStep.confirm:
        state = state.copyWith(
          step: DeleteAccountStep.reauthIntro,
          confirmationText: '',
          errorMessage: () => null,
        );
        return true;
      case DeleteAccountStep.processing:
      case DeleteAccountStep.success:
      case DeleteAccountStep.failed:
        return true;
    }
  }

  // --- Step B: re-authentication (reuses FR-PR-02) ---

  /// Requests an OTP for the CURRENT number to begin re-authentication.
  Future<void> sendReauthOtp() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    await _accountRepository.requestOtp(
      phoneNumber: state.currentPhoneNumber,
      onCodeSent: (session) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          step: DeleteAccountStep.reauthOtp,
          verificationId: () => session.verificationId,
        );
      },
      onError: (error) {
        if (!mounted) return;
        _failReauth(error);
      },
      onAutoRetrieved: _onReauthAutoRetrieved,
    );
  }

  /// Submits the OTP for the re-authentication leg.
  Future<void> submitReauthOtp(String code) async {
    final vid = state.verificationId;
    if (vid == null || _verifying) return;

    _verifying = true;
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    final error = await _accountRepository.reauthenticate(
      verificationId: vid,
      code: code,
    );
    if (!mounted) return;
    _onReauthComplete(error);
  }

  /// Android instant verification of the CURRENT number.
  void _onReauthAutoRetrieved(PhoneAuthCredential credential) {
    if (_verifying) return;
    if (state.step != DeleteAccountStep.reauthIntro &&
        state.step != DeleteAccountStep.reauthOtp) {
      return;
    }
    unawaited(_reauthWithCredential(credential));
  }

  Future<void> _reauthWithCredential(PhoneAuthCredential credential) async {
    if (_verifying) return;
    _verifying = true;
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    final error = await _accountRepository.reauthenticateWithCredential(
      credential,
    );
    if (!mounted) return;
    _onReauthComplete(error);
  }

  void _onReauthComplete(AuthError? error) {
    _verifying = false;
    if (error == null) {
      unawaited(
        _analytics.logEvent(name: DeleteAccountTelemetry.reauthCompleted),
      );
      state = state.copyWith(
        isLoading: false,
        step: DeleteAccountStep.confirm,
        verificationId: () => null,
        errorMessage: () => null,
      );
    } else {
      _failReauth(error);
    }
  }

  /// Surfaces a re-authentication failure. Max-retries (`tooManyRequests`)
  /// is shown as a one-shot snackbar per SCR-28; every other auth error is
  /// shown inline on the OTP field. Neither path emits
  /// `delete_account_failed` — that event is reserved for the Cloud
  /// Function (Step D).
  void _failReauth(AuthError error) {
    if (error == AuthError.tooManyRequests) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => null,
        snackbarMessage: () => error.message,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => error.message,
      );
    }
  }

  /// Clears the one-shot [DeleteAccountState.snackbarMessage] after the
  /// screen has shown it.
  void clearSnackbar() {
    if (state.snackbarMessage == null) return;
    state = state.copyWith(snackbarMessage: () => null);
  }

  // --- Step C: type-DELETE confirmation ---

  /// Updates the Step C confirmation-text input.
  void updateConfirmationText(String text) {
    state = state.copyWith(confirmationText: text);
  }

  // --- Step C -> D: run the cascade ---

  /// Invokes `deleteUserAccount` (Step D). Only proceeds when the Step C
  /// gate is satisfied. On success advances to Step E; on error or the
  /// 30-second timeout advances to [DeleteAccountStep.failed].
  Future<void> confirmDeletion() async {
    if (!state.confirmationMatches || state.isLoading) return;

    unawaited(_analytics.logEvent(name: DeleteAccountTelemetry.confirmed));
    state = state.copyWith(
      step: DeleteAccountStep.processing,
      isLoading: true,
      errorMessage: () => null,
    );

    try {
      await _deleteAccountRepository.deleteAccount().timeout(_deleteTimeout);
      if (!mounted) return;
      unawaited(_analytics.logEvent(name: DeleteAccountTelemetry.completed));
      state = state.copyWith(step: DeleteAccountStep.success, isLoading: false);
    } catch (error) {
      if (!mounted) return;
      unawaited(
        _analytics.logEvent(
          name: DeleteAccountTelemetry.failed,
          parameters: {
            DeleteAccountTelemetry.paramErrorCode: _errorCode(error),
          },
        ),
      );
      state = state.copyWith(step: DeleteAccountStep.failed, isLoading: false);
    }
  }

  /// Maps a deletion failure to a PII-free `error_code` (never the uid or
  /// phone number).
  String _errorCode(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is DeleteAccountException) return error.errorCode;
    return 'unknown';
  }

  // --- Step E: sign out to Phone Entry ---

  /// Signs the user out after the Step E success display. The root auth
  /// gate reacts to the unauthenticated state by clearing the navigation
  /// stack to the Phone Entry screen (`lib/main.dart`).
  Future<void> signOutAfterDeletion() async {
    await _signOut();
  }

  /// Test-only hook to drive the private Android instant-verification
  /// handler for the re-auth leg.
  @visibleForTesting
  void debugFireReauthAutoRetrieved(PhoneAuthCredential credential) =>
      _onReauthAutoRetrieved(credential);
}

/// Riverpod provider for [DeleteAccountController].
///
/// Auto-disposing so the controller is cleaned up when the delete-account
/// screen leaves the tree. The re-auth target number is sourced from
/// Firebase Auth (`currentUser.phoneNumber`) — the authoritative number
/// `reauthenticate` runs against — falling back to the Firestore users-doc
/// number only when Auth has none.
final deleteAccountControllerProvider =
    StateNotifierProvider.autoDispose<
      DeleteAccountController,
      DeleteAccountState
    >((ref) {
      final authState = ref.read(authStateProvider).valueOrNull;
      final docPhoneNumber = switch (authState) {
        AuthenticatedWithProfile(:final user) => user.phoneNumber,
        _ => '',
      };
      final accountRepository = ref.watch(phoneAccountRepositoryProvider);
      final currentPhoneNumber =
          accountRepository.currentPhoneNumber() ?? docPhoneNumber;
      final authRepository = ref.watch(phoneAuthRepositoryProvider);

      return DeleteAccountController(
        currentPhoneNumber: currentPhoneNumber,
        analytics: ref.watch(analyticsServiceProvider),
        accountRepository: accountRepository,
        deleteAccountRepository: ref.watch(deleteAccountRepositoryProvider),
        signOut: authRepository.signOut,
      );
    });
