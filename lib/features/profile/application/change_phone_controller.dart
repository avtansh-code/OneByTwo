import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/validators.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';

/// The steps of the FR-PR-02 change-phone re-verification flow.
enum ChangePhoneStep {
  /// Re-authentication intro: the current number is shown read-only with a
  /// "Send verification code" action (SCR-28 Step B pattern).
  reauthIntro,

  /// OTP entry for the CURRENT number (re-authentication leg).
  reauthOtp,

  /// New +91 number entry.
  newPhoneEntry,

  /// OTP entry for the NEW number (update leg).
  newPhoneOtp,

  /// The number has been updated everywhere; the screen may pop.
  success,
}

/// Immutable state for the change-phone flow (FR-PR-02).
class ChangePhoneState {
  /// Creates a [ChangePhoneState].
  const ChangePhoneState({
    required this.currentPhoneNumber,
    this.step = ChangePhoneStep.reauthIntro,
    this.newPhoneDigits = '',
    this.verificationId,
    this.isLoading = false,
    this.validationError,
    this.errorMessage,
    this.syncPending = false,
  });

  /// The user's current verified E.164 phone number (re-auth target and
  /// the value the new number is checked against).
  final String currentPhoneNumber;

  /// The current step of the flow.
  final ChangePhoneStep step;

  /// The raw 10-digit new number (no prefix).
  final String newPhoneDigits;

  /// The verification ID for the in-progress OTP leg.
  final String? verificationId;

  /// Whether a Firebase or Firestore operation is in progress.
  final bool isLoading;

  /// Non-null when the new-number entry failed client-side validation.
  final String? validationError;

  /// Non-null when an operation (OTP/reauth/update/sync) failed.
  final String? errorMessage;

  /// True when the auth phone was updated but the Firestore users-doc sync
  /// failed and can be retried without re-entering an OTP.
  final bool syncPending;

  /// The E.164 form of the entered new number.
  String get newPhoneE164 => '+91$newPhoneDigits';

  /// Whether the entered new number equals the current number.
  bool get isSameAsCurrent => newPhoneE164 == currentPhoneNumber;

  /// Creates a copy with the given fields replaced.
  ChangePhoneState copyWith({
    String? currentPhoneNumber,
    ChangePhoneStep? step,
    String? newPhoneDigits,
    String? Function()? verificationId,
    bool? isLoading,
    String? Function()? validationError,
    String? Function()? errorMessage,
    bool? syncPending,
  }) {
    return ChangePhoneState(
      currentPhoneNumber: currentPhoneNumber ?? this.currentPhoneNumber,
      step: step ?? this.step,
      newPhoneDigits: newPhoneDigits ?? this.newPhoneDigits,
      verificationId: verificationId != null
          ? verificationId()
          : this.verificationId,
      isLoading: isLoading ?? this.isLoading,
      validationError: validationError != null
          ? validationError()
          : this.validationError,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      syncPending: syncPending ?? this.syncPending,
    );
  }
}

/// Controller for the FR-PR-02 change-phone flow (SCR-26 entry point).
///
/// Drives a two-OTP state machine: re-verify the CURRENT number
/// (`reauthenticate`), then verify the NEW number
/// (`currentUser.updatePhoneNumber`), then force an ID-token refresh and
/// write `users/{uid}.phoneNumber`. The re-authentication leg is part of
/// the normal path because FR-AU-07 session persistence keeps the last
/// sign-in older than Firebase's recent-login window. See ADR-0015.
class ChangePhoneController extends StateNotifier<ChangePhoneState> {
  /// Creates a [ChangePhoneController].
  ///
  /// Fires `phone_change_started` on creation.
  ChangePhoneController({
    required String uid,
    required String currentPhoneNumber,
    required AnalyticsService analytics,
    required PhoneAccountRepository accountRepository,
    required UserRepository userRepository,
  }) : _uid = uid,
       _analytics = analytics,
       _accountRepository = accountRepository,
       _userRepository = userRepository,
       super(ChangePhoneState(currentPhoneNumber: currentPhoneNumber)) {
    unawaited(_analytics.logEvent(name: 'phone_change_started'));
  }

