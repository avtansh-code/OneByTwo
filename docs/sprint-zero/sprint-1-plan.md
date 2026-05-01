# Sprint 1 Plan

## Sprint Goal

Establish a fully authenticated user entry path (phone OTP login through profile
setup) with the foundational Firebase infrastructure, CI pipeline, and the
simplified-debts contract stub so that all subsequent feature sprints can build on
a proven, tested base.

---

## Selected Stories

### FR-AU-01: Phone Number Login with Locked +91 Prefix

- **Priority:** P0
- **User Story:** As a new or returning user, I want to sign in using my Indian
  mobile phone number so that I can access the app without needing an email or
  password.
- **Acceptance Criteria:**
  1. **Given** the user opens the app for the first time, **When** the login
     screen loads, **Then** the country code field displays "+91" and is not
     editable.
  2. **Given** the user enters a valid 10-digit mobile number and taps
     "Continue", **When** the request is sent, **Then** the app navigates to the
     OTP entry screen and a 6-digit OTP is dispatched via SMS (FR-AU-03).
  3. **Given** the user enters an empty phone number or only whitespace, **When**
     they tap "Continue", **Then** the app displays an inline validation error
     and does not trigger an OTP request.
- **Definition of Done:** Code merged to `main`, unit and widget tests passing in
  CI, QA verified on both iOS simulator and Android emulator against the Firebase
  Auth Emulator, telemetry event `signup_started` fires, screen documented in
  design system.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 3

---

### FR-AU-02: Indian Mobile Number Validation

- **Priority:** P0
- **User Story:** As a user, I want the app to reject invalid phone numbers
  before sending an OTP so that I do not waste time waiting for an SMS that will
  never arrive.
- **Acceptance Criteria:**
  1. **Given** the user enters a 10-digit number starting with 6, 7, 8, or 9,
     **When** they tap "Continue", **Then** the input is accepted and the OTP
     flow begins.
  2. **Given** the user enters a number with fewer than 10 digits, **When** they
     tap "Continue", **Then** an inline error "Enter a valid 10-digit mobile
     number" is displayed and no OTP request is made.
  3. **Given** the user enters a 10-digit number starting with 0, 1, 2, 3, 4, or
     5, **When** they tap "Continue", **Then** the number is rejected with the
     same inline error (negative case — invalid Indian mobile prefix).
  4. **Given** the user enters alphabetic or special characters, **When** they
     type, **Then** the input field strips non-numeric characters and only digits
     are retained.
- **Definition of Done:** Code merged, unit tests for all validation branches
  passing, widget test confirms error rendering, QA verified.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 2

---

### FR-AU-03: OTP Dispatch via Firebase Phone Auth

- **Priority:** P0
- **User Story:** As a user who has entered a valid phone number, I want the app
  to send me a 6-digit OTP via SMS so that I can verify my identity.
- **Acceptance Criteria:**
  1. **Given** a valid +91 number is submitted, **When** Firebase Phone Auth is
     called, **Then** the user receives a 6-digit OTP via SMS and the app
     transitions to the OTP entry screen showing a 30-second countdown timer.
  2. **Given** the user submits the correct OTP, **When** Firebase verifies it,
     **Then** the user is authenticated and a Firebase Auth session is created.
  3. **Given** the user submits an incorrect OTP, **When** Firebase rejects it,
     **Then** the app displays an error "Invalid OTP. Please try again." and
     allows the user to re-enter (negative case).
  4. **Given** the Firebase Auth Emulator is running, **When** the OTP flow is
     triggered in debug mode, **Then** the app uses the emulator endpoint
     (localhost / 10.0.2.2) and not production Firebase.
- **Definition of Done:** Code merged, unit tests with mocked Firebase Auth
  passing, integration test against Auth Emulator passing, QA verified on both
  platforms.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 5

---

### FR-AU-04: OTP Auto-Read (Android) and Manual Entry (iOS)

- **Priority:** P0
- **User Story:** As an Android user, I want the app to auto-read the OTP from my
  SMS so that I can log in without manually typing the code; as an iOS user, I
  want a clear manual entry field.
- **Acceptance Criteria:**
  1. **Given** the user is on Android and SMS Retriever is available, **When** the
     OTP SMS arrives, **Then** the app auto-fills the 6-digit code and proceeds
     to verification without user action.
  2. **Given** the user is on iOS, **When** the OTP entry screen is displayed,
     **Then** a 6-digit input field is shown with the iOS keyboard "from
     Messages" autofill suggestion enabled.
  3. **Given** the user is on Android but SMS Retriever fails or times out,
     **When** 15 seconds pass without auto-read, **Then** the manual entry field
     remains editable and the user can type the code manually (negative case —
     graceful degradation).
