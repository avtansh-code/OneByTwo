# FR-AU-01: Phone Number Entry with Locked +91 Prefix

> Implementation-ready user story for the first feature in sprint 1.
> Ready to be opened as a GitHub Issue using the `user_story` template.

---

## SRS Requirement ID(s)

FR-AU-01, FR-AU-02

## Priority

**P0 — Must have**

## User Story

As a **new or returning user**,
I want to **enter my 10-digit Indian mobile number into a phone-entry screen with
the +91 country code prefix locked and non-editable**
so that **I can begin the sign-in flow quickly without selecting a country code,
and the app can validate my number before requesting an OTP**.

## Preconditions

- The user has installed the app and completed (or skipped) the onboarding slides.
- The user is not currently authenticated (no active Firebase Auth session).
- The device has an active internet connection (or the screen is at least
  renderable offline with a connectivity warning).

---

## Acceptance Criteria

**Scenario 1 — Happy path: valid 10-digit number (starts with 6-9)**

> Given the user is on the phone-number entry screen
> and the "+91" prefix is displayed and non-editable
> When the user enters a valid 10-digit number starting with a digit between 6
> and 9 (e.g., "9876543210")
> and taps the "Continue" button
> Then the app fires the `signup_started` analytics event with no PII attached
> and the app navigates to the OTP verification screen
> and the entered number is passed to Firebase Phone Auth as "+919876543210".

**Scenario 2 — Negative: number too short (fewer than 10 digits)**

> Given the user is on the phone-number entry screen
> When the user enters a 9-digit number (e.g., "987654321")
> and taps "Continue"
> Then the "Continue" button remains disabled or an inline validation error is
> displayed reading "Enter a valid 10-digit mobile number"
> and navigation does not occur.

**Scenario 3 — Negative: number too long (more than 10 digits)**

> Given the user is on the phone-number entry screen
> When the user attempts to enter an 11-digit number (e.g., "98765432101")
> Then the input field restricts entry to a maximum of 10 digits
> and any digit beyond the 10th is not accepted into the field.

**Scenario 4 — Negative: invalid Indian mobile prefix (starts with 0-5)**

> Given the user is on the phone-number entry screen
> When the user enters a 10-digit number starting with a digit between 0 and 5
> (e.g., "0123456789" or "5123456789")
> and taps "Continue"
> Then an inline validation error is displayed reading "Enter a valid 10-digit
> mobile number"
> and navigation does not occur.

**Scenario 5 — Negative: alphabetic or special character input**

> Given the user is on the phone-number entry screen
> When the user types or pastes text containing alphabetic or special characters
> (e.g., "98a76!543b0")
> Then the input formatter strips all non-digit characters
> and only the digits are retained in the field.

**Scenario 6 — Locked +91 prefix is non-editable**

> Given the user is on the phone-number entry screen
> When the user attempts to tap, select, delete, or modify the "+91" prefix
> Then the prefix remains unchanged and the cursor stays within the 10-digit
> entry area
> and the prefix is visually distinct (e.g., greyed-out label or separate
> non-editable container).

**Scenario 7 — Negative: empty field shows validation error**

> Given the user is on the phone-number entry screen
> and the 10-digit input field is empty
> When the user taps "Continue"
> Then the "Continue" button is disabled or an inline validation error is
> displayed reading "Enter a valid 10-digit mobile number"
> and navigation does not occur.

---

## Edge Cases (QA-identified)

### 1. Input Formatting

| # | Scenario | Input | Expected Behaviour |
|---|----------|-------|--------------------|
| 1.1 | Pasting "+91" followed by 10 digits | `+919876543210` | Input formatter strips the leading `+91` prefix. Field shows `9876543210`. Validation passes. |
| 1.2 | Pasting "091" followed by 10 digits | `0919876543210` | Formatter strips leading `091`. Field shows `9876543210`. |
| 1.3 | Pasting "+91" with fewer than 10 digits | `+9198765` | Prefix stripped; field shows `98765`. On Continue, inline error displayed. |
| 1.4 | Input contains spaces | `98765 43210` | Non-digit characters stripped in real time. Field shows `9876543210`. |
| 1.5 | Input contains dashes | `987-654-3210` | Dashes stripped. Field shows `9876543210`. |
| 1.6 | Input contains parentheses | `(987) 654 3210` | Parentheses and spaces stripped. Field shows `9876543210`. |
| 1.7 | Leading zero in 10-digit part | `0123456789` | Input accepted (10 digits), but rejected on Continue — starts with `0`. |
| 1.8 | Pasting a non-Indian number | `+14155551234` | `+` stripped, digits `14155551234` capped at 10: `1415555123`. Rejected on Continue (starts with `1`). |
| 1.9 | Pasting only "+91" with no digits | `+91` | Prefix stripped; field empty. Continue shows validation error. |

