# FR-PR-01: View and Edit Profile

> Implementation-ready user story for the Profile View and Edit Profile screens.
> Covers displaying the user's profile, editing the display name, changing the
> profile photo, and integration with the existing sign-out flow.

---

## SRS Requirement ID(s)

FR-PR-01 (SRS section 4.2)

## Priority

**P0 — Must have**

## Story Points

5

## User Story

As a **signed-in user**,
I want to **view my profile and edit my display name and photo**
so that **other users see my preferred identity**.

## Preconditions

1. User is authenticated and has a `users/{userId}` document in Firestore
   (FR-AU-06 delivered in PR #10).
2. The sign-out flow is functional (FR-AU-08 delivered in PR #11).

---

## Acceptance Criteria

### AC-1 — Profile View displays current data

> Given the user is signed in and has a `users/{userId}` document
> When they navigate to the Profile screen (tab index 4)
> Then their current display name (`titleLarge`, `textPrimary`) and phone number
> (`bodyMedium`, `textSecondary`, read-only) are shown
> And their profile photo is displayed via `OBTUserAvatar` (96 dp); if
> `photoUrl` is `null`, a default initials avatar is rendered
> And the `profile_viewed` telemetry event fires

### AC-2 — Edit display name (happy path)

> Given the user is on the Profile View screen
> When they tap the "Edit Profile" row, edit the display name to a valid value
> (e.g., "Riya"), and tap Save
> Then the `users/{userId}` document is updated in Firestore with the new
> `displayName` and a fresh `updatedAt` server timestamp
> And an `OBTSnackbar(message: "Profile updated", type: success)` is shown
> And the user is navigated back to the Profile View, which reflects the new name
> And the `profile_edited` telemetry event fires with
> `fields_changed: ["displayName"]`

### AC-3 — Change profile photo (happy path)

> Given the user is on the Edit Profile screen
> When they tap the avatar, select "Choose from Gallery" from the photo picker
> bottom sheet, and pick a new image
> Then the image is uploaded to Firebase Storage at `avatars/{userId}`
> And the `users/{userId}` document is updated with the new `photoUrl` download
> URL and a fresh `updatedAt` server timestamp
> And the new photo is reflected on both the Edit Profile screen and, upon
> navigating back, the Profile View
> And the `profile_photo_changed` telemetry event fires with
> `action: "choose"`

### AC-4 — Photo upload failure (negative / error path)

> Given the user has selected a new photo from the picker
> When the Firebase Storage upload fails (network error, timeout, etc.)
> Then the previous `photoUrl` on the `users/{userId}` document remains unchanged
> And an `OBTSnackbar(message: "Photo upload failed. Try again.", type: error)`
> is shown
> And the avatar reverts to its previous state (the existing photo is not
> destroyed by a failed replacement)
> And the user can retry by tapping the avatar again

### AC-5 (Negative) — Empty display name blocked

> Given the user is on the Edit Profile screen
> When they clear the display name field or enter only whitespace characters
> Then an inline error is displayed below the field: "Display name cannot be
> empty." (in `danger` colour)
> And the Save button is disabled
> And no Firestore write occurs

### AC-6 (Negative) — Display name exceeds 50 characters

> Given the user is on the Edit Profile screen
> When they enter a display name longer than 50 characters
> Then an inline error is displayed below the field: "Display name must be 50
> characters or fewer." (in `danger` colour)
> And the Save button is disabled
> And no Firestore write occurs

### AC-7 (Negative / Security) — Immutable fields rejected by Security Rules

> Given an attacker with a valid auth token crafts a Firestore SDK write to their
> own `users/{userId}` document that attempts to modify `phoneNumber` or
> `createdAt`
> When the write request reaches Firestore
> Then the Firestore Security Rules reject the write
> And the document remains unchanged
> (Verified by Firestore Security Rules unit tests running against the emulator.)

### AC-8 — Sign Out integration from Profile screen

> Given the user is on the Profile View screen
> When they tap the "Sign Out" row
> Then the existing sign-out flow (FR-AU-08, PR #11) executes: the confirmation
> dialog is presented, and upon confirmation, `firebase_auth.signOut()` is called,
> the app navigates to the Phone Entry screen with no authenticated screens in the
> route stack
> And the `sign_out_completed` telemetry event fires

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `profile_viewed` | -- | Profile View screen mounts |
| `profile_edited` | `fields_changed` (array of changed field names) | Profile saved successfully |
| `profile_photo_changed` | `action` (`"choose"`, `"take"`, `"remove"`) | Photo change completed successfully |

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
- [ ] Firestore Security Rules tests verify AC-7 (immutable fields rejection).
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
| Screen spec | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-26) |
| Wireframe — Profile View | `docs/design/04-wireframes/profile-and-support.md` (section 1) |
| Wireframe — Edit Profile | `docs/design/04-wireframes/profile-and-support.md` (section 2) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`users/{userId}`) |
| State management | `docs/design/07-technical/state-management.md` |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Profile View screen, Edit Profile screen, photo picker, validation, state management |
| Architect | Security Rules for field-level update restrictions, Storage rules for `avatars/{userId}` |
| Functions Dev | Firestore Security Rules tests (AC-7) |
| QA | Test plan execution, acceptance criteria verification |
| Designer | Visual review, accessibility sign-off |

---

## Implementation Notes

- **Profile View layout** follows the four-section structure defined in SCR-26:
  profile header (avatar 96 dp, display name, phone number), stats section (My
  Friends count, My Groups count), actions section (Edit Profile, Notification
  Preferences, Contact Support), destructive section (Sign Out, Delete Account).
  Sections are separated by full-bleed 1 dp dividers.
- **Edit Profile** is a pushed sub-screen at `/profile/edit` with `OBTAppBar`
  (back button) and hidden bottom nav. The Save button is disabled when no
  changes have been made or the display name is empty/invalid.
- Per ADR-0008, profile updates are client-side Firestore writes. The client
  calls `update()` on the `users/{userId}` document with only the changed fields
  plus a fresh `updatedAt` server timestamp.
- **Firestore Security Rules** must enforce that `phoneNumber` and `createdAt`
  are immutable after document creation. An `update` rule should verify that
  `request.resource.data.phoneNumber == resource.data.phoneNumber` and
  `request.resource.data.createdAt == resource.data.createdAt`.
- **Photo picker bottom sheet** offers "Take Photo", "Choose from Gallery", and
  "Remove Photo" (visible only when `photoUrl` is non-null; uses `danger`
  colour). Corner radius: 24 dp top corners.
- **Photo upload** overwrites the existing file at `avatars/{userId}` in Firebase
  Storage. The new download URL is written to `photoUrl` on the user document. If
  the upload fails, the previous `photoUrl` is preserved — the client must not
  clear `photoUrl` before a successful upload completes.
- **Photo validation:** maximum file size 5 MB; accepted formats JPEG and PNG.
  Large images should be compressed/resized client-side before upload (consistent
  with FR-AU-06 behaviour). Oversized or unsupported files show inline errors per
  SCR-26 input validation table.
- **Display name** is trimmed before submission. Validation: minimum 1
  non-whitespace character, maximum 50 characters.
- **Loading state** uses `OBTSkeletonLoader` with shimmer animation: 96 dp circle
  shimmer for avatar, text bar shimmers, row shimmers (per wireframe section 1.3).
- **Error state** uses `OBTErrorState` with title "Something went wrong",
  subtitle "We could not load your profile. Check your connection and try again.",
  Retry button, and "Contact Support" link.
- The `OBTUserAvatar` component renders the profile photo or an initials fallback
  when `photoUrl` is `null`.
- Concurrent edits on multiple devices follow last-write-wins semantics (FR-OF-03).
  The real-time Firestore listener on the Profile View reflects the latest data
  when the user navigates back.

---

## Out of Scope

- Phone number change (FR-PR-02, P1) — the phone number field on the Edit Profile
  screen is read-only with hint text "Phone number cannot be changed from here."
- Notification Preferences screen (FR-PR-03, P1) — the row is rendered but
  navigates to a separate story.
- Delete Account flow (FR-AU-09, P1) — the row is rendered but functionality is a
  separate story.
- Friends and groups count values — the rows are rendered but counts are populated
  by their respective feature stories (FR-FR-xx, FR-GR-xx).

---

## Dependencies

| Dependency | Status |
|---|---|
| PR #10 — Profile setup (FR-AU-06) | Merged |
| PR #11 — Sign out (FR-AU-08) | Merged |
| Firestore Security Rules for `users/{userId}` update restrictions | Required (Architect) |
| Firebase Storage rules for `avatars/{userId}` | Required (Architect) |