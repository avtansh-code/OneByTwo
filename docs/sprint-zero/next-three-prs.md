# Next Three PRs

> Rolling roadmap. Replace this file after PR #8 with the next three.
> Last updated after PR #5.

---

## PR #6 — OTP Screen UI (FR-AU-03 partial, FR-AU-04 partial, FR-AU-05 partial)

**Scope:** OTP entry screen UI only. No Firebase Phone Auth wiring — the screen
renders, accepts 6-digit input, shows countdown timer, and transitions to a
placeholder success state. Firebase integration deferred to PR #7.

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FR-AU-03, FR-AU-04, FR-AU-05).

**Design artefacts:**
- Wireframe: `docs/design/04-wireframes/auth-flow.md` (section 4 — OTP Verification).
- Screen spec: `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-04).
- Mockup: `docs/design/05-mockups/02-phone-and-otp.html` (OTP half).

**Agents involved:** flutter-dev, qa.

**Carry-over fixes from PR #4 retro (to be included in PR #6):**
- Add `XXXXX XXXXX` visual formatting (space after 5th digit) to phone input.
- Add `autoFocus: true` to phone input `TextField`.
- Add `Semantics(header: true)` to phone entry heading.
- Add `Semantics(liveRegion: true)` to phone entry error text.
- Add isolated `PhoneEntryController` unit tests.
- Implement `phone_entry_viewed`, `phone_number_submitted`, `phone_validation_failed`
  telemetry events (SCR-03).

---

## PR #7 — Firebase Phone Auth Wiring (FR-AU-03, FR-AU-04, FR-AU-05 fully)

**Scope:** Wire Firebase Phone Auth end-to-end. Phone entry screen triggers
`verifyPhoneNumber`, OTP screen verifies the credential, loading and error states
are implemented, and the flow navigates to profile setup (new user) or home
(returning user). Create `lib/app/bootstrap.dart` for Firebase initialisation.

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FR-AU-03, FR-AU-04, FR-AU-05).

**Design artefacts:**
- Screen spec: `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md`
  (SCR-03 loading/error states, SCR-04 full).
- Telemetry: `docs/design/07-technical/telemetry-plan.md` (OTP events).

**Agents involved:** flutter-dev, devops (emulator integration tests), qa.

**Key deliverables:**
- `lib/app/bootstrap.dart` — Firebase initialisation with test-mode bypass.
- Integration test running against Firebase Auth Emulator.
- Loading state on Continue button (circular progress indicator).
- Error mapping from Firebase error codes to user-friendly messages.
- SMS Retriever (Android) and keyboard autofill (iOS) support.

---

## PR #8 — Profile Setup Screen and User Document Creation (FR-AU-06)

**Scope:** First-time user profile setup screen. Display name (required) and
profile photo (optional). Creates the `users/{userId}` Firestore document on
submit. Returning users bypass this screen (FR-AU-07 partial).

**User story:** `docs/sprint-zero/sprint-1-plan.md` (FR-AU-06).

**Design artefacts:**
- Wireframe: `docs/design/04-wireframes/auth-flow.md` (section 5 — Profile Setup).
- Screen spec: `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-05).
- Firestore schema: `docs/design/07-technical/firestore-schema.md` (users collection).

**Agents involved:** flutter-dev, architect (schema review), qa.

**Key deliverables:**
- Profile setup screen with display name validation.
- Firestore `users/{userId}` document creation.
- Photo picker using system image picker (no third-party crop library in v1.0).
- Navigation: profile setup -> home (new user), auth -> home (returning user).