### 2. Boundary Conditions

| # | Scenario | Expected Behaviour |
|---|----------|--------------------|
| 2.1 | Exactly 9 digits | Inline error on Continue. |
| 2.2 | Exactly 10 valid digits | Validation passes. OTP flow begins. |
| 2.3 | 11th digit typed | Input formatter rejects; field stays at 10 digits. |
| 2.4 | 11 digits pasted | Formatter truncates to first 10 digits. |
| 2.5 | Empty field | Inline error on Continue. |
| 2.6 | Whitespace-only | Stripped to empty; inline error on Continue. |

### 3. Platform-Specific

| # | Scenario | Expected Behaviour |
|---|----------|--------------------|
| 3.1 | iOS keyboard type | Number pad presented. No alphabetic keys. |
| 3.2 | Android keyboard type | Number pad presented. No alphabetic keys. |
| 3.3 | Physical keyboard on tablet | Input formatter strips non-digits regardless. |
| 3.4 | iOS autofill from contacts | Formatter processes autofilled value; strips prefix/formatting. |
| 3.5 | Android autofill from Google | Same behaviour as iOS. |

### 4. Accessibility

| # | Scenario | Expected Behaviour |
|---|----------|--------------------|
| 4.1 | Screen reader announces prefix | VoiceOver/TalkBack announces "+91" as "Country code, plus 91, not editable". |
| 4.2 | Screen reader announces input field | Label "Phone number" or "10-digit mobile number" announced. |
| 4.3 | Validation error announced | Error message announced immediately via live region. |
| 4.4 | Continue button state | Disabled state communicated to assistive technology. |
| 4.5 | Tap target sizes | Continue button >= 48x48 dp (Android) / 44x44 pt (iOS). |
| 4.6 | Focus order | Logical: prefix (informational) -> phone input -> Continue button. |
| 4.7 | Contrast ratio | Error text >= 4.5:1 in both light and dark mode. |

### 5. Visual / Layout

| # | Scenario | Expected Behaviour |
|---|----------|--------------------|
| 5.1 | Dark mode | All elements (prefix, input, error, button) legible with WCAG AA contrast. |
| 5.2 | Dynamic font 1.5x | Text scales; no clipping or overlap. |
| 5.3 | Dynamic font 2x | Screen remains functional; no elements pushed off-screen. |
| 5.4 | iPhone SE 2nd gen (Tier 2) | All elements visible without overflow. |
| 5.5 | Low-end Android 8 (Tier 2) | Renders correctly; no visual artefacts. |

### 6. Concurrency / Timing

| # | Scenario | Expected Behaviour |
|---|----------|--------------------|
| 6.1 | Rapid double-tap on Continue | Only one OTP request sent. Button disabled on first tap with loading indicator. |
| 6.2 | Tap Continue, then edit number | In-flight request completes for original number. No second OTP sent without explicit tap. |
| 6.3 | Network timeout during OTP | Loading indicator shown; on timeout, button re-enabled with error message. |
| 6.4 | App backgrounded during OTP request | Correct state shown on return (OTP screen or error). No crash. |

### 7. Telemetry

| # | Scenario | Expected Behaviour |
|---|----------|--------------------|
| 7.1 | `signup_started` fires on valid submit | Event logged exactly once when OTP request is initiated. No PII. |
| 7.2 | Event does NOT fire on validation failure | Invalid/empty number does not trigger telemetry. |

---

## Definition of Done

- [ ] Code merged to `main` via an approved PR.
- [ ] Widget test for the phone-entry screen covering all 7 acceptance-criteria
      scenarios.
- [ ] Integration test for the OTP flow (phone entry through to OTP screen
      transition) running against the Firebase Auth Emulator.
- [ ] `signup_started` telemetry event logged via Firebase Analytics when the user
      taps "Continue" with a valid number, verified in test.
- [ ] Accessibility check: screen-reader compatible with semantic labels on the
      prefix, input field, validation error, and Continue button (TalkBack on
      Android, VoiceOver on iOS) — per SRS section 5.6.
