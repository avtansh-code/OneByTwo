# Screen Specifications: Authentication and Profile Setup (SCR-01 to SCR-05)

> **Document status:** Draft
> **SRS version:** 1.1
> **Audience:** Flutter Developer, Solution Architect, QA Engineer
> **Design system reference:** `docs/design/02-design-system/components.md`
> **Information architecture reference:** `docs/design/01-information-architecture/site-map.md`
> **Wireframe reference:** `docs/design/04-wireframes/auth-flow.md`

This document provides detailed screen specifications for the five unauthenticated screens in the OneByTwo authentication and profile setup flow. Each specification is intended to be consumed directly by the Flutter Developer during implementation and by the QA Engineer during test case authoring. All monetary values follow Invariant 1 (integer paise). All navigation follows the site-map routing contract (site-map sections 2.1 and 2.5).

---

## SCR-01: Splash Screen

### Screen Name

Splash Screen

### Purpose

Determine the user's authentication state and route them to the appropriate downstream screen whilst displaying the app brand.

### Route

`/splash`

### SRS Requirements

| ID | Requirement summary |
|---|---|
| FR-AU-07 | Persist authenticated session and auto-login on subsequent launches. |
| Section 6.3 item 1 | Splash and onboarding screens. |
| Section 6.4 | Error state with retry affordance for network failure. |
| Section 6.2 | Motion: 200--300 ms ease-in-out transitions. |

### Reachable From / Leads To

| Reachable from | Leads to | Navigation type | Condition |
|---|---|---|---|
| App launch (cold start) | `/onboarding` | `replace` | No session and first install (local `onboardingCompleted` flag is `false`). |
| App launch (cold start) | `/auth/phone` | `replace` | No session and onboarding previously completed. |
| App launch (cold start) | `/auth/profile-setup` | `replace` | Valid session but no `users/{userId}` document in Firestore (FR-AU-06). |
| App launch (cold start) | `/home` | `replace` | Valid session and profile document exists (FR-AU-07). |

### Components Used

| Component | Catalogue ref | Usage |
|---|---|---|
| -- | -- | No catalogue components. Bespoke branded layout: centred app logo, tagline, and a custom three-dot indeterminate loader rendered in `primary` (`#1F4E79`). |

### States

| State | Visual description | Trigger | Duration / persistence |
|---|---|---|---|
| **Default (loading)** | App logo centred vertically and horizontally. Tagline "Split it. Settle it. Simple." below logo in muted body text. Three-dot indeterminate loader beneath tagline in `primary`. | App launch (cold start). | Minimum 1500 ms display time, then navigates based on auth state check result (SRS section 6.2). |
| **Loading (skeleton)** | Not applicable. The default state is itself the loading presentation. | -- | -- |
| **Empty** | Not applicable. No data-driven content on this screen. | -- | -- |
| **Error (network)** | Logo remains centred. Loader is replaced by inline error text: "Could not connect. Check your internet and try again." A "Retry" text button appears below in `primary`. | Auth state check fails due to network unavailability. | Persists until user taps Retry or connectivity restores. |
| **Populated** | Not applicable. No data-driven content on this screen. | -- | -- |
| **Offline** | Identical to the error (network) state. If the device is offline at launch, the auth state check cannot complete. Error text and Retry button are shown. | Device has no network connectivity at cold start. | Persists until connectivity restores or user taps Retry. |

### Inputs and Validation

This screen has no user inputs. All logic is automated (auth state check against Firebase Auth and Firestore).

### Telemetry Events

| Event name | Trigger | Parameters | SRS ref |
|---|---|---|---|
| `app_launched` | Screen mounts on cold start. | `timestamp`, `platform` (iOS/Android), `app_version` | Section 5.10 |
| `splash_auth_check_started` | Auth state check begins. | `timestamp` | Section 5.10 |
| `splash_auth_check_completed` | Auth state check resolves. | `result` (`onboarding` / `phone` / `profile_setup` / `home`), `duration_ms` | Section 5.10 |
| `splash_auth_check_failed` | Auth state check fails (network error). | `error_type`, `timestamp` | Section 5.10 |
| `splash_retry_tapped` | User taps the Retry button in the error state. | `attempt_number` | Section 5.10 |

### Accessibility

| Element | Semantic label | Role / type |
|---|---|---|
| App logo image | "One By Two app logo" | Image (decorative: `false`) |
| Tagline text | Announced as body text: "Split it. Settle it. Simple." | Text |
| Three-dot loader | "Loading, please wait" | Live region (`Semantics(liveRegion: true)`) |
| Error message text | Announced on state change: "Could not connect. Check your internet and try again." | Live region |
| Retry button | "Retry" | Button |

**Focus order:** Logo (non-interactive, skipped by focus traversal) then loader (announced as live region). In error state: error message then Retry button.

**Screen-reader announcement on state change:** When the state transitions from default to error, the error message is announced immediately via the live region. When the user taps Retry, the live region reverts to "Loading, please wait."

**Contrast verification:** Tagline text (`onSurface` muted) on `surface` (`#FFFFFF`) must meet 4.5:1 ratio (SRS section 5.6). Error text in `danger` (`#E76F51`) on `surface` (`#FFFFFF`) yields approximately 3.3:1; therefore error text must use `onSurface` (dark text) rather than raw `danger` to satisfy WCAG AA, or the background must be tinted. Open question for the Architect below.

### Edge Cases