- **Definition of Done:** Code merged, platform-specific widget tests passing, QA
  verified on Android emulator (auto-read) and iOS simulator (manual entry).
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 3

---

### FR-AU-05: OTP Resend with Cooldown and Retry Cap

- **Priority:** P0
- **User Story:** As a user who did not receive the OTP, I want to request a new
  one after a short wait so that I can still complete login without restarting
  the flow.
- **Acceptance Criteria:**
  1. **Given** the user is on the OTP entry screen, **When** the 30-second
     cooldown has not elapsed, **Then** the "Resend OTP" button is disabled and a
     countdown timer is displayed.
  2. **Given** the 30-second cooldown has elapsed, **When** the user taps "Resend
     OTP", **Then** a new OTP is dispatched and the cooldown resets to 30
     seconds.
  3. **Given** the user has already resent the OTP 3 times within 10 minutes,
     **When** they attempt a fourth resend, **Then** the button is disabled and a
     message "Too many attempts. Please try again later." is displayed (negative
     case — rate limit).
- **Definition of Done:** Code merged, unit tests for timer logic and retry
  counter passing, widget test confirms disabled/enabled button states, QA
  verified.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 3

---

### FR-AU-06: First-Time Profile Setup Prompt

- **Priority:** P0
- **User Story:** As a first-time user who has just verified my phone number, I
  want to be prompted to enter my display name and optionally upload a profile
  photo so that my friends can recognise me in the app.
- **Acceptance Criteria:**
  1. **Given** a user successfully logs in for the very first time (no existing
     `users/{userId}` document), **When** authentication completes, **Then** the
     app navigates to the profile setup screen with a required "Display Name"
     field and an optional "Profile Photo" picker.
  2. **Given** the user enters a display name and taps "Continue", **When** the
     profile is saved, **Then** a `users/{userId}` document is created in
     Firestore with `displayName`, `phoneNumber`, and `createdAt`, and the app
     navigates to the Home dashboard.
  3. **Given** the user leaves the display name field empty and taps "Continue",
     **When** validation runs, **Then** an inline error "Display name is
     required" is shown and the profile is not saved (negative case).
  4. **Given** a returning user logs in (existing `users/{userId}` document),
     **When** authentication completes, **Then** the profile setup screen is
     skipped and the app navigates directly to Home.
- **Definition of Done:** Code merged, unit tests for first-time vs returning
  user detection passing, widget test for validation, integration test against
  Firestore Emulator confirming document creation, QA verified.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 5

---

### FR-AU-07: Session Persistence and Auto-Login

- **Priority:** P0
- **User Story:** As a returning user, I want to be automatically logged in when I
  reopen the app so that I do not have to enter my phone number and OTP every
  time.
- **Acceptance Criteria:**
  1. **Given** a user has previously logged in and not signed out, **When** the
     app is launched, **Then** the app detects the existing Firebase Auth session
     and navigates directly to the Home dashboard without showing the login
     screen.
  2. **Given** a user has previously logged in and not signed out, **When** the
     app is launched after a device restart, **Then** the persisted session is
     still valid and auto-login succeeds.
  3. **Given** the user's Firebase Auth token has been revoked server-side (e.g.,
     account disabled), **When** the app launches and the token refresh fails,
     **Then** the app clears the local session and redirects to the login screen
     with an appropriate message (negative case).
- **Definition of Done:** Code merged, unit tests for auth-state routing logic
  passing, integration test against Auth Emulator, QA verified on cold launch
  scenarios.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 2

---

### FR-AU-08: Sign Out from Profile Screen

- **Priority:** P0
- **User Story:** As a logged-in user, I want to sign out from the Profile screen
  so that I can switch accounts or secure my session on a shared device.
- **Acceptance Criteria:**
  1. **Given** the user is on the Profile screen, **When** they tap "Sign Out",
     **Then** a confirmation dialog is displayed asking "Are you sure you want to
     sign out?".
  2. **Given** the user confirms the sign-out dialog, **When** sign-out
     completes, **Then** the Firebase Auth session is cleared, local cached data
     is purged, and the app navigates to the login screen.
  3. **Given** the user cancels the sign-out dialog, **When** the dialog is
     dismissed, **Then** the user remains on the Profile screen and the session
     is unchanged (negative case — cancellation).
  4. **Given** the user has signed out, **When** they reopen the app, **Then**
     the login screen is displayed (no auto-login per FR-AU-07).
- **Definition of Done:** Code merged, unit tests for sign-out flow passing,
  widget test for confirmation dialog, QA verified end-to-end.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 2

---