- [ ] Dark-mode visual check: phone-entry screen renders correctly in both light
      and dark themes, with WCAG 2.1 AA contrast ratios (4.5:1 minimum for body
      text).
- [ ] Tap targets are at least 48x48 dp (Android) / 44x44 pt (iOS) — per SRS
      section 5.6.
- [ ] QA reviewed and verified all scenarios and edge cases.
- [ ] Documentation updated (screen catalogue, developer README if applicable).

## Invariant Compliance

- [x] **Money is integer paise (invariant 1).** Not applicable — this screen
      handles no monetary values. Compliant by absence.
- [x] **No client writes to `simplifiedBalances` (invariant 2).** Not applicable
      — this screen does not interact with Firestore balance documents. Compliant
      by absence.
- [x] **System share sheet only (invariant 3).** Not applicable — this screen
      performs no sharing actions. Compliant by absence.
- [x] **Single Firebase project (invariant 4).** The phone-entry screen uses
      Firebase Phone Auth from the single production project. All pre-merge tests
      run against the Firebase Emulator Suite. Compliant.

---

## Technical Approach (Architect)

### 1. Widget Tree (High Level)

```
PhoneEntryScreen (ConsumerWidget)
 |-- Scaffold
     |-- SafeArea
         |-- Padding
             |-- Column (mainAxisAlignment: center)
                 |-- _Header
                 |   |-- Text ("Enter your mobile number")
                 |   |-- Text (subtitle / microcopy)
                 |-- SizedBox (spacing)
                 |-- _PhoneInputRow
                 |   |-- Container (locked prefix)
                 |   |   |-- Text ("+91", style: bold, non-interactive)
                 |   |-- Expanded
                 |       |-- TextField
                 |           |-- controller: _phoneController (10-digit only)
                 |           |-- keyboardType: TextInputType.number
                 |           |-- inputFormatters: [IndianPhoneInputFormatter]
                 |           |-- maxLength: 10 (counter hidden)
                 |           |-- decoration: (hint "00000 00000", no prefix)
                 |-- SizedBox (spacing, 8 dp)
                 |-- _ErrorText (conditionally visible)
                 |   |-- Text (error message, style: Coral Red #E76F51)
                 |-- Spacer or SizedBox
                 |-- _ContinueButton
                     |-- FilledButton (full-width, min height 48 dp)
                         |-- enabled: phoneNumber.length == 10 && !isLoading
                         |-- child: isLoading ? CircularProgressIndicator
                                             : Text("Continue")
```

Key design notes:

- The `+91` prefix is a **sibling widget**, not part of the `TextField`. It is
  rendered inside a styled `Container` that visually appears as part of the same
  input row but is non-focusable and non-editable. This eliminates any risk of
  the user moving the cursor into or deleting the prefix.
- Tap targets for the Continue button meet the 48x48 dp Android minimum (SRS
  section 5.6).
- Semantic labels are applied: `Semantics(label: 'Country code, India, plus 91')`
  on the prefix, and a `TextField` semantics label of `'10-digit mobile number'`
  for screen-reader compatibility.

### 2. Riverpod Provider Shape

```dart
// lib/features/auth/providers/phone_entry_provider.dart

@freezed
class PhoneEntryState with _$PhoneEntryState {
  const factory PhoneEntryState({
    @Default('') String phoneNumber,   // raw 10-digit string, no prefix
    String? validationError,            // null when valid or not yet validated
    @Default(false) bool isLoading,     // true while awaiting FR-AU-03
  }) = _PhoneEntryState;
}

@riverpod
class PhoneEntryNotifier extends _$PhoneEntryNotifier {
  @override
  PhoneEntryState build() => const PhoneEntryState();

  void updatePhoneNumber(String value);  // sets phoneNumber, clears error
  void submit();                         // validates, then triggers OTP
}
```

| Provider | Type | Purpose |
|---|---|---|
| `phoneEntryNotifierProvider` | `Notifier<PhoneEntryState>` | Owns phone input form state, validation, and submit action. |
| `authRepositoryProvider` | `Provider<AuthRepository>` | Thin wrapper around `FirebaseAuth.instance`. Lives in `lib/data/repositories/`. |

