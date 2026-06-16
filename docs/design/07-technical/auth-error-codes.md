# Auth Error Codes — Firebase Phone Auth

> **Document owner:** Solution Architect
> **PR:** #7
> **Version:** 1.0
> **Last updated:** 2025-07-15
> **SRS version:** 1.1
> **firebase\_auth package:** ^6.4.0

This document maps every relevant `FirebaseAuthException.code` to a domain-level
`AuthError` enum value, a user-facing message, a recovery affordance, and a
telemetry parameter value. It is the single source of truth for error handling in
the phone authentication flow.

> **Scope:** This document covers **client-side Firebase Phone Authentication**
> errors (`FirebaseAuthException`) only, as mapped in
> `lib/features/auth/data/phone_auth_repository.dart` to the
> `lib/features/auth/domain/auth_error.dart` enum. It does **not** cover
> Cloud Functions error codes. In particular, the server-side
> `lookupUserByPhoneNumber` callable returns its own typed codes
> (`UNAUTHENTICATED`, `INVALID_INPUT`, `RATE_LIMITED`, `INTERNAL`) — those are
> documented in `docs/design/07-technical/cloud-functions-error-codes.md`.

**Cross-references:**

- Cloud Functions error codes (server-side, including `lookupUserByPhoneNumber`):
  `docs/design/07-technical/cloud-functions-error-codes.md`
- SRS section 5.10 — Observability (telemetry events)
- Telemetry plan: `docs/design/07-technical/telemetry-plan.md` (events
  `otp_send_failed`, `otp_verification_failed`)
- Error taxonomy: `docs/design/07-technical/error-and-empty-state-taxonomy.md`
  (section 1.2)
- Wireframe: `docs/design/04-wireframes/auth-flow.md` (sections 3 and 4)
- Coding standards: `.github/shared/coding-standards.md`
- Invariants: `.github/shared/invariants.md`

---

## 1. Error Code Mapping Table

### 1.1 OTP Request Phase (`verifyPhoneNumber`)

These errors can be thrown when calling `FirebaseAuth.instance.verifyPhoneNumber`
and are delivered via the `verificationFailed` callback.

| Firebase Code | Domain Error | User Message | Recovery | Telemetry Code |
|---|---|---|---|---|
| `invalid-phone-number` | `AuthError.invalidPhoneNumber` | "That phone number is not valid. Please check and try again." | Edit number, tap Continue again. | `invalid_phone_number` |
| `too-many-requests` | `AuthError.tooManyRequests` | "Too many attempts. Please wait a few minutes before trying again." | Wait; UI disables Continue for a cooldown period. Contact Support link shown. | `too_many_requests` |
| `quota-exceeded` | `AuthError.quotaExceeded` | "We are unable to send codes right now. Please try again later." | Wait and retry later. Contact Support link shown. | `quota_exceeded` |
| `network-request-failed` | `AuthError.networkFailure` | "Could not connect. Please check your internet and try again." | Check connectivity, tap Continue again. | `network_request_failed` |
| `operation-not-allowed` | `AuthError.operationNotAllowed` | "Phone sign-in is not available at the moment. Please contact support." | Contact Support. No user-actionable retry. | `operation_not_allowed` |
| `app-not-authorized` | `AuthError.appNotAuthorised` | "This app is not authorised for phone sign-in. Please contact support." | Contact Support. No user-actionable retry. | `app_not_authorized` |
| `captcha-check-failed` | `AuthError.captchaFailed` | "Verification check failed. Please try again." | Tap Continue again to retry. | `captcha_check_failed` |
| `missing-phone-number` | `AuthError.invalidPhoneNumber` | "That phone number is not valid. Please check and try again." | Edit number, tap Continue again. | `missing_phone_number` |
| `user-disabled` | `AuthError.userDisabled` | "Your account is currently unavailable. Please contact support for help." | Contact Support. Sign out. No retry. | `user_disabled` |
| `internal-error` | `AuthError.unknown` | "Something went wrong. Please try again." | Tap Continue again. Contact Support after repeated failures. | `internal_error` |

### 1.2 OTP Verification Phase (`signInWithCredential`)

These errors can be thrown when calling
`FirebaseAuth.instance.signInWithCredential(PhoneAuthProvider.credential(...))`.

| Firebase Code | Domain Error | User Message | Recovery | Telemetry Code |
|---|---|---|---|---|
| `invalid-verification-code` | `AuthError.invalidOtp` | "That code does not match. Please check and try again." | Re-enter code. After 3 failed attempts, prompt "Request a new code". | `invalid_verification_code` |
| `session-expired` | `AuthError.sessionExpired` | "Your code has expired. Please request a new one." | Tap "Resend code" (respects 30 s cooldown per FR-AU-05). | `session_expired` |
| `invalid-verification-id` | `AuthError.sessionExpired` | "Your verification session has expired. Please request a new code." | Tap "Resend code". The stale `verificationId` is discarded. | `invalid_verification_id` |
| `credential-already-in-use` | `AuthError.credentialInUse` | "This phone number is already linked to another account. Please contact support." | Contact Support. | `credential_already_in_use` |
| `user-disabled` | `AuthError.userDisabled` | "Your account is currently unavailable. Please contact support for help." | Contact Support. Sign out. No retry. | `user_disabled` |
| `network-request-failed` | `AuthError.networkFailure` | "Could not connect. Please check your internet and try again." | Check connectivity, tap Verify again. | `network_request_failed` |
| `too-many-requests` | `AuthError.tooManyRequests` | "Too many attempts. Please wait a few minutes before trying again." | Wait; Contact Support link shown. | `too_many_requests` |
| `operation-not-allowed` | `AuthError.operationNotAllowed` | "Phone sign-in is not available at the moment. Please contact support." | Contact Support. No user-actionable retry. | `operation_not_allowed` |
| `internal-error` | `AuthError.unknown` | "Something went wrong. Please try again." | Tap Verify again. Contact Support after repeated failures. | `internal_error` |

### 1.3 Catch-All

Any `FirebaseAuthException.code` not listed above is mapped to
`AuthError.unknown` with the message "Something went wrong. Please try again."
and telemetry code set to the raw Firebase exception code string. This ensures
that unknown codes surface in telemetry without crashing the app.

Non-`FirebaseAuthException` exceptions (e.g. `PlatformException` from the method
channel) are also mapped to `AuthError.unknown`. The raw exception type and
message are logged to Crashlytics but never shown to the user.

### 1.4 Phone Change Phase (FR-PR-02 — `reauthenticateWithCredential` / `updatePhoneNumber`)

These errors can be thrown when re-verifying the current number
(`currentUser.reauthenticateWithCredential`) or applying the new number
(`currentUser.updatePhoneNumber`) in the change-phone flow. They are mapped by the
same `authErrorFromFirebaseCode` function used by sign-in.

| Firebase Code | Domain Error | User Message | Recovery | Telemetry Code |
|---|---|---|---|---|
| `requires-recent-login` | `AuthError.requiresRecentLogin` | "For your security, please verify your current number again before changing it." | The flow re-authenticates the current number first; surfaced only if re-authentication itself cannot complete. | `requiresRecentLogin` |
| `invalid-verification-code` | `AuthError.invalidOtp` | "That code does not match. Please check and try again." | Re-enter the code on the current step. | `invalidOtp` |
| `credential-already-in-use` | `AuthError.credentialInUse` | "This phone number is already linked to another account. Please contact support." | Contact Support; the new number belongs to another account. | `credentialInUse` |
| `session-expired` / `invalid-verification-id` | `AuthError.sessionExpired` | "Your code has expired. Please request a new one." | Request a new code for the current leg. | `sessionExpired` |

