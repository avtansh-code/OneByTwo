# Profile

Feature-folder that owns the profile and settings surfaces: the profile
view and edit (FR-PR-01, SCR-26), the notification-preferences
toggles (FR-PR-03, SCR-27), and the Contact Support `mailto:` flow
(FR-PR-05 / FR-SH-03 / FR-SH-04). Sign-out is initiated here and
delegated to the notifications feature for FCM-token cleanup.

## Implemented scope

### FR-PR-01 — Profile view and edit

- `presentation/profile_screen.dart` — `ProfileScreen`
  (`ConsumerStatefulWidget`), the SCR-26 tab-root screen. Shows the
  authenticated user's info and entry points to Edit Profile,
  Notification Preferences, and Sign Out. Fires `profile_viewed` on
  mount.
- `presentation/edit_profile_screen.dart` — `EditProfileScreen`, the
  display-name and photo editor.
- `application/edit_profile_controller.dart` — `EditProfileController`
  (`StateNotifier<EditProfileState>`, `editProfileControllerProvider`,
  auto-disposing). Validates the display name, manages photo selection /
  removal (5 MB cap; `.jpg` / `.jpeg` / `.png`), and persists via
  `UserRepository` (auth feature) and `ImagePickerService` (core).
- `presentation/widgets/photo_picker_sheet.dart` — `PhotoPickerSheet`
  and the `PhotoPickerAction` enum (`takePhoto` / `chooseFromGallery` /
  `removePhoto`).

### FR-PR-03 — Notification preferences

- `presentation/notification_preferences_screen.dart` —
  `NotificationPreferencesScreen` (SCR-27): the per-category toggles, an
  OS-permission info banner (with an "Open Settings" CTA that deep-links
  to the OS notification settings via `appSettingsServiceProvider`,
  AC-11 / ADR-0019) when push is blocked, and a one-shot
  "You are offline" snackbar.
- `application/notification_preferences_controller.dart` — the sealed
  `NotificationPreferencesState` (`Loading` / `Error` / `Ready`) and
  `NotificationPreferencesController` (`StateNotifier`,
  `notificationPreferencesControllerProvider`, auto-disposing). Toggles
  are optimistic and debounced; the `offlineWriteJustQueued` one-shot
  signal is latched the first time a flip happens while offline,
  detected via `connectivityCheckProvider` (core).
- `application/notification_preferences_telemetry.dart` — the event /
  parameter / token constants: `notification_prefs_viewed`,
  `notification_pref_changed`, `notification_pref_error`; categories
  `newExpense` / `settlement` / `reminder`; error codes
  `firestore-error` / `network` / `unknown`.

### FR-PR-05 / FR-SH-03 / FR-SH-04 — Contact Support (mailto)