### FR-PR-01: View and Edit Profile (Display Name and Photo)

- **Priority:** P0
- **User Story:** As a registered user, I want to view and edit my display name
  and profile photo from the Profile screen so that I can keep my identity up to
  date.
- **Acceptance Criteria:**
  1. **Given** a logged-in user navigates to the Profile screen, **When** the
     screen loads, **Then** the current display name, profile photo (or a default
     avatar with initials), and phone number (read-only) are displayed.
  2. **Given** the user edits their display name to a new valid value and taps
     "Save", **When** the update is submitted, **Then** the `users/{userId}`
     document in Firestore is updated with the new `displayName` and
     `updatedAt`, and a success confirmation is shown.
  3. **Given** the user selects a new profile photo from their device gallery,
     **When** the upload completes, **Then** the image is stored in Firebase
     Storage at `avatars/{userId}`, the `photoUrl` field on the user document is
     updated, and the new photo is displayed.
  4. **Given** the user clears the display name field and taps "Save", **When**
     validation runs, **Then** an inline error "Display name cannot be empty" is
     shown and the update is not submitted (negative case).
- **Definition of Done:** Code merged, unit tests for profile update logic
  passing, widget test for edit form, integration test against Firestore and
  Storage Emulators, QA verified, profile photo upload tested with images under
  5 MB and over-size rejection.
- **Responsible Agents:** Flutter Dev, QA.
- **Story Points:** 5

---

### INFRA-01: Firebase Project Configuration and Emulator Suite Setup

- **Priority:** P0 (blocking all other stories)
- **User Story:** As a developer on the team, I want the Firebase project
  configured with all required services and the local emulator suite ready to run
  so that I can develop and test features without touching production.
- **Acceptance Criteria:**
  1. **Given** a developer clones the repository, **When** they run
     `firebase emulators:start`, **Then** the Auth, Firestore, Functions, and
     Storage emulators start successfully on localhost with ports defined in
     `firebase.json`.
  2. **Given** the Firebase project is configured, **When** the configuration is
     inspected, **Then** Auth is enabled with Phone provider, Firestore is set to
     region `asia-south1`, Storage is enabled, and App Check is configured.
  3. **Given** a developer pushes a branch and opens a pull request to `main`,
     **When** the PR pipeline triggers, **Then** the `.github/workflows/pr.yml`
     workflow runs: checkout, Flutter setup, Node 20 setup, `flutter pub get`,
     `dart format --set-exit-if-changed`, `flutter analyze`,
     `flutter test --coverage`,
     `cd functions && npm ci && npm run lint && npm test`, and reports pass/fail
     status.
  4. **Given** branch protection rules are applied to `main`, **When** a
     developer attempts to push directly to `main` or force-push, **Then** the
     push is rejected (negative case).
  5. **Given** the repository README or a dedicated `docs/secrets.md` file
     exists, **When** a developer reads it, **Then** they find documentation for
     all required GitHub secrets listed in SRS section 9.3 with instructions on
     how to set them (without revealing actual values).
- **Definition of Done:**
  - `firebase.json` committed with emulator configuration for Auth, Firestore,
    Functions, and Storage.
  - `.firebaserc` committed with the single production project alias (invariant
    4 — single Firebase project).
  - `.github/workflows/pr.yml` committed and passing on a test PR.
  - Branch protection rules enabled on `main` (no direct push, no force-push,
    required status checks).
  - GitHub secrets documentation committed.
  - `lefthook.yml` updated with pre-commit hooks for lint and format.
- **Responsible Agents:** DevOps, Architect.
- **Story Points:** 8

---

### FUNC-01: Simplified-Debts Pure Function Stub with Canonical Test Suite

- **Priority:** P0 (contract-establishing; blocks expense and settlement features
  in sprint 2)
- **User Story:** As a Cloud Functions developer, I want the simplified-debts
  algorithm contract established with TypeScript types, a pure function skeleton,
  and a comprehensive test suite so that expense and settlement features can
  depend on a stable, tested interface.