> The change-phone funnel logs `phone_change_failed` with `error_code` set to the
> `AuthError.name` (e.g. `requiresRecentLogin`), consistent with the
> `otp_send_failed` / `otp_verification_failed` convention. A failed Firestore
> users-doc sync after a successful auth update logs `error_code: sync_failed`.
> The phone number is never a telemetry parameter (SRS section 5.4).

---

## 2. AuthError Enum — Quick Reference

```
AuthError.invalidPhoneNumber
AuthError.tooManyRequests
AuthError.quotaExceeded
AuthError.networkFailure
AuthError.operationNotAllowed
AuthError.appNotAuthorised
AuthError.captchaFailed
AuthError.userDisabled
AuthError.invalidOtp
AuthError.sessionExpired
AuthError.credentialInUse
AuthError.requiresRecentLogin
AuthError.unknown
```

Each enum value exposes a `message` getter returning the user-facing string from
the tables above. The `message` getter is the single source of user-facing auth
error copy; controllers must not hard-code messages.

---

## 3. Telemetry Integration

Auth errors produce two analytics events, as defined in the telemetry plan
(`docs/design/07-technical/telemetry-plan.md`, section 1.2):

| Analytics Event | Phase | Parameter | Value |
|---|---|---|---|
| `otp_send_failed` | OTP request | `error_code` | Telemetry Code from section 1.1 |
| `otp_verification_failed` | OTP verification | `error_code` | Telemetry Code from section 1.2 |

The `error_code` parameter uses the Telemetry Code column (snake\_case, stable,
non-PII). It does not use the raw Firebase exception code to allow decoupling
from Firebase internals.

---

## Architect Notes — PR #7

### 1. Platform Reconciliation

The `firebase_auth` Flutter package exposes two APIs for phone authentication:

- **`verifyPhoneNumber`** — the native Flutter Firebase Auth API. Works on both
  Android and iOS. Provides callbacks: `verificationCompleted`, `verificationFailed`,
  `codeSent`, and `codeAutoRetrievalTimeout`. On Android, the SMS Retriever API may
  auto-read the OTP and trigger `verificationCompleted` without user interaction.
  On iOS, `verificationCompleted` is never called; the user must always enter the
  code manually.

- **`signInWithPhoneNumber`** — a web-only convenience method in `flutter_fire`.
  It is not available on native iOS or Android builds of Flutter. Do not use it.

**Decision:** use `verifyPhoneNumber` on both platforms. The repository layer
exposes a platform-agnostic public API (`requestOtp`, `verifyOtp`, `resendOtp`)
and handles platform differences internally:

- On Android: the `verificationCompleted` callback may fire with an
  `AuthCredential` that auto-signs the user in. The repository must surface this
  to the controller via a stream or callback so the OTP screen can skip manual
  entry and navigate forward. The `codeSent` callback provides a `resendToken`
  used for subsequent resend calls.

- On iOS: `verificationCompleted` never fires. The `codeSent` callback provides
  the `verificationId` needed for manual `signInWithCredential`. There is no
  `resendToken`; resend calls re-invoke `verifyPhoneNumber` without one.

- No `Platform.isAndroid` / `Platform.isIOS` branching is needed in the
  repository implementation. The `verifyPhoneNumber` method itself handles
  platform differences via the underlying method channel. The repository simply
  wires all four callbacks.

- The `autoRetrievedSmsCodeForTesting` parameter is only used when running
  against the Firebase Emulator Suite. It must not be set in production builds.
  Guard with `kDebugMode` or an emulator-detection flag.

### 2. VerificationSession Model

**Path:** `lib/features/auth/domain/verification_session.dart`

An immutable value object holding the state of an in-progress phone verification.