| # | Edge case | Expected behaviour | Source |
|---|---|---|---|
| 1 | Auth token has expired since last session (Firebase token refresh fails). | Treat as unauthenticated. Navigate to `/auth/phone` (or `/onboarding` if first install). Do not show an error; the user simply re-authenticates. | QA |
| 2 | Firestore is reachable but the `users/{userId}` document has been deleted (e.g., account deletion completed server-side). | Session exists but no profile document. Navigate to `/auth/profile-setup` so the user can re-create their profile (FR-AU-06). | QA |
| 3 | Device clock is significantly skewed (more than 5 minutes), causing Firebase token validation to fail. | Firebase Auth SDK handles clock skew internally for most cases. If the check fails, treat as a network error and show the Retry state. | QA |
| 4 | App is killed during the splash screen before auth check completes. | No side effects. On next launch, the splash screen restarts the auth check from scratch. | QA |

### Open Questions for the Architect

1. **Error text contrast:** The `danger` token (`#E76F51`) on white `surface` does not meet WCAG 2.1 AA 4.5:1 contrast for body text. Should we use `onSurface` for error message text and reserve `danger` for borders/icons only, or should we darken the danger token specifically for text usage?
2. **Minimum display time:** The wireframe specifies 1500 ms minimum display. Should this timer run concurrently with the auth check, or should the auth check begin only after the timer elapses? Concurrent is recommended for perceived performance.
3. **Connectivity listener:** Should the splash screen register a connectivity stream listener to auto-retry when the network becomes available, or rely solely on the manual Retry button?

---

## SCR-02: Onboarding

### Screen Name

Onboarding

### Purpose

Introduce first-time users to the app's core value propositions across three illustrated slides before routing them to phone-number authentication.

### Route

`/onboarding`

### SRS Requirements

| ID | Requirement summary |
|---|---|
| Section 6.3 item 1 | Three illustrated onboarding slides. |
| Section 5.6 | Tap targets (48x48 dp), contrast ratios (4.5:1), screen-reader labels, dynamic font scaling. |
| Section 6.5 | Friendly, concise microcopy tone. |
| Section 6.2 | 200--300 ms ease-in-out transitions for slide swipes. |

### Reachable From / Leads To

| Reachable from | Leads to | Navigation type | Condition |
|---|---|---|---|
| `/splash` | `/auth/phone` | `replace` | User taps "Skip" (slides 1--2) or "Get Started" (slide 3). |

On completion (Skip or Get Started), the local `onboardingCompleted` flag is set to `true`. The onboarding flow is never shown again on subsequent launches.

### Components Used

| Component | Catalogue ref | Usage |
|---|---|---|
| -- | -- | No catalogue components. Bespoke onboarding layout. Buttons follow the standard filled-button style from design tokens: corner radius 16 dp, `primary` fill, white label. Dot pagination is a custom widget. |

### States

| State | Visual description | Trigger |
|---|---|---|
| **Default (slide 1)** | First illustration (approximately 200 dp tall, centred). Title: "Track every rupee" (heading, `primary`, centred). Description: "Add expenses with friends and groups. We handle the maths." (body, muted, centred). Dot pagination: first dot active in `primary`, remaining two in muted grey. "Skip" text button top-right. "Next" filled button bottom. | Screen mount on first install. |
| **Slide 2** | Second illustration. Title: "See who owes what". Description: "Simplified balances show you the easiest way to settle up." Dot 2 active. "Skip" visible. "Next" button. | User swipes right or taps "Next" from slide 1. |
| **Slide 3** | Third illustration. Title: "Settle up, stress-free". Description: "Record payments and stay on top of shared spending." Dot 3 active. "Skip" hidden. "Get Started" button replaces "Next". | User swipes right or taps "Next" from slide 2. |
| **Swiping** | Crossfade between illustrations. Dots animate position. 200--300 ms ease-in-out (SRS section 6.2). | User swipes horizontally between slides. |
| **Loading (skeleton)** | Not applicable. All content is bundled locally; no network fetch required. | -- |
| **Empty** | Not applicable. Content is static. | -- |
| **Error** | Not applicable. No network dependency. | -- |
| **Populated** | Each slide is the populated state. | -- |
| **Offline** | Fully functional. All content is local. No degradation. | -- |

### Inputs and Validation

No text inputs. Interactive elements are limited to "Skip", "Next", "Get Started", swipe gestures, and dot pagination (non-interactive indicators only).

### Telemetry Events

| Event name | Trigger | Parameters | SRS ref |
|---|---|---|---|
| `onboarding_started` | Screen mounts (slide 1 is displayed). | `timestamp` | Section 5.10 |
| `onboarding_slide_viewed` | Each slide becomes visible (including via swipe). | `slide_index` (1, 2, or 3), `timestamp` | Section 5.10 |
| `onboarding_skipped` | User taps "Skip". | `skipped_from_slide` (1 or 2), `timestamp` | Section 5.10 |
| `onboarding_completed` | User taps "Get Started" on slide 3. | `timestamp` | Section 5.10 |
| `signup_started` | Fires when navigation to `/auth/phone` is initiated (either via Skip or Get Started). | `source` (`skip` / `get_started`), `timestamp` | Section 5.10 (key funnel event) |

### Accessibility

| Element | Semantic label | Role / type |
|---|---|---|
| Illustration (each slide) | `excludeSemantics: true` (decorative) | Image (excluded) |
| Slide title | Announced as a heading (`Semantics(header: true)`) | Heading |
| Slide description | Announced as body text | Text |
| Dot pagination | "Page [N] of 3" | Live region (announced on slide change) |
| "Skip" button | "Skip onboarding" | Button |
| "Next" button | "Next" | Button |
| "Get Started" button | "Get Started" | Button |