  final String _uid;
  final AnalyticsService _analytics;
  final PhoneAccountRepository _accountRepository;
  final UserRepository _userRepository;

  /// Updates the entered new-number digits and clears any prior error.
  void updateNewPhone(String digits) {
    state = state.copyWith(
      newPhoneDigits: digits,
      validationError: () => null,
      errorMessage: () => null,
    );
  }

  /// Requests an OTP for the CURRENT number to begin re-authentication.
  Future<void> sendReauthOtp() async {
    await _requestOtp(
      phoneNumber: state.currentPhoneNumber,
      leg: 'reauth',
      nextStep: ChangePhoneStep.reauthOtp,
      onAutoRetrieved: _onReauthAutoRetrieved,
    );
  }

  /// Submits the OTP for the re-authentication leg.
  Future<void> submitReauthOtp(String code) async {
    final vid = state.verificationId;
    if (vid == null || state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: () => null);
    final error = await _accountRepository.reauthenticate(
      verificationId: vid,
      code: code,
    );
    if (!mounted) return;
    _onReauthComplete(error);
  }

  /// Applies the outcome of a re-authentication (manual or auto-retrieved).
  void _onReauthComplete(AuthError? error) {
    if (error == null) {
      state = state.copyWith(
        isLoading: false,
        step: ChangePhoneStep.newPhoneEntry,
        verificationId: () => null,
      );
    } else {
      _failWith(error);
    }
  }

  /// Android instant verification of the CURRENT number: re-authenticate
  /// with the auto-retrieved credential rather than waiting for manual OTP.
  void _onReauthAutoRetrieved(PhoneAuthCredential credential) {
    if (state.step != ChangePhoneStep.reauthIntro &&
        state.step != ChangePhoneStep.reauthOtp) {
      return;
    }
    unawaited(_reauthWithCredential(credential));
  }