- **Acceptance Criteria:**
  1. **Given** the file `functions/src/simplifiedDebts.ts` exists, **When**
     inspected, **Then** it exports a pure function
     `simplifyDebts(members: MemberBalance[]): Transfer[]` with clearly defined
     TypeScript types: `MemberBalance` (containing `userId: string` and
     `netPaise: number`) and `Transfer` (containing `from: string`,
     `to: string`, `amountPaise: number`), with all monetary values as integers
     (invariant 1 — money is integer paise).
  2. **Given** the canonical test suite in
     `functions/src/__tests__/simplifiedDebts.test.ts` exists, **When**
     `npm test` is run, **Then** all six canonical test cases pass:
     - **Empty input:** given an empty array, returns an empty transfer list.
     - **Single member:** given one member with any net balance, returns an empty
       transfer list (no one to transfer to).
     - **Perfectly balanced:** given members whose nets are all zero, returns an
       empty transfer list.
     - **Cyclic debts that simplify to zero:** given members A, B, C where
       A owes B 100, B owes C 100, C owes A 100 (all nets zero), returns an
       empty transfer list.
     - **3-person case:** given A(+300), B(-100), C(-200), returns transfers that
       settle all balances with the minimum number of transactions, and all
       `amountPaise` values are positive integers.
     - **5-person case:** given 5 members with varying positive and negative nets
       summing to zero, returns a valid minimal transfer set where the sum of all
       transfers from each debtor equals their net debt and the sum of all
       transfers to each creditor equals their net credit.
  3. **Given** two creditors or debtors have the same absolute net balance,
     **When** the algorithm runs, **Then** ties are broken by ascending `userId`
     for deterministic output (per SRS section 7.4).
  4. **Given** a member has a `netPaise` value that is a floating-point number,
     **When** passed to the function, **Then** the function throws a validation
     error or the type system prevents it at compile time (negative case —
     invariant 1 enforcement).
  5. **Given** the function is a stub, **When** the tests are run, **Then** the
     stubs return correct results for the canonical test matrix (implementation
     may be naive/direct for now; optimisation is a sprint 2 concern).
- **Definition of Done:**
  - `functions/src/simplifiedDebts.ts` committed with exported types and
    function.
  - `functions/src/__tests__/simplifiedDebts.test.ts` committed with all six
    canonical cases plus the tie-breaking and negative case.
  - `npm test` passes in CI (PR pipeline).
  - JSDoc on all exported types and the function.
  - No client code writes to `simplifiedBalances` (invariant 2 — verified by
    code review).
- **Responsible Agents:** Functions Dev, Architect (contract review), QA (test
  review).
- **Story Points:** 5

---

## Sprint Capacity

| Area | Stories | Points |
|---|---|---|
| Authentication (FR-AU-01 to FR-AU-08) | 8 | 25 |
| Profile (FR-PR-01) | 1 | 5 |
| Infrastructure (INFRA-01) | 1 | 8 |
| Simplified-Debts Stub (FUNC-01) | 1 | 5 |
| **Total** | **11** | **43** |

### Risks and Notes

1. **INFRA-01 is on the critical path.** All Flutter stories depend on the
   emulator suite and CI pipeline being operational. INFRA-01 should be the first
   story started and completed. If it slips, all authentication stories are
   blocked.
2. **FR-AU-03 and FR-AU-04 carry platform-specific risk.** SMS Retriever
   behaviour on Android emulators may be non-deterministic; testing should
   primarily validate the fallback manual-entry path in CI, with auto-read tested
   on a real device during QA.
3. **FR-AU-06 and FR-PR-01 share UI surface.** The profile setup screen (first
   login) and the profile edit screen (returning user) should share components to
   avoid duplication. Architect should flag this in the technical design.
4. **Single Firebase project (invariant 4)** means all emulator configuration
   must be correct before any integration test runs. There is no fallback staging
   environment.
5. **FUNC-01 is deliberately a stub.** The goal is to lock the contract (types,
   function signature, test matrix) so that sprint 2 expense and settlement
   stories can depend on it. The algorithm implementation may be naive;
   performance optimisation is deferred.

---

## Progress

| PR | Title | Stories | Status | Merged |
|---|---|---|---|---|
| #1 | Agentic configuration bootstrap | -- | Merged | 2026-04-30 |
| #2 | Sprint-zero + design phase artefacts | -- | Merged | 2026-04-30 |
| #3 | Bootstrap project skeleton | INFRA-01 (partial) | Merged | 2026-05-01 |
| #4 | Phone-number entry screen (FR-AU-01) | FR-AU-01, FR-AU-02 | Merged | [2026-05-01](https://github.com/avtansh-code/OneByTwo/pull/4) |
| #5 | PR-#4 retrospective and ratified patterns | -- (chore) | In flight | -- |

### Velocity observation

- **FR-AU-01 + FR-AU-02 (5 SP):** ~10.5 hours elapsed (PR #4 created to merged).
  Approximately half the commit effort was CI/platform fixups rather than feature
  work. With the CI improvements landed in PR #5, future feature PRs should see
  less CI friction.
- **No sequencing changes required.** The retro did not uncover blockers that alter
  the story order. The auth flow continues as planned: OTP screen next, then Firebase
  Phone Auth wiring, then profile setup.