**Focus order:** Skip button (when visible) then slide title then slide description then dot pagination then Next/Get Started button.

**Screen-reader announcement on state change:** When the active slide changes (via swipe or Next), the dot pagination live region announces "Page [N] of 3". The new slide's title and description are announced in sequence.

**Tap targets:** All buttons meet 48x48 dp minimum (SRS section 5.6). "Skip" text button must have sufficient padding to meet the minimum even though the text itself may be narrow.

### Edge Cases

| # | Edge case | Expected behaviour | Source |
|---|---|---|---|
| 1 | User swipes backwards from slide 1. | No action; the `PageView` should clamp at index 0 with a subtle bounce/resistance animation. No crash or blank screen. | QA |
| 2 | User rotates device during onboarding (landscape mode). | Layout adapts. Illustration scales down. Text remains readable. No content is clipped. Consider constraining illustration height to `min(200 dp, 40% of screen height)`. | QA |
| 3 | User force-kills the app after viewing slide 2 but before completing onboarding. | `onboardingCompleted` flag remains `false`. On next launch, onboarding restarts from slide 1. No partial state is persisted. | QA |
| 4 | Dynamic font scaling is set to maximum (accessibility large text). | Title and description text scale up. The layout must scroll vertically if content overflows, rather than clipping. Illustration may shrink or be hidden to accommodate larger text. | QA |

### Open Questions for the Architect

1. **Local storage mechanism:** Should the `onboardingCompleted` flag be stored in `SharedPreferences` or `Hive`? This affects the auth guard redirect logic on splash.
2. **Illustration format:** Should illustrations be bundled as vector assets (SVG via `flutter_svg`) or rasterised PNGs at multiple densities? SVG is smaller but may have rendering overhead on low-end devices.

---

## SCR-03: Phone Entry

### Screen Name

Phone Entry

### Purpose

Collect the user's Indian mobile number and trigger Firebase Phone Auth to send a 6-digit OTP via SMS.

### Route

`/auth/phone`

### SRS Requirements

| ID | Requirement summary |
|---|---|
| FR-AU-01 | Sign in using mobile phone number with +91 country code prefix locked. |
| FR-AU-02 | Reject any phone number that is not a valid 10-digit Indian mobile number. |
| FR-AU-03 | Trigger Firebase Phone Auth to send a 6-digit OTP via SMS. |
| Section 6.3 item 2 | Phone-number entry screen with locked +91 prefix. |
| Section 6.4 | Error state with actionable retry; loading state on button. |
| Section 5.6 | Tap targets, contrast ratios, screen-reader labels, dynamic font scaling. |

### Reachable From / Leads To

| Reachable from | Leads to | Navigation type | Condition |
|---|---|---|---|
| `/splash` (no session, onboarding done) | `/auth/otp` | `push` | Valid +91 number submitted, OTP sent successfully. |
| `/onboarding` (Skip or Get Started) | `/auth/otp` | `push` | Valid +91 number submitted, OTP sent successfully. |
| `/auth/otp` (back button) | -- | `pop` (returns here) | User navigates back to correct their number. |

### Components Used

| Component | Catalogue ref | Usage |
|---|---|---|
| `OBTPhoneInput` | Component 8 | Locked `+91` prefix, 10-digit input, `XXXXX XXXXX` formatting, validation states. |
| `OBTSnackbar` | Component 25 | Error feedback when OTP send fails. Type: `error`. |

### States

| State | Visual description | Trigger |
|---|---|---|
| **Default (empty)** | Heading: "Enter your mobile number" (`primary`, semi-bold, 24 sp). Subtitle: "We'll send you a 6-digit code to verify." (muted, 16 sp). Empty `OBTPhoneInput` with placeholder "Enter mobile number". "Continue" button disabled (muted fill, no ripple). | Screen mount. |
| **Focused (typing)** | `OBTPhoneInput` bottom border in `primary`. Digits appear with live `XXXXX XXXXX` formatting. "Continue" remains disabled until 10 digits are entered. | User begins typing. |
| **Populated (valid, 10 digits)** | `OBTPhoneInput` shows formatted number. "Continue" button becomes active (`primary` fill, white label). | Exactly 10 digits entered. |
| **Error (invalid number)** | `OBTPhoneInput` border turns `danger` (`#E76F51`). Error text below input: "Please enter a valid 10-digit mobile number." "Continue" button disabled. | User taps Continue with number not starting with 6, 7, 8, or 9, or with fewer than 10 digits. |
| **Loading (sending OTP)** | "Continue" button label replaced by an indeterminate circular progress indicator in white. Button is non-interactive. `OBTPhoneInput` is disabled (greyed, keyboard dismissed). | User taps Continue with a valid number. |
| **Error (OTP send failed)** | Loading ends. `OBTPhoneInput` re-enabled. `OBTSnackbar` of type `error` appears at the bottom: "Could not send the code. Please try again." "Continue" button returns to active state. | Firebase Phone Auth returns an error (network, rate-limiting, etc.). |
| **Skeleton** | Not applicable. No data-driven content on this screen. | -- |
| **Empty** | The default state is the empty state. | -- |
| **Offline** | If the device is offline when Continue is tapped, the OTP send fails. The OTP-send-failed error state is shown. The snackbar message should read: "No internet connection. Check your network and try again." | Device offline when submitting. |

### Inputs and Validation