**Connection to FR-AU-03:** When `submit()` passes validation, it sets
`isLoading: true`, calls
`ref.read(authRepositoryProvider).verifyPhoneNumber('+91$phoneNumber', ...)`,
and on the `codeSent` callback, navigates to the OTP screen (passing the
`verificationId`). On error, it sets `isLoading: false` and populates
`validationError` with a user-friendly message.

### 3. Route/Navigation Entry

Per SRS section 6.3, the phone-entry screen is **screen 2** in the navigation
graph:

```
/splash --> /onboarding --> /auth/phone --> /auth/otp --> /auth/profile-setup --> /home
```

GoRouter configuration (proposed ADR-0007):

```dart
GoRoute(
  path: '/auth/phone',
  name: 'phoneEntry',
  builder: (context, state) => const PhoneEntryScreen(),
),
```

A `redirect` guard at the router level checks
`FirebaseAuth.instance.currentUser`. If the user is already authenticated,
`/auth/phone` redirects to `/home` (FR-AU-07 auto-login). The phone-entry screen
pushes to `/auth/otp` on successful OTP dispatch so the user can press back to
correct their number.

### 4. Locked +91 Prefix — Input Formatter Implementation

The prefix is enforced at **three levels**:

**Level 1 — Visual separation.** The `+91` text is a separate, non-editable
widget. The `TextEditingController` never contains the prefix. The full E.164
number (`+91XXXXXXXXXX`) is assembled only at submit time.

**Level 2 — `TextInputFormatter` (digits only, 10 chars max):**

```dart
// lib/features/auth/widgets/indian_phone_input_formatter.dart

class IndianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final stripped = _stripCountryPrefix(digitsOnly);
    final clamped =
        stripped.length > 10 ? stripped.substring(0, 10) : stripped;
    return TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
  }

  String _stripCountryPrefix(String digits) {
    if (digits.length > 10 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length > 10 && digits.startsWith('091')) {
      return digits.substring(3);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }
}
```

**Level 3 — Paste handling.** The `_stripCountryPrefix` logic handles common
paste patterns (`+919876543210`, `919876543210`, `09876543210`). The `+` is
stripped by the `[^\d]` regex before prefix detection runs.

This three-level approach ensures the controller's `.text` is **always** 0-10
ASCII digits with no prefix, spaces, or non-numeric characters.

### 5. Validation Logic

```dart
// lib/core/validators.dart

final indianMobileRegex = RegExp(r'^[6-9]\d{9}$');

String? validateIndianMobile(String digits) {
  if (digits.isEmpty) return 'Please enter your mobile number';
  if (digits.length < 10) return 'Mobile number must be 10 digits';
  if (!indianMobileRegex.hasMatch(digits)) {
    return 'Please enter a valid Indian mobile number';
  }
  return null;
}
```

**Location:** `lib/core/validators.dart` — reusable across features (e.g.,
FR-FR-01 "Add friend by number").

**When validation runs:** On submit only (not on every keystroke) to avoid
premature error display. Error is cleared when the user resumes editing. The
Continue button is passively gated on `phoneNumber.length == 10`.

### 6. Package Recommendation

**Decision:** Build a bespoke phone input widget. Do not use
`intl_phone_number_input` or `phone_form_field`.

**Rationale (proposed ADR-0016):**

| Criterion | `intl_phone_number_input` | Bespoke widget |
|---|---|---|
| Country selector | Full multi-country picker | Not needed; +91 only (SRS section 1.3) |
| Dependency weight | ~1.5 MB native binary per platform | Zero additional dependencies |
| Customisation | Must fight package API for locked prefix | Full control |
| Testing | Requires platform-channel mocking | Pure Dart; trivially testable |

### 7. Feature Folder Layout

```
lib/features/auth/
  screens/
    phone_entry_screen.dart
  widgets/
    indian_phone_input_formatter.dart
    phone_input_row.dart
  providers/
    phone_entry_provider.dart
    phone_entry_provider.g.dart

lib/core/
  validators.dart

lib/data/repositories/
  auth_repository.dart
```

---

## Implementation Notes

- This story covers the phone-entry screen only. OTP verification (FR-AU-03,
  FR-AU-04, FR-AU-05) is a separate story.
- The `signup_started` event (SRS section 5.10) must not include PII.
- FR-AU-06 and FR-PR-01 share UI surface for profile editing — components should
  be designed for reuse.

---

*This story is ready to be opened as a GitHub Issue using the `user_story`
template. The next session can begin implementation.*
