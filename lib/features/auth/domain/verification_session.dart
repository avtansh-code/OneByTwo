import 'package:flutter/foundation.dart';

/// Immutable value object representing an in-progress phone verification.
///
/// Holds the state returned by the `codeSent` callback of
/// `FirebaseAuth.verifyPhoneNumber`. This object is never persisted;
/// it lives only in memory for the duration of the auth flow.
@immutable
class VerificationSession {
  /// Creates a [VerificationSession].
  const VerificationSession({
    required this.verificationId,
    required this.phoneNumber,
    required this.requestedAt,
    this.resendToken,
  });

  /// The verification ID from the `codeSent` callback.
  final String verificationId;

  /// The E.164 formatted phone number (e.g. `+919876543210`).
  final String phoneNumber;

  /// The resend token from the `codeSent` callback.
  ///
  /// Available on Android; `null` on iOS.
  final int? resendToken;

  /// The time at which the OTP was requested.
  final DateTime requestedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerificationSession &&
          runtimeType == other.runtimeType &&
          verificationId == other.verificationId &&
          phoneNumber == other.phoneNumber &&
          resendToken == other.resendToken &&
          requestedAt == other.requestedAt;

  @override
  int get hashCode =>
      Object.hash(verificationId, phoneNumber, resendToken, requestedAt);
}