| Input | Field component | Type | Required | Constraints | Error message (exact) | SRS ref |
|---|---|---|---|---|---|---|
| Phone number | `OBTPhoneInput` | Numeric (10 digits) | Yes | Exactly 10 digits; must start with 6, 7, 8, or 9; `+91` prefix locked and non-editable. | "Please enter a valid 10-digit mobile number." | FR-AU-01, FR-AU-02 |

**Validation timing:** On tap of "Continue". No inline validation whilst typing (to avoid premature errors). The button is disabled until 10 digits are entered, providing a soft gate.

### Telemetry Events

| Event name | Trigger | Parameters | SRS ref |
|---|---|---|---|
| `phone_entry_viewed` | Screen mounts. | `source` (`splash` / `onboarding` / `otp_back`), `timestamp` | Section 5.10 |
| `phone_number_submitted` | User taps Continue with 10 digits. | `timestamp` (phone number is NOT logged for privacy) | Section 5.10 |
| `phone_validation_failed` | Client-side validation rejects the number. | `reason` (`invalid_prefix` / `too_short`), `timestamp` | Section 5.10 |
| `otp_send_requested` | Firebase Phone Auth `verifyPhoneNumber` is called. | `timestamp` | Section 5.10 |
| `otp_send_succeeded` | Firebase confirms OTP was dispatched. | `duration_ms`, `timestamp` | Section 5.10 |
| `otp_send_failed` | Firebase returns an error. | `error_code`, `timestamp` | Section 5.10 |

### Accessibility

| Element | Semantic label | Role / type |
|---|---|---|
| Heading | "Enter your mobile number" | Heading (`Semantics(header: true)`) |
| Subtitle | "We'll send you a 6-digit code to verify." | Text |
| `OBTPhoneInput` | "Phone number, India country code plus 91" | Text field |
| `+91` prefix | Announced as part of the phone input label; non-editable. | -- |
| Error text (invalid number) | "Please enter a valid 10-digit mobile number." | Live region (announced on state change) |
| "Continue" button (active) | "Continue" | Button |
| "Continue" button (disabled) | "Continue, disabled" | Button (disabled) |
| "Continue" button (loading) | "Sending verification code" | Button (disabled, live region) |
| `OBTSnackbar` (error) | Announced on appearance: "Could not send the code. Please try again." | Live region |

**Focus order:** Heading (non-interactive, skipped) then `OBTPhoneInput` (receives autofocus) then Continue button.

**Screen-reader announcement on state change:** When validation fails, the error text is announced immediately. When the snackbar appears (OTP send failure), it is announced as a live region. When loading begins, the button announces "Sending verification code."

**Contrast verification:** Heading `primary` (`#1F4E79`) on `surface` (`#FFFFFF`) yields approximately 8.5:1, exceeding 4.5:1 (SRS section 5.6). Error text: see open question from SCR-01 regarding `danger` token contrast.

### Edge Cases

| # | Edge case | Expected behaviour | Source |
|---|---|---|---|
| 1 | User pastes a phone number with spaces, dashes, or the `+91` prefix included (e.g., "+91-98765-43210"). | The input must strip non-digit characters and any leading `+91` or `91` prefix, then validate the remaining 10 digits. If the result is not exactly 10 digits starting with 6/7/8/9, show the validation error. | QA |
| 2 | Firebase returns `too-many-requests` error (rate limiting). | Map the Firebase error code to a user-friendly snackbar: "Too many attempts. Please wait a few minutes and try again." Do not expose the raw Firebase error. | QA |
| 3 | User navigates back from `/auth/otp` to correct their number. | The previously entered phone number should be pre-populated in the `OBTPhoneInput` field. The user can edit and re-submit. The Continue button should be active if 10 digits are present. | QA |
| 4 | User taps Continue rapidly multiple times before the loading state activates. | Debounce the tap. Only one `verifyPhoneNumber` call should be made. Subsequent taps during loading are ignored. | QA |

### Open Questions for the Architect

1. **Phone number persistence on back-navigation:** When the user pops back from OTP, should the phone number be held in an in-memory Riverpod provider or passed as a route parameter? The route parameter approach is simpler but exposes the number in the URL.
2. **Rate-limit error mapping:** Firebase Phone Auth returns various error codes (`too-many-requests`, `quota-exceeded`, `app-not-authorized`). Should we maintain a centralised error-code-to-microcopy mapping, or handle each error inline?

---

## SCR-04: OTP Verification

### Screen Name

OTP Verification

### Purpose

Accept and verify the 6-digit OTP sent to the user's phone number via Firebase Phone Auth, with support for auto-read on Android and manual entry on iOS.

### Route

`/auth/otp`

### SRS Requirements

| ID | Requirement summary |
|---|---|
| FR-AU-03 | 6-digit OTP entry and verification via Firebase Phone Auth. |
| FR-AU-04 | Auto-read OTP on Android via SMS Retriever; manual entry on iOS. |
| FR-AU-05 | Resend OTP after 30-second cooldown, capped at 3 retries per 10-minute window. |
| FR-AU-06 | First-time login prompts profile setup (name, optional photo). |
| FR-AU-07 | Returning user auto-navigates to Home. |
| Section 6.3 item 3 | OTP verification screen layout. |
| Section 6.4 | Error states (invalid code, network) with retry; loading state. |
| Section 5.6 | Tap targets (48x48 dp cells), contrast ratios, screen-reader labels. |
| Section 6.2 | 200--300 ms transitions; `success` colour checkmark animation. |

### Reachable From / Leads To

