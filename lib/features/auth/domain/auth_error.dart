/// Domain-level authentication error codes.
///
/// Each value corresponds to one or more `FirebaseAuthException.code`
/// values. The [message] getter returns user-facing copy in British
/// English. See `docs/design/07-technical/auth-error-codes.md` for the
/// full mapping table.
enum AuthError {
  /// The phone number is invalid or missing.
  invalidPhoneNumber,

  /// Too many requests have been made in a short period.
  tooManyRequests,

  /// The SMS quota has been exceeded.
  quotaExceeded,

  /// A network error occurred.
  networkFailure,

  /// Phone sign-in is not enabled for this project.
  operationNotAllowed,

  /// The app is not authorised for phone sign-in.
  appNotAuthorised,

  /// The reCAPTCHA check failed.
  captchaFailed,

  /// The user account has been disabled.
  userDisabled,

  /// The OTP code does not match.
  invalidOtp,

  /// The verification session has expired.
  sessionExpired,

  /// The credential is already linked to another account.
  credentialInUse,

  /// The operation needs a recent sign-in; the user must re-authenticate.
  ///
  /// Raised by sensitive mutations such as `updatePhoneNumber` when the
  /// last sign-in is older than Firebase's recent-login window. Under
  /// FR-AU-07 session persistence this is the common path, not an edge
  /// case, so the change-phone flow re-verifies the current number first.
  requiresRecentLogin,

  /// An unknown error occurred.
  unknown;

  /// User-facing error message.
  ///
  /// This is the single source of user-facing auth error copy.
  /// Controllers must use this getter rather than hard-coding messages.
  String get message => switch (this) {
    invalidPhoneNumber =>
      'That phone number is not valid. '
          'Please check and try again.',
    tooManyRequests =>
      'Too many attempts. '
          'Please wait a few minutes before trying again.',
    quotaExceeded =>
      'We are unable to send codes right now. '
          'Please try again later.',
    networkFailure =>
      'Could not connect. '
          'Please check your internet and try again.',
    operationNotAllowed =>
      'Phone sign-in is not available at the moment. '
          'Please contact support.',
    appNotAuthorised =>
      'This app is not authorised for phone sign-in. '
          'Please contact support.',
    captchaFailed => 'Verification check failed. Please try again.',
    userDisabled =>
      'Your account is currently unavailable. '
          'Please contact support for help.',
    invalidOtp =>
      'That code does not match. '
          'Please check and try again.',
    sessionExpired => 'Your code has expired. Please request a new one.',
    credentialInUse =>
      'This phone number is already linked to another '
          'account. Please contact support.',
    requiresRecentLogin =>
      'For your security, please verify your current '
          'number again before changing it.',
    unknown => 'Something went wrong. Please try again.',
  };
}

/// Maps a raw `FirebaseAuthException.code` to a domain [AuthError].
///
/// This is the single source of truth for the Firebase-code → [AuthError]
/// translation, shared by every repository that wraps Firebase Phone Auth
/// (`FirebasePhoneAuthRepository` for sign-in and the change-phone account
/// repository). See `docs/design/07-technical/auth-error-codes.md` for the
/// full mapping table.
AuthError authErrorFromFirebaseCode(String code) {
  return switch (code) {
    'invalid-phone-number' ||
    'missing-phone-number' => AuthError.invalidPhoneNumber,
    'too-many-requests' => AuthError.tooManyRequests,
    'quota-exceeded' => AuthError.quotaExceeded,
    'network-request-failed' => AuthError.networkFailure,
    'operation-not-allowed' => AuthError.operationNotAllowed,
    'app-not-authorized' => AuthError.appNotAuthorised,
    'captcha-check-failed' => AuthError.captchaFailed,
    'user-disabled' => AuthError.userDisabled,
    'invalid-verification-code' => AuthError.invalidOtp,
    'session-expired' || 'invalid-verification-id' => AuthError.sessionExpired,
    'credential-already-in-use' => AuthError.credentialInUse,
    'requires-recent-login' || 'user-mismatch' => AuthError.requiresRecentLogin,
    _ => AuthError.unknown,
  };
}