- `presentation/profile_screen.dart` — both Contact Support entry points
  (the "Contact Support" action row and the error-state "Still stuck?
  Contact Support" link) call `_contactSupport`, which invokes
  `contactSupportControllerProvider` and, on a fallback result, shows the
  FR-SH-04 dialog.
- `application/contact_support_controller.dart` — the sealed
  `ContactSupportResult` (`ContactSupportLaunched` /
  `ContactSupportFallbackRequired`) and `ContactSupportController`
  (`contactSupportControllerProvider`). Resolves the support address from
  Remote Config, assembles the diagnostic `mailto:` URI (canonical
  subject/body + `Uri.encodeComponent` encoding), launches the default
  mail client, and fires `support_email_opened`. Declares
  `dependencies: [currentUserIdProvider]` so the shell-scoped UID
  resolves on the Profile screen.
- `application/contact_support_telemetry.dart` — `support_email_opened`
  event and its single PII-free `method` parameter (`mailto` /
  `fallback_dialog`).
- `presentation/contact_support_fallback_dialog.dart` —
  `ContactSupportFallbackDialog` (FR-SH-04): selectable address, "Copy
  Address" (clipboard + "Email address copied" snackbar) and "Close".
- `data/device_diagnostics_service.dart` — `DeviceDiagnosticsService` +
  the `package_info_plus` / `device_info_plus`-backed implementation.
- `domain/support_diagnostics.dart` — the immutable `SupportDiagnostics`
  value object (app version, build, OS name/version, device model).
- Shared (core): `RemoteConfigService` (`lib/core/remote_config/`, the
  app's first Remote Config consumer per ADR-0006) and
  `UrlLauncherService` (`lib/core/services/`).

### FR-AU-09 — Account deletion (SCR-28 Part B)

- `presentation/profile_screen.dart` — the "Delete Account" row calls
  `_openDeleteAccount`, which pushes `DeleteAccountScreen` and, on a
  `DeleteAccountOutcome.failed` result, shows the error snackbar whose
  "Contact Support" action reuses the FR-PR-05 `_contactSupport` flow.
- `presentation/delete_account_screen.dart` — `DeleteAccountScreen`, the
  single full-screen route whose body switches by `DeleteAccountStep`:
  Step A warning, Step B re-authentication (reusing the auth `OtpInput`
  and the FR-PR-02 `PhoneAccountRepository`), Step C type-`DELETE`
  confirmation, Step D processing (back blocked via `PopScope`, 30s
  timeout), Step E success (3s, then sign-out). Returns
  `DeleteAccountOutcome.failed` to Profile on a Step D failure / timeout.
- `application/delete_account_controller.dart` — `DeleteAccountController`
  (`deleteAccountControllerProvider`, autoDispose), the five-step state
  machine. Re-auth reuses `PhoneAccountRepository` (never
  `signInWithCredential`); the cascade runs in the `deleteUserAccount`
  callable; on success it signs out so the root auth gate clears the stack
  to Phone Entry (ADR-0016).
- `application/delete_account_telemetry.dart` — the seven PII-free
  `delete_account_*` event-name constants (only `delete_account_failed`
  carries an `error_code`).
- `data/delete_account_repository.dart` — `DeleteAccountRepository` +
  `DeleteAccountCallable` typedef + `DeleteAccountException`. The
  `deleteAccountRepositoryProvider` is overridden in `main.dart`; tests
  inject a fake callable.
- `data/delete_account_callable_adapter.dart` — `DeleteAccountCallableAdapter`,
  the only profile file importing `cloud_functions`; translates
  `FirebaseFunctionsException` to `DeleteAccountException`.

### Legacy stub

- `presentation/profile_placeholder_screen.dart` —
  `ProfilePlaceholderScreen`, an early sign-out stub superseded by
  `ProfileScreen`. Not wired into the live navigation; retained as a
  legacy artefact.

## Layout

```
application/
  edit_profile_controller.dart            # EditProfileController (autoDispose)
  notification_preferences_controller.dart # sealed state + StateNotifier (autoDispose)
  notification_preferences_telemetry.dart  # FR-PR-03 event/param/token constants
  contact_support_controller.dart         # FR-PR-05 sealed result + controller
  contact_support_telemetry.dart          # FR-PR-05 support_email_opened (no PII)
  delete_account_controller.dart          # FR-AU-09 five-step state machine (autoDispose)
  delete_account_telemetry.dart           # FR-AU-09 seven delete_account_* events (no PII)
data/
  device_diagnostics_service.dart         # FR-PR-05 package_info_plus + device_info_plus
  delete_account_repository.dart           # FR-AU-09 callable repo + typed exception
  delete_account_callable_adapter.dart     # FR-AU-09 cloud_functions -> typedef shim
domain/
  support_diagnostics.dart                # FR-PR-05 immutable diagnostics value object
presentation/
  profile_screen.dart                     # SCR-26 tab root
  edit_profile_screen.dart                # SCR-26 edit sub-screen
  notification_preferences_screen.dart    # SCR-27 toggles + banner + offline snackbar
  contact_support_fallback_dialog.dart    # FR-SH-04 no-mail-client dialog
  delete_account_screen.dart              # SCR-28 Part B five-step deletion flow
  profile_placeholder_screen.dart         # legacy sign-out stub (not on the live nav)
  widgets/
    photo_picker_sheet.dart               # PhotoPickerSheet + PhotoPickerAction
```

## Invariants honoured

- **Invariant 1 (integer paise):** N/A — profile handles no monetary
  values.
- **Invariant 2 (`simplifiedBalances` server-maintained):** the
  controllers read/write profile fields and `notificationPrefs` on
  `users/{uid}` only; they never touch `simplifiedBalances`.
- **Invariant 3 (system share sheet only):** N/A to sharing, and the
  Contact Support flow does NOT change that. A `mailto:` URI opens the
  device's default mail client (FR-SH-03) and targets no specific app; it
  must never route through `ShareService` / `share_plus`, which is the
  FR-SH-01 invite/share path.
- **Invariant 4 (single Firebase project):** all reads/writes go through
  the single production project; offline behaviour is detected via the
  one-shot `connectivityCheckProvider`, and the Firestore SDK queues the
  preference write until reconnection.

## Hand-off boundaries

- **In (host):** `ProfileScreen` is tab 4 of `AuthenticatedShell` (shell
  feature).
- **In (shared):** profile reads/writes and avatar upload reuse
  `UserRepository` / `firebaseStorageProvider` (auth feature) and
  `ImagePickerService` (core).
- **Out (sign-out):** the Sign Out action calls `signOutWithFcmCleanup`
  (notifications feature), which unregisters the device's FCM token
  before `PhoneAuthRepository.signOut`.