| Reachable from | Leads to | Navigation type | Condition |
|---|---|---|---|
| `/auth/phone` (OTP sent successfully) | `/auth/profile-setup` | `replace` | OTP verified; first-time user (no `users/{userId}` document). |
| `/auth/phone` (OTP sent successfully) | `/home` | `replace` | OTP verified; returning user (profile document exists). |
| -- | `/auth/phone` | `pop` | User taps the back button to correct their phone number. |

### Components Used

| Component | Catalogue ref | Usage |
|---|---|---|
| `OBTOTPInput` | Component 7 | Six-cell OTP entry with auto-advance, auto-read, error, and loading states. |
| `OBTAppBar` | Component 1 | Back button to return to Phone Entry. `showBackButton: true`, `title: ""` (no title). |
| `OBTSnackbar` | Component 25 | Network error feedback. Type: `error`. |

### States

| State | Visual description | Trigger |
|---|---|---|
| **Default (empty)** | `OBTAppBar` with back button (no title). Heading: "Verify your number" (`primary`). Subtitle: "Enter the 6-digit code sent to +91 98765 43210" (muted body; phone number in bold). Six empty `OBTOTPInput` cells with muted bottom borders. Countdown text: "Resend code in 0:30" (muted). "Resend OTP" text button disabled (muted). | Screen mount after OTP is sent. |
| **Focused (typing)** | Active cell has `primary` bottom border and blinking cursor. Filled cells show centred digits. | User enters digits manually. |
| **Auto-reading (Android only)** | Muted text below cells: "Reading code automatically..." Cells remain empty until auto-read completes. | SMS Retriever API is listening (FR-AU-04). |
| **Loading (verifying)** | All six cells filled. Cells replaced by a centred indeterminate progress indicator in `primary`. Input disabled. | All 6 digits entered manually or via auto-read; `onCompleted` fires. |
| **Error (invalid OTP)** | All cell borders turn `danger`. Error text below: "Incorrect code, try again." Cells clear after 1 second. Input re-enabled for retry. | Firebase returns `invalid-verification-code` error. |
| **Error (network)** | `OBTSnackbar` of type `error`: "Could not verify. Check your connection and try again." Cells retain entered digits. Input re-enabled. | Network failure during verification. |
| **Resend available** | Countdown text hidden. "Resend OTP" button in `primary`, interactive. | 30-second countdown reaches zero. |
| **Resend exhausted** | "Resend OTP" button permanently disabled. Text: "Maximum resend attempts reached. Please try again later." (muted). | 3 resend attempts used within the 10-minute window (FR-AU-05). |
| **Success** | Brief checkmark animation in `success` (`#2A9D8F`) replaces the cells (200 ms ease-in-out). Then navigation fires. | OTP verified successfully. |
| **Skeleton** | Not applicable. No data-driven content. | -- |
| **Empty** | The default state is the empty state. | -- |
| **Populated** | Cells are filled with digits. | User enters or auto-read populates digits. |
| **Offline** | If the device is offline when verification is attempted, the network error state is shown (snackbar). If offline when resend is tapped, the snackbar message reads: "No internet connection. Check your network and try again." | Device offline during verification or resend attempt. |

### Inputs and Validation

| Input | Field component | Type | Required | Constraints | Error message (exact) | SRS ref |
|---|---|---|---|---|---|---|
| OTP code | `OBTOTPInput` | Numeric (6 digits) | Yes | Exactly 6 digits. Verification is server-side (Firebase). | "Incorrect code, try again." (invalid code) / "Could not verify. Check your connection and try again." (network) | FR-AU-03 |

**Validation timing:** Verification fires automatically when all 6 digits are entered (`onCompleted`). No explicit submit button is required.

### Telemetry Events

| Event name | Trigger | Parameters | SRS ref |
|---|---|---|---|
| `otp_screen_viewed` | Screen mounts. | `timestamp` | Section 5.10 |
| `otp_auto_read_started` | SMS Retriever begins listening (Android only). | `timestamp` | Section 5.10 |
| `otp_auto_read_succeeded` | SMS Retriever successfully reads the OTP. | `duration_ms`, `timestamp` | Section 5.10 |
| `otp_auto_read_failed` | SMS Retriever times out or fails. | `error_type`, `timestamp` | Section 5.10 |
| `otp_manual_entry_completed` | User manually enters all 6 digits. | `timestamp` | Section 5.10 |
| `otp_verification_started` | Firebase `signInWithCredential` is called. | `method` (`auto_read` / `manual` / `paste`), `timestamp` | Section 5.10 |
| `otp_verification_succeeded` | Firebase confirms the OTP is valid. | `is_new_user` (boolean), `duration_ms`, `timestamp` | Section 5.10 |
| `otp_verification_failed` | Firebase returns an error. | `error_code`, `timestamp` | Section 5.10 |
| `signup_completed` | Fires for first-time users immediately after successful OTP verification. | `timestamp` | Section 5.10 (key funnel event) |
| `otp_resend_tapped` | User taps "Resend OTP". | `attempt_number` (1, 2, or 3), `timestamp` | Section 5.10 |
| `otp_resend_exhausted` | Third resend attempt is used. | `timestamp` | Section 5.10 |

### Accessibility

