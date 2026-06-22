# Auth

Feature-folder that owns phone-number authentication and first-login
onboarding (FR-AU): phone entry and OTP request, OTP verification, and
profile setup. It also defines the app-wide auth gate and a couple of
app-scoped dependency-injection providers that the rest of the app
depends on.

## Implemented scope

### Auth gate and app-scoped providers

- `application/auth_state_provider.dart` — `authStateProvider`
  (`StreamProvider<AuthState>`). Combines `FirebaseAuth.authStateChanges()`
  with a snapshot listener on `users/{uid}` (switchMap semantics; the
  cached token is validated via `User.reload`) and emits the sealed
  `AuthState`. This is the root of the auth gate consumed by
  `OneBytwoApp` in `lib/main.dart`. The file also exposes
  `firebaseAuthProvider` (`Provider<FirebaseAuth>`).
- `application/analytics_provider.dart` — the `AnalyticsService`
  abstraction, `FirebaseAnalyticsService`, and `analyticsServiceProvider`
  (`Provider<AnalyticsService>`). This is the shared analytics seam used
  by every feature; tests override it with a fake.
- `data/user_repository.dart` — the `UserRepository` and
  `userRepositoryProvider`. Reads/writes `users/{uid}` and handles avatar
  upload to Firebase Storage. (The shared `firebaseFirestoreProvider` and
  `firebaseStorageProvider` now live in `lib/core/providers/`.)

### Sign-in flow (FR-AU)

- `domain/auth_state.dart` — the sealed `AuthState`: `AuthLoading`,
  `AuthUnauthenticated`, `AuthenticatedNoProfile`,
  `AuthenticatedWithProfile`. These four arms map one-to-one to the home
  screen chosen in `OneBytwoApp.build`.
- `domain/auth_error.dart` — the `AuthError` codes that map
  `FirebaseAuthException.code` values to British-English user-facing copy
  (see `docs/design/07-technical/auth-error-codes.md`).
- `domain/auth_user.dart` — a minimal, framework-agnostic
  authenticated-user value object.
- `domain/user_model.dart` — `UserModel`, the domain model for the
  `users/{uid}` document (schema in
  `docs/design/07-technical/firestore-schema.md`).
- `domain/verification_session.dart` — `VerificationSession`, the
  in-memory value returned by the `codeSent` callback.
- `data/phone_auth_repository.dart` — the abstract `PhoneAuthRepository`
  over Firebase Phone Auth (the `phoneAuthRepositoryProvider` now lives in
  `lib/core/providers/`). Errors
  are returned as `AuthError` values rather than thrown; supports
  Android SMS-Retriever auto-verification.
- `application/phone_entry_controller.dart` — `PhoneEntryController`
  (`StateNotifier<PhoneEntryState>`, `phoneEntryControllerProvider`):
  10-digit Indian-mobile input validation and OTP request.
- `application/otp_entry_controller.dart` — `OtpEntryController`
  (`StateNotifier<OtpEntryState>`,
  `otpEntryControllerProvider`, auto-disposing): the six OTP cells,
  auto-read, retry handling and verification.
- `application/profile_setup_controller.dart` — `ProfileSetupController`
  (`StateNotifier<ProfileSetupState>`,
  `profileSetupControllerProvider`, auto-disposing): display name and
  optional photo for first-login onboarding (SCR-05).

### Screens

- `presentation/splash_screen.dart` — `SplashScreen` (`AuthLoading`).
- `presentation/phone_entry_screen.dart` — `PhoneEntryScreen`
  (`AuthUnauthenticated`).
- `presentation/otp_entry_screen.dart` — `OtpEntryScreen`, with
  `presentation/widgets/otp_input.dart` (`OtpInput`).
- `presentation/profile_setup_screen.dart` — `ProfileSetupScreen`
  (`AuthenticatedNoProfile`).
- `presentation/authenticated_screen.dart` — `AuthenticatedScreen`, an
  early debug stub that simply shows the UID. It is **not** wired into
  the live auth gate (which routes `AuthenticatedWithProfile` to
  `AuthenticatedShell`); retained only as a legacy artefact.

## Layout

```
application/
  analytics_provider.dart       # AnalyticsService seam (app-wide)
  auth_state_provider.dart      # authStateProvider + firebaseAuthProvider
  otp_entry_controller.dart     # OtpEntryController (autoDispose)
  phone_entry_controller.dart   # PhoneEntryController
  profile_setup_controller.dart # ProfileSetupController (autoDispose)
data/
  phone_auth_repository.dart    # PhoneAuthRepository over Firebase Phone Auth
  user_repository.dart          # users/{uid} read/write + avatar upload
domain/
  auth_error.dart               # AuthError codes → British-English copy
  auth_state.dart               # sealed AuthState (4 arms)
  auth_user.dart                # framework-agnostic auth user
  user_model.dart               # users/{uid} domain model
  verification_session.dart     # in-progress verification value
presentation/
  splash_screen.dart            # AuthLoading
  phone_entry_screen.dart       # AuthUnauthenticated
  otp_entry_screen.dart         # OTP verification
  profile_setup_screen.dart     # AuthenticatedNoProfile (SCR-05)
  authenticated_screen.dart     # legacy debug stub (not on the live gate)
  widgets/
    otp_input.dart              # six-cell OTP input
```

## Invariants honoured

- **Invariant 1 (integer paise):** N/A — auth handles no monetary
  values.
- **Invariant 2 (`simplifiedBalances` server-maintained):** the user-doc
  listener and `UserRepository` read/write profile fields on
  `users/{uid}`; they never touch `simplifiedBalances`.
- **Invariant 3 (system share sheet only):** N/A.
- **Invariant 4 (single Firebase project):** all auth and Firestore
  reads/writes go through the single production project; the Auth and
  Firestore emulators (wired in `main.dart` behind `--dart-define`) are
  used for non-production testing.

## Hand-off boundaries

- **Out (gate):** `lib/main.dart` (`OneBytwoApp`) watches
  `authStateProvider` and routes each `AuthState` arm to its
  screen, mounting `AuthenticatedShell` (shell feature) for
  `AuthenticatedWithProfile`.
- **In (shared):** `analyticsServiceProvider` and `userRepositoryProvider`
  are consumed across the app (notifications, profile, expenses, etc.).
  The shared Firebase DI providers (`firebaseFirestoreProvider`,
  `firebaseStorageProvider`) and `phoneAuthRepositoryProvider` were
  relocated to `lib/core/providers/` (M4).
- **Out (cleanup):** sign-out from the profile screen routes through
  `signOutWithFcmCleanup` (notifications feature), which unregisters the
  FCM token before calling `PhoneAuthRepository.signOut`.