  Future<void> _reauthWithCredential(PhoneAuthCredential credential) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    final error = await _accountRepository.reauthenticateWithCredential(
      credential,
    );
    if (!mounted) return;
    _onReauthComplete(error);
  }

  /// Validates the new number and requests its OTP.
  Future<void> submitNewPhone() async {
    if (state.isLoading) return;

    final validation = validateIndianMobile(state.newPhoneDigits);
    if (validation != null) {
      state = state.copyWith(validationError: () => validation);
      return;
    }
    if (state.isSameAsCurrent) {
      state = state.copyWith(
        validationError: () => 'This is already your phone number.',
      );
      return;
    }

    await _requestOtp(
      phoneNumber: state.newPhoneE164,
      leg: 'new_number',
      nextStep: ChangePhoneStep.newPhoneOtp,
      onAutoRetrieved: _onNewPhoneAutoRetrieved,
    );
  }

  /// Submits the OTP for the new number and, on success, syncs Firestore.
  Future<void> submitNewPhoneOtp(String code) async {
    final vid = state.verificationId;
    if (vid == null || state.isLoading || state.syncPending) return;

    state = state.copyWith(isLoading: true, errorMessage: () => null);
    final error = await _accountRepository.updatePhoneNumber(
      verificationId: vid,
      code: code,
    );
    if (!mounted) return;
    await _onUpdateComplete(error);
  }

  /// Android instant verification of the NEW number: update with the
  /// auto-retrieved credential rather than waiting for manual OTP.
  void _onNewPhoneAutoRetrieved(PhoneAuthCredential credential) {
    if (state.syncPending) return;
    if (state.step != ChangePhoneStep.newPhoneEntry &&
        state.step != ChangePhoneStep.newPhoneOtp) {
      return;
    }
    unawaited(_updateWithCredential(credential));
  }

  Future<void> _updateWithCredential(PhoneAuthCredential credential) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    final error = await _accountRepository.updatePhoneNumberWithCredential(
      credential,
    );
    if (!mounted) return;
    await _onUpdateComplete(error);
  }

  /// Applies the outcome of a phone-number update (manual or auto-retrieved).
  Future<void> _onUpdateComplete(AuthError? error) async {
    if (error != null) {
      _failWith(error);
      return;
    }
    // Auth phone updated. Clear the (now-consumed) verificationId so an
    // OtpInput re-fire cannot re-run updatePhoneNumber, then sync Firestore.
    state = state.copyWith(verificationId: () => null);
    await _completeSync();
  }

  /// Retries the Firestore sync after a successful auth update whose
  /// users-doc write failed (no new OTP required).
  Future<void> retrySync() async {
    if (state.isLoading || !state.syncPending) return;
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    await _completeSync();
  }

  Future<void> _completeSync() async {
    try {
      await _accountRepository.refreshIdToken();
      await _userRepository.updatePhoneNumber(
        uid: _uid,
        phoneNumber: state.newPhoneE164,
      );
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        step: ChangePhoneStep.success,
        syncPending: false,
        errorMessage: () => null,
      );
      unawaited(_analytics.logEvent(name: 'phone_change_completed'));
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        syncPending: true,
        errorMessage: () =>
            'Your number was verified but we could not finish '
            'updating it. Please try again.',
      );
      unawaited(
        _analytics.logEvent(
          name: 'phone_change_failed',
          parameters: {'error_code': 'sync_failed'},
        ),
      );
    }
  }

  Future<void> _requestOtp({
    required String phoneNumber,
    required String leg,
    required ChangePhoneStep nextStep,
    void Function(PhoneAuthCredential credential)? onAutoRetrieved,
  }) async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
      validationError: () => null,
    );
    unawaited(
      _analytics.logEvent(
        name: 'phone_change_otp_requested',
        parameters: {'leg': leg},
      ),
    );

    await _accountRepository.requestOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (session) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          step: nextStep,
          verificationId: () => session.verificationId,
        );
      },
      onError: (error) {
        if (!mounted) return;
        _failWith(error);
      },
      onAutoRetrieved: onAutoRetrieved,
    );
  }

  void _failWith(AuthError error) {
    state = state.copyWith(isLoading: false, errorMessage: () => error.message);
    unawaited(
      _analytics.logEvent(
        name: 'phone_change_failed',
        parameters: {'error_code': error.name},
      ),
    );
  }
}

/// Riverpod provider for [ChangePhoneController].
///
/// Auto-disposing so the controller is cleaned up when the change-phone
/// screen is removed from the tree. The uid comes from
/// [authStateNotifierProvider]; the re-auth target number is sourced from
/// Firebase Auth (`currentUser.phoneNumber`) — the authoritative number
/// `reauthenticateWithCredential` runs against — falling back to the
/// Firestore users-doc number only when Auth has none.
final changePhoneControllerProvider =
    StateNotifierProvider.autoDispose<ChangePhoneController, ChangePhoneState>((
      ref,
    ) {
      final authState = ref.read(authStateNotifierProvider).valueOrNull;
      final uid = switch (authState) {
        AuthenticatedWithProfile(:final uid) => uid,
        _ => '',
      };
      final docPhoneNumber = switch (authState) {
        AuthenticatedWithProfile(:final user) => user.phoneNumber,
        _ => '',
      };
      final accountRepository = ref.watch(phoneAccountRepositoryProvider);
      final currentPhoneNumber =
          accountRepository.currentPhoneNumber() ?? docPhoneNumber;

      return ChangePhoneController(
        uid: uid,
        currentPhoneNumber: currentPhoneNumber,
        analytics: ref.watch(analyticsServiceProvider),
        accountRepository: accountRepository,
        userRepository: ref.watch(userRepositoryProvider),
      );
    });