| Element | Semantic label | Role / type |
|---|---|---|
| Back button (`OBTAppBar`) | "Navigate back" | Button |
| Heading | "Verify your number" | Heading (`Semantics(header: true)`) |
| Subtitle (with phone number) | "Enter the 6-digit code sent to plus 91, 98765 43210" | Text |
| `OBTOTPInput` group | "Enter 6-digit verification code" | Text field group |
| Individual OTP cell (on focus) | "Digit [N] of 6" | Text field |
| Auto-read indicator (Android) | "Attempting to read verification code automatically" | Live region |
| Countdown timer | Announced every 10 seconds: "Resend available in [N] seconds" | Live region (periodic) |
| "Resend OTP" (disabled) | "Resend OTP, disabled, [N] seconds remaining" | Button (disabled) |
| "Resend OTP" (active) | "Resend OTP" | Button |
| "Resend OTP" (exhausted) | "Maximum resend attempts reached. Please try again later." | Text (disabled button) |
| Error text (invalid code) | "Incorrect code, try again." | Live region |
| `OBTSnackbar` (network error) | "Could not verify. Check your connection and try again." | Live region |
| Success checkmark | "Verification successful" | Live region |

**Focus order:** Back button then heading (non-interactive) then subtitle then first OTP cell (receives focus on mount) then remaining cells (auto-advance) then countdown/resend area.

**Screen-reader announcement on state change:** On verification start, announce "Verifying." On success, announce "Verification successful." On invalid code error, announce error text. On resend availability, announce "Resend OTP available."

### Edge Cases

