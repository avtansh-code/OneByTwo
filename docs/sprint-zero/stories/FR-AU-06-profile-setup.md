# FR-AU-06: Profile Setup on First Login

> Implementation-ready user story for the profile setup screen.
> Covers display name entry, optional photo upload, and Firestore user document
> creation.

---

## SRS Requirement ID(s)

FR-AU-06 (SRS section 4.1)

## Priority

**P0 — Must have**

## Story Points

5

## User Story

As a **first-time user who has just verified my phone number**,
I want to **be prompted to enter my display name and optionally upload a profile
photo**
so that **my friends can recognise me in the app**.

## Preconditions

1. User has successfully completed phone number verification (FR-AU-03/04/05).
2. No `users/{userId}` document exists in Firestore for this user.

---

## Acceptance Criteria

### Scenario 1 — Happy path (name only)

> Given a first-time user has just verified their phone number
> When they enter a valid display name (e.g., "Avtansh") and tap Continue without
> adding a photo
> Then a `users/{userId}` document is created in Firestore with `displayName`,
> `phoneNumber`, `photoUrl: null`, `fcmTokens: []`, `createdAt`, `updatedAt`,
> `notificationPrefs` (defaults), `locale: 'en-IN'`
> And the user is navigated to the Home placeholder screen
> And `profile_save_succeeded` telemetry event fires with `has_photo: false`

### Scenario 2 — Happy path (name + photo)

> Given a first-time user is on the profile-setup screen
> When they enter a valid display name, select a photo from gallery, and tap
> Continue
> Then the photo is uploaded to Firebase Storage at `avatars/{userId}`
> And the `users/{userId}` document is created with `photoUrl` set to the Storage
> download URL
> And the user is navigated to the Home placeholder screen
> And `profile_save_succeeded` fires with `has_photo: true`

### Scenario 3 — Returning user skips setup

> Given a user has previously completed profile setup (user doc exists with
> `displayName` set)
> When they complete phone verification again
> Then they are navigated directly to the Home placeholder screen, bypassing
> profile setup

### Scenario 4 — Negative: empty display name

> Given the user is on the profile-setup screen
> When they tap Continue with an empty or whitespace-only display name
> Then the Continue button remains disabled (or shows error "Please enter your
> name.")
> And no Firestore write occurs
> And `profile_save_failed` does NOT fire (validation is client-side only)

### Scenario 5 — Negative: display name too long

> Given the user is on the profile-setup screen
> When they enter a display name longer than 50 characters
> Then an error message "Name must be 50 characters or fewer." is shown
> And the Continue button is disabled

### Scenario 6 — Negative: photo upload failure

> Given the user has selected a photo and entered a valid display name
> When the photo upload to Firebase Storage fails
> Then the user document is still created without a photo (`photoUrl: null`)
> And the user is navigated to the Home placeholder screen
> And `profile_save_failed` fires with `error_source: 'storage'`
> And `profile_save_succeeded` still fires after the doc write succeeds

### Scenario 7 — Negative: offline during save

> Given the user has entered a valid display name and is offline
> When they tap Continue
> Then a snackbar error "No internet connection. Check your network and try
> again." is shown
> And the form fields are re-enabled for retry
> And `profile_save_failed` fires with `error_code: 'offline'`

---

## Telemetry Events

| Event name | Trigger | Parameters |
|---|---|---|
| `profile_setup_viewed` | Screen mounts | `source` |
| `profile_photo_picker_opened` | User taps the avatar or camera badge | -- |
| `profile_photo_selected` | User selects a photo from camera or gallery | `source` |
| `profile_photo_skipped` | User taps Continue without selecting a photo | -- |
| `profile_save_requested` | User taps Continue with valid input | `has_photo`, `name_length` |
| `profile_save_succeeded` | Firestore write (and optional upload) completes | `duration_ms`, `has_photo` |
| `profile_save_failed` | Firestore write or Storage upload fails | `error_code`, `error_source` |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary values in this story. |
| 2 | `simplifiedBalances` server-maintained | N/A. This story does not touch `simplifiedBalances`. |
| 3 | System share sheet only | N/A. No sharing in this story. |
| 4 | Single Firebase project | Applicable. All code targets the single production Firebase project. Testing uses Firebase Emulator Suite per ADR-0003. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — N/A.
- [ ] Uses system share sheet only (invariant 3) — N/A.
- [ ] Single Firebase project (invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-05) |
| Wireframe | `docs/design/04-wireframes/auth-flow.md` (section 5) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`users/{userId}`) |
| State management | `docs/design/07-technical/state-management.md` (section 2.2) |
| Telemetry | `docs/design/07-technical/telemetry-plan.md` (section 1.2) |

---

## Implementation Notes

- The `profileSetupNotifierProvider` (an `@riverpod AsyncNotifier`, auto-disposing)
  manages display name input and optional photo upload. See
  `docs/design/07-technical/state-management.md` section 2.2.
- Per ADR-0008, the profile-setup screen writes the full `users/{userId}` document
  via a single Firestore `set()` call. No Cloud Function is involved.
- The profile photo should be uploaded sequentially before the Firestore document
  write so the `photoUrl` is available at document creation time. If the upload
  fails, the document is created with `photoUrl: null` (graceful degradation per
  scenario 6).
- The display name is trimmed before submission. Validation: minimum 1
  non-whitespace character, maximum 50 characters (SCR-05 input constraints).
- Navigation from this screen uses `replace` — there is no back navigation to the
  OTP screen (site-map section 2.1).
- The `OBTUserAvatar` component (component catalogue entry 11, 80 dp diameter)
  displays the selected photo or an initials fallback. The `OBTSnackbar` component
  (catalogue entry 25, type `error`) is used for save-failure feedback.
- Photo compression: large images are compressed/resized client-side to a maximum
  upload size of 1 MB before uploading to Firebase Storage (SCR-05, edge case 1).
- All Firestore fields for the `users/{userId}` document are documented in
  `docs/design/07-technical/firestore-schema.md`. Extension-point field `locale`
  must be explicitly written at creation time per ARCH-EXT-04.