| Field | Type | Source | Purpose |
|---|---|---|---|
| `verificationId` | `String` | `codeSent` callback | Passed to `PhoneAuthProvider.credential` when verifying the OTP. |
| `resendToken` | `int?` | `codeSent` callback | Passed to subsequent `verifyPhoneNumber` calls for resend. Null on iOS. |
| `phoneNumber` | `String` | Caller | The E.164 formatted number (`+91XXXXXXXXXX`). Displayed on OTP screen. |
| `requestedAt` | `DateTime` | `DateTime.now()` at creation | Used by the controller to enforce the 30-second resend cooldown (FR-AU-05). |

Constraints:

- Use `@immutable` annotation and a `const` constructor.
- Override `==` and `hashCode` (or use `Equatable` / manual override).
- No methods beyond equality. No serialisation (this object is never persisted).
- The `verificationId` must never be persisted to `SharedPreferences` or any
  durable store. It lives only in memory for the duration of the auth flow.

### 3. AuthUser Model

**Path:** `lib/features/auth/domain/auth_user.dart`

A minimal immutable representation of the authenticated user, decoupled from the
Firebase `User` object.

| Field | Type | Source | Purpose |
|---|---|---|---|
| `uid` | `String` | `FirebaseAuth.currentUser!.uid` | Unique user identifier. Used as the Firestore document key. |
| `phoneNumber` | `String?` | `FirebaseAuth.currentUser!.phoneNumber` | The verified E.164 phone number. Null only if auth state is inconsistent. |

Constraints:

- Immutable, `const` constructor, override `==` and `hashCode`.
- No Firestore user-document fields here (display name, photo URL). Those belong
  to a `UserProfile` model created in PR #8 when the user document is written.
- A factory constructor `AuthUser.fromFirebaseUser(User user)` converts the
  Firebase SDK type to this domain type.

### 4. AuthError Enum

**Path:** `lib/features/auth/domain/auth_error.dart`

An exhaustive enum mapping Firebase error conditions to domain-level error
values.

```dart
/// Domain-level authentication error codes.
///
/// Each value corresponds to one or more `FirebaseAuthException.code`
/// values. The [message] getter returns user-facing copy in British
/// English. See `docs/design/07-technical/auth-error-codes.md` for the
/// full mapping table.
enum AuthError {
  invalidPhoneNumber,
  tooManyRequests,
  quotaExceeded,
  networkFailure,
  operationNotAllowed,
  appNotAuthorised,
  captchaFailed,
  userDisabled,
  invalidOtp,
  sessionExpired,
  credentialInUse,
  unknown;

  /// User-facing error message.
  ///
  /// This is the single source of user-facing auth error copy.
  /// Controllers must use this getter rather than hard-coding messages.
  String get message => switch (this) {
    invalidPhoneNumber =>
      'That phone number is not valid. Please check and try again.',
    tooManyRequests =>
      'Too many attempts. Please wait a few minutes before trying again.',
    quotaExceeded =>
      'We are unable to send codes right now. Please try again later.',
    networkFailure =>
      'Could not connect. Please check your internet and try again.',
    operationNotAllowed =>
      'Phone sign-in is not available at the moment. Please contact support.',
    appNotAuthorised =>
      'This app is not authorised for phone sign-in. Please contact support.',
    captchaFailed =>
      'Verification check failed. Please try again.',
    userDisabled =>
      'Your account is currently unavailable. Please contact support for help.',
    invalidOtp =>
      'That code does not match. Please check and try again.',
    sessionExpired =>
      'Your code has expired. Please request a new one.',
    credentialInUse =>
      'This phone number is already linked to another account. '
      'Please contact support.',
    unknown =>
      'Something went wrong. Please try again.',
  };
}
```

### 5. Repository Interface and Implementation

**Path:** `lib/features/auth/data/phone_auth_repository.dart`

#### 5.1 Abstract Interface

```dart
abstract class PhoneAuthRepository {
  /// Requests an OTP for the given [phoneNumber] (E.164 format).
  ///
  /// Returns a [VerificationSession] via the [codeSent] callback path.
  /// On Android, may also auto-verify via [verificationCompleted].
  ///
  /// Throws no exceptions. All errors are returned as [AuthError] in
  /// the result type.
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
  });

  /// Verifies the OTP [code] against the given [verificationId].
  ///
  /// On success, returns an [AuthUser].
  /// On failure, returns an [AuthError].
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  });

  /// Resends the OTP for an existing verification session.
  ///
  /// Accepts the [resendToken] from the previous [VerificationSession]
  /// (may be null on iOS).
  Future<void> resendOtp({
    required String phoneNumber,
    int? resendToken,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
  });

  /// Signs the current user out.
  Future<void> signOut();
}
```

#### 5.2 Implementation: `FirebasePhoneAuthRepository`

`FirebasePhoneAuthRepository implements PhoneAuthRepository`

- Constructor takes `FirebaseAuth` instance (defaults to
  `FirebaseAuth.instance`) for testability.
- The `requestOtp` method calls `FirebaseAuth.instance.verifyPhoneNumber` with
  all four callbacks wired.
- The `verifyOtp` method calls `FirebaseAuth.instance.signInWithCredential`
  with `PhoneAuthProvider.credential(verificationId: ..., smsCode: ...)`.
- Error mapping: a private `AuthError _mapException(FirebaseAuthException e)`
  method uses a `switch` on `e.code` to return the correct `AuthError` value.
  This is the single location where Firebase error codes are translated. See the
  mapping table in section 1 of this document.
- No generic `catch (e)` blocks. Catch `FirebaseAuthException` specifically.
  Any other exception type is caught, logged to Crashlytics, and mapped to
  `AuthError.unknown`.

#### 5.3 Riverpod Provider

```dart
final phoneAuthRepositoryProvider = Provider<PhoneAuthRepository>(
  (ref) => FirebasePhoneAuthRepository(),
);
```

Override in tests with a fake implementation to avoid Firebase initialisation.

#### 5.4 Result Type

Use a lightweight sealed `Result<T, E>` type (either inline in
`lib/core/result.dart` or from a package such as `result_dart` if already in
`pubspec.yaml`). The `verifyOtp` method returns
`Result<AuthUser, AuthError>` rather than throwing, keeping error handling
explicit and type-safe in the controller layer.

### 6. Invariant Compliance

| # | Invariant | Relevance to PR #7 |
|---|---|---|
| 1 | Money is integer paise | Not applicable — no monetary values in auth flow. |
| 2 | `simplifiedBalances` is server-only | Not applicable — no balance reads or writes. |
| 3 | System share sheet only | Not applicable — no sharing in auth flow. |
| 4 | Single Firebase project | Relevant. All testing runs against the Firebase Emulator Suite. The `autoRetrievedSmsCodeForTesting` parameter should be set only when the emulator is detected. No staging project. |

### 7. Scope Boundaries

- **PR #7 does:** wire Firebase Phone Auth to the existing phone-entry and OTP
  screens, create domain models (`VerificationSession`, `AuthUser`, `AuthError`),
  create `PhoneAuthRepository`, update controllers to call the repository, and
  log telemetry events (`otp_send_failed`, `otp_verification_failed`,
  `otp_send_succeeded`, `otp_verification_succeeded`, `otp_send_requested`).

- **PR #7 does not:** create the Firestore `users/{userId}` document (PR #8),
  implement profile setup (PR #8), implement auto-login on splash (future PR),
  or persist auth state beyond what Firebase Auth SDK handles natively.

### 8. Security Considerations

- Phone numbers are PII. They must not appear in analytics event parameters.
  Use a SHA-256 hash (`phone_hash`) when correlation is needed, as the existing
  `OtpEntryController` already does.
- The `verificationId` is a short-lived credential. It must not be logged,
  persisted to `SharedPreferences`, or sent to any backend other than Firebase
  Auth.
- The OTP code itself must never be logged or sent to analytics.