| # | Edge case | Expected behaviour | Source |
|---|---|---|---|
| 1 | User receives the OTP SMS but switches to another app and returns after the 30-second resend timer has elapsed. | The countdown should have continued in the background. If 30 seconds have passed, "Resend OTP" should be active. The previously entered (partial) digits should be preserved in the cells. | QA |
| 2 | Auto-read on Android captures an OTP from a different service (e.g., a banking OTP arrives simultaneously). | The SMS Retriever API uses an app-specific hash to filter messages. If a non-matching SMS is received, it should be ignored. If auto-read returns an incorrect code, verification fails gracefully with the "Incorrect code" error state, and the user can re-enter manually. | QA |
| 3 | User pastes a code on iOS that contains non-digit characters or is not exactly 6 digits. | The paste should be rejected. Only pastes of exactly 6 numeric digits are accepted. No error is shown for a rejected paste; the cells simply do not populate. | QA |
| 4 | Firebase returns `session-expired` because the user waited too long (beyond Firebase's internal OTP expiry, typically 5 minutes). | Map the error to a user-friendly message: "This code has expired. Please request a new one." Enable the "Resend OTP" button immediately (bypassing the countdown) if resend attempts remain. | QA |
| 5 | User taps back, changes their phone number, and returns to OTP. | The OTP cells should be cleared. The countdown and resend counter should reset for the new phone number. The subtitle should display the updated phone number. | QA |

### Open Questions for the Architect

1. **OTP expiry handling:** Firebase Phone Auth OTP typically expires after a server-defined window. Should we implement a client-side expiry timer (e.g., 5 minutes) that proactively prompts the user to resend, or rely solely on the server-side `session-expired` error?
2. **Resend counter persistence:** Should the 3-retry / 10-minute window counter be persisted (e.g., in memory via Riverpod) or reset if the user navigates back to Phone Entry and re-submits? Resetting could allow circumvention; persisting per phone number is more robust.
3. **Auto-read timeout:** If SMS Retriever does not receive the SMS within a reasonable window (e.g., 60 seconds), should we dismiss the "Reading code automatically..." indicator and prompt manual entry?

---

## SCR-05: Profile Setup

### Screen Name

Profile Setup

### Purpose

Collect the user's display name (required) and optional profile photo on first login to create their Firestore user document.

### Route

`/auth/profile-setup`

### SRS Requirements

| ID | Requirement summary |
|---|---|
| FR-AU-06 | First successful login prompts for display name and optional profile photo. |
| FR-PR-01 | Users can view and edit their display name and profile photo. |
| Section 6.3 item 4 | Profile setup screen (name, photo). |
| Section 6.4 | Error states (empty name, save failure) with actionable copy; loading state on button. |
| Section 5.6 | Tap targets, contrast ratios, screen-reader labels, dynamic font scaling. |
| Section 6.5 | Friendly microcopy: "Tell us your name so your friends recognise you." |

### Reachable From / Leads To

| Reachable from | Leads to | Navigation type | Condition |
|---|---|---|---|
| `/auth/otp` (first-time user, OTP verified) | `/home` | `replace` | Profile saved successfully. |
| `/splash` (valid session, no profile document) | `/home` | `replace` | Profile saved successfully. |

No back navigation. The user cannot return to the OTP screen from this screen (site-map section 2.1).

### Components Used

| Component | Catalogue ref | Usage |
|---|---|---|
| `OBTUserAvatar` | Component 11 | 80 dp diameter. Displays selected photo or initials fallback (first character of display name on hashed-colour background). |
| `OBTSnackbar` | Component 25 | Error feedback on save failure. Type: `error`. |

### States

| State | Visual description | Trigger |
|---|---|---|
| **Default (empty)** | Heading: "Set up your profile" (`primary`, semi-bold, 24 sp). Subtitle: "Tell us your name so your friends recognise you." (muted, 16 sp). `OBTUserAvatar` at 80 dp showing generic person icon on neutral background. Camera badge (24 dp, `primary` background, white camera icon) overlapping bottom-right of avatar. Empty display name text field with label "Display name" and placeholder. "Continue" button disabled (muted fill). | Screen mount for first-time user. |
| **Typing** | Avatar initial updates live as the user types the first character of their name. Display name field has `primary` bottom border. "Continue" becomes active once at least one non-whitespace character is entered. | User types in the display name field. |
| **Photo selected** | Avatar shows the selected and circle-cropped photo. Camera badge remains for changing the selection. | User picks a photo from camera or gallery via the bottom sheet. |
| **Error (empty name)** | Display name field border turns `danger`. Error text below: "Please enter your name." "Continue" remains disabled. | User taps Continue with an empty or whitespace-only name. |
| **Error (name too long)** | Display name field border turns `danger`. Error text below: "Name must be 50 characters or fewer." | User enters more than 50 characters. |
| **Loading (saving)** | "Continue" button label replaced by circular progress indicator in white. Display name field and avatar picker are disabled (non-interactive). | User taps Continue with valid input. |
| **Error (save failed)** | Loading ends. Fields re-enabled. `OBTSnackbar` of type `error`: "Could not save your profile. Please try again." "Continue" button returns to active. | Firestore write or Firebase Storage upload fails. |
| **Success** | Brief transition animation; navigates to `/home` via `replace`. | Profile saved successfully. |
| **Skeleton** | Not applicable. No pre-existing data to load for a first-time user. | -- |
| **Empty** | The default state is the empty state. | -- |
| **Populated** | Display name field has content; avatar shows initials or photo. | User has entered data. |
| **Offline** | If the device is offline when Continue is tapped, the save fails. Snackbar message: "No internet connection. Check your network and try again." Fields re-enabled. | Device offline when submitting. |

### Inputs and Validation

| Input | Field component | Type | Required | Constraints | Error message (exact) | SRS ref |
|---|---|---|---|---|---|---|
| Display name | Standard text field | Text | Yes | Minimum 1 non-whitespace character; maximum 50 characters. Trimmed before submission. | "Please enter your name." (empty) / "Name must be 50 characters or fewer." (too long) | FR-AU-06 |
| Profile photo | Avatar picker (camera/gallery bottom sheet) | Image | No | Accepted formats: JPEG, PNG. Maximum file size: 5 MB (before compression). Cropped to circle on display; stored as square. | "Photo could not be loaded. Please try a different image." (corrupt/unsupported file) | FR-AU-06 |

**Validation timing:** Display name is validated on tap of "Continue". The 50-character limit may also be enforced with a live character counter (e.g., "42/50") that appears once the user exceeds 40 characters, providing a soft warning before the hard limit.

### Telemetry Events

| Event name | Trigger | Parameters | SRS ref |
|---|---|---|---|
| `profile_setup_viewed` | Screen mounts. | `source` (`otp` / `splash`), `timestamp` | Section 5.10 |
| `profile_photo_picker_opened` | User taps the avatar or camera badge. | `timestamp` | Section 5.10 |
| `profile_photo_selected` | User selects a photo from camera or gallery. | `source` (`camera` / `gallery`), `timestamp` | Section 5.10 |
| `profile_photo_skipped` | User taps Continue without selecting a photo. | `timestamp` | Section 5.10 |
| `profile_save_requested` | User taps Continue with valid input. | `has_photo` (boolean), `name_length`, `timestamp` | Section 5.10 |
| `profile_save_succeeded` | Firestore write (and optional Storage upload) completes. | `duration_ms`, `timestamp` | Section 5.10 |
| `profile_save_failed` | Firestore write or Storage upload fails. | `error_code`, `error_source` (`firestore` / `storage`), `timestamp` | Section 5.10 |

### Accessibility

| Element | Semantic label | Role / type |
|---|---|---|
| Heading | "Set up your profile" | Heading (`Semantics(header: true)`) |
| Subtitle | "Tell us your name so your friends recognise you." | Text |
| Avatar area (no photo) | "Profile photo. Tap to add a photo." | Button |
| Avatar area (photo set) | "Profile photo set. Tap to change." | Button |
| Camera badge | `excludeSemantics: true` (the avatar carries the combined label) | -- |
| Bottom sheet: "Take photo" | "Take photo" | Button |
| Bottom sheet: "Choose from gallery" | "Choose from gallery" | Button |
| Display name field | "Display name, required" | Text field |
| Error text (empty name) | "Please enter your name." | Live region |
| Error text (name too long) | "Name must be 50 characters or fewer." | Live region |
| "Continue" button (active) | "Continue" | Button |
| "Continue" button (disabled) | "Continue, disabled" | Button (disabled) |
| "Continue" button (loading) | "Saving profile" | Button (disabled, live region) |
| `OBTSnackbar` (save error) | "Could not save your profile. Please try again." | Live region |

**Focus order:** Heading (non-interactive) then avatar area (tappable) then display name field (receives focus after avatar) then Continue button. When the photo-picker bottom sheet opens: "Take photo" then "Choose from gallery" then implicit dismiss (swipe down or tap outside).

**Screen-reader announcement on state change:** When the avatar initial updates as the user types, no announcement is made (visual-only feedback; the text field value is already announced). When validation fails, the error text is announced. When loading begins, "Saving profile" is announced. On save failure, the snackbar is announced.

**Tap targets:** Avatar tap area is 80 dp (exceeds 48 dp minimum). All buttons meet 48x48 dp minimum (SRS section 5.6).

### Edge Cases

| # | Edge case | Expected behaviour | Source |
|---|---|---|---|
| 1 | User selects a very large photo (e.g., 20 MB raw camera image). | The app should compress/resize the image client-side before uploading to Firebase Storage. Target a maximum upload size of 1 MB. If compression fails or the image is corrupt, show an inline error: "Photo could not be loaded. Please try a different image." The user can still proceed without a photo. | QA |
| 2 | User denies camera or gallery permission when attempting to pick a photo. | Show a permission-denied message: "Photo access is needed to set your profile picture. You can grant permission in Settings." Provide a "Open Settings" button. The user can dismiss and proceed without a photo. | QA |
| 3 | User's display name contains only whitespace or special characters (e.g., "   " or "!!!"). | Whitespace-only names are rejected with the "Please enter your name" error. Names consisting solely of special characters (e.g., "!!!") are accepted, as they contain non-whitespace characters. The product may wish to add further validation (open question). | QA |
| 4 | Firebase Storage upload succeeds but the subsequent Firestore write to `users/{userId}` fails. | The uploaded photo becomes an orphan in Storage. The error state is shown. On retry, the photo should be re-uploaded (or, ideally, the client checks if the previous upload exists and reuses the URL). An orphan-cleanup Cloud Function should handle stale uploads. | QA |
| 5 | User is on this screen and the app is backgrounded for an extended period, causing the Firebase Auth token to refresh. | The token refresh should happen transparently via the Firebase SDK. If the refresh fails (e.g., user's account was disabled server-side), the save attempt will fail with an auth error. Show the snackbar: "Your session has expired. Please sign in again." and navigate to `/auth/phone`. | QA |

### Open Questions for the Architect

1. **Photo upload strategy:** Should the profile photo be uploaded to Firebase Storage first (obtaining a download URL) and then written to Firestore in a single document write, or should both operations run in parallel? Sequential is safer (avoids a Firestore document with a pending URL) but slower.
2. **Display name content policy:** Should we apply any content filtering or profanity detection to display names, or accept any non-empty string of up to 50 characters? For v1.0, accepting any string seems appropriate, but this should be recorded as a decision.
3. **Orphan photo cleanup:** If a Storage upload succeeds but the Firestore write fails, the photo is orphaned. Should a scheduled Cloud Function clean up Storage objects that are not referenced by any user document? What retention period is appropriate?
4. **Profile document schema:** What is the exact shape of the `users/{userId}` document created on this screen? The screen needs to know which fields to write (`displayName`, `photoUrl`, `phoneNumber`, `createdAt`). This should be confirmed against the Firestore data model in SRS section 7.2.

---

## Cross-Screen Design Tokens Applied

For reference, the following design token values from SRS section 6.2 are applied consistently across all five screens in this specification:

| Token | Light value | Dark value | Application in auth and profile setup flow |
|---|---|---|---|
| `primary` | `#1F4E79` | `#2E86AB` | Headings, active input borders, button fills, progress indicators. |
| `secondary` | `#F4A261` | `#F4A261` | Not used in the auth flow. Reserved for FAB and highlights in authenticated screens. |
| `success` | `#2A9D8F` | `#2A9D8F` | OTP success checkmark animation (SCR-04). |
| `danger` | `#E76F51` | `#E76F51` | Error text, error borders on inputs, snackbar error type. |
| `surface` | `#FFFFFF` | `#121212` | Screen backgrounds, input field backgrounds. |
| `cornerRadiusSmall` | 16 dp | 16 dp | Buttons, input fields. |
| `cornerRadiusLarge` | 24 dp | 24 dp | Photo-picker bottom sheet (SCR-05). |
| `motionStandard` | 200--300 ms ease-in-out | -- | Screen transitions, button state changes, onboarding slide swipes, OTP cell animations. |
| `tapTargetMin` | 48x48 dp (Android) / 44x44 pt (iOS) | -- | All interactive elements across all five screens. |
| Typography | Inter / Plus Jakarta Sans; system fallback | -- | Headings: semi-bold, 24 sp. Body: regular, 16 sp. Muted/subtitle: regular, 14 sp. |

---

## Navigation Summary

| From | To | Type | Condition | SRS ref |
|---|---|---|---|---|
| SCR-01 Splash | SCR-02 Onboarding | `replace` | First install, no session. | Section 6.3 item 1 |
| SCR-01 Splash | SCR-03 Phone Entry | `replace` | No session, onboarding done. | FR-AU-07 |
| SCR-01 Splash | SCR-05 Profile Setup | `replace` | Session valid, no profile document. | FR-AU-06 |
| SCR-01 Splash | Home (`/home`) | `replace` | Session valid, profile exists. | FR-AU-07 |
| SCR-02 Onboarding | SCR-03 Phone Entry | `replace` | Skip or Get Started. | Section 6.3 item 1 |
| SCR-03 Phone Entry | SCR-04 OTP Verification | `push` | Valid number, OTP sent. | FR-AU-03 |
| SCR-04 OTP Verification | SCR-03 Phone Entry | `pop` | Back button. | -- |
| SCR-04 OTP Verification | SCR-05 Profile Setup | `replace` | Valid OTP, first-time user. | FR-AU-06 |
| SCR-04 OTP Verification | Home (`/home`) | `replace` | Valid OTP, returning user. | FR-AU-07 |
| SCR-05 Profile Setup | Home (`/home`) | `replace` | Profile saved. | FR-AU-06 |

All `replace` transitions prevent backward navigation into completed authentication steps (site-map section 2.1).

---

## Document Control

| Field | Value |
|---|---|
| Author | UX/UI Designer agent |
| Created | 2025 |
| SRS version | 1.1 |
| Status | Draft -- pending Architect review of open questions |
| Dependencies | `docs/design/02-design-system/components.md`, `docs/design/04-wireframes/auth-flow.md`, `docs/design/01-information-architecture/site-map.md` |