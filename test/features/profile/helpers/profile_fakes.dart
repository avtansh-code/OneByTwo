// Shared no-op / configurable fakes for the DC-10 Profile reskin gate.
//
// Defined once and reused by profile_haldi_reskin_test.dart and the DC-10
// golden scaffold rather than redefined per file (the DC-07/08/09 shared-fakes
// review lesson). The behavioural per-surface suites keep their own inline
// fakes; these back only the new reskin-gate pumps.

import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;

import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_account_repository.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/profile/data/delete_account_repository.dart';

/// Records emitted analytics event names so a reskin test can assert a
/// converted control still emits its planned telemetry.
class FakeAnalytics implements AnalyticsService {
  /// Event names captured in emission order.
  final List<String> events = <String>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(name);
  }
}

/// Configurable [PhoneAccountRepository] for the change-phone / delete-account
/// re-auth flows. The current number is fixed so masking is deterministic.
class FakeAccountRepo implements PhoneAccountRepository {
  /// Creates a [FakeAccountRepo].
  FakeAccountRepo({this.reauthResult, this.updateResult});

  /// Result returned by both re-authenticate entry points.
  AuthError? reauthResult;

  /// Result returned by both update-number entry points.
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

/// [UserRepository] whose Firestore mirror write can be made to throw, to
/// drive the change-phone "sync pending" recovery state.
class FakeUserRepo implements UserRepository {
  /// Creates a [FakeUserRepo].
  FakeUserRepo({this.throwOnSync = false});

  /// When true, [updatePhoneNumber] throws so the auth update succeeds but the
  /// Firestore mirror does not (the sync-pending branch).
  bool throwOnSync;

  @override
  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {
    if (throwOnSync) throw Exception('sync failed');
  }

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

/// No-op [PhoneAuthRepository] that records whether [signOut] ran.
class FakePhoneAuthRepository implements PhoneAuthRepository {
  /// True once [signOut] has been called.
  bool signOutCalled = false;

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
    signOutCalled = true;
  }
}

/// No-op [DeleteAccountRepository]; the server cascade is unchanged by DC-10.
class FakeDeleteRepo implements DeleteAccountRepository {
  @override
  Future<void> deleteAccount() async {}
}

/// No-op [AppSettingsService] for the notification-preferences pump.
class FakeAppSettings implements AppSettingsService {
  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

/// A deterministic [UserModel] for the reskin pumps.
UserModel fakeUser({Map<String, bool>? prefs}) => UserModel(
  phoneNumber: '+919876543210',
  displayName: 'Test User',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
  notificationPrefs:
      prefs ??
      const <String, bool>{
        'newExpense': true,
        'settlement': true,
        'reminder': true,
      },
);
