# Profile

Feature-folder that owns the profile and settings surfaces: the profile
view and edit (FR-PR-01, SCR-26) and the notification-preferences
toggles (FR-PR-03, SCR-27). Sign-out is initiated here and delegated to
the notifications feature for FCM-token cleanup.

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
  OS-permission info banner when push is blocked, and a one-shot
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
presentation/
  profile_screen.dart                     # SCR-26 tab root
  edit_profile_screen.dart                # SCR-26 edit sub-screen
  notification_preferences_screen.dart    # SCR-27 toggles + banner + offline snackbar
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
- **Invariant 3 (system share sheet only):** N/A.
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
