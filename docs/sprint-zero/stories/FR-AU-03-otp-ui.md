# FR-AU-03-otp-ui: OTP Entry Screen UI

> Implementation-ready user story for the OTP entry screen UI (PR #6).
> Covers UI shell only — Firebase Auth wiring is deferred to PR #7.

---

## SRS Requirement ID(s)

FR-AU-03 (partial — UI only), FR-AU-04 (partial — UI only), FR-AU-05 (partial — timer UI only)

## Priority

**P0 — Must have**

## User Story

As a **user who has entered my phone number**,
I want to **enter the 6-digit OTP code sent to my phone**
so that **I can verify my identity and proceed with authentication**.

## Preconditions

- User has entered a valid +91 10-digit mobile number on the phone entry screen.
- The phone entry screen has navigated to `/auth/otp`, passing the phone number
  as a route parameter.
- (For this PR, no actual OTP is sent — the screen renders with stub callbacks.)

---

## Acceptance Criteria

**Scenario 1 (happy path — digit entry):**

> Given the OTP screen is displayed with six empty cells
> When I enter six digits one at a time
> Then each digit appears in its cell, focus auto-advances to the next cell,
> and `isComplete` becomes true after the sixth digit.

**Scenario 2 (happy path — paste):**

> Given the OTP screen is displayed with six empty cells
> When I paste a 6-digit numeric string from the clipboard
> Then all six cells populate simultaneously and `isComplete` becomes true.

**Scenario 3 (negative — incomplete entry):**

> Given I have entered fewer than 6 digits
> When submission is attempted (either by the system or programmatically)
> Then nothing happens — the stub submit callback is NOT invoked.

**Scenario 4 (negative — non-numeric paste):**

> Given the OTP screen is displayed
> When I paste a string that contains non-digit characters or is not exactly
> 6 digits
> Then the paste is rejected and the cells do not change.

**Scenario 5 (backspace behaviour):**

> Given I have entered some digits and the current cell is empty
> When I press backspace
> Then focus moves to the previous cell and that cell's content is cleared.

**Scenario 6 (resend timer):**

> Given the OTP screen has just mounted
> When I observe the countdown timer
> Then it starts at 30 seconds and counts down by 1 every second, and
> "Resend OTP" is disabled during the countdown.

**Scenario 7 (resend available):**

> Given the countdown timer has reached zero
> When I tap "Resend OTP"
> Then the stub resend callback fires, the `signup_otp_resend_requested`
> telemetry event logs, and the 30-second countdown resets.

**Scenario 8 (edit phone number):**

> Given the OTP screen is displayed
> When I tap the back button or "Edit phone number" affordance
> Then the route pops back to the phone entry screen.

**Scenario 9 (telemetry — screen viewed):**

> Given the OTP screen mounts
> When the screen becomes visible
> Then the `signup_otp_screen_viewed` telemetry event fires with the phone
> number HASHED (SHA-256), never raw.

**Scenario 10 (phone number masking):**

> Given the phone number +91 9876543210 was passed from the phone entry screen
> When the OTP screen renders
> Then the subtitle displays the phone number with only the last 4 digits
> visible (e.g., "+91 XXXXXX3210").

**Scenario 11 (accessibility):**

> Given a screen reader is active (TalkBack or VoiceOver)
> When I navigate the OTP screen
> Then each OTP cell announces "Digit N of 6", the heading is announced as a
> heading, the resend button announces its disabled state and remaining seconds,
> and error messages are announced as live regions.

---

## Definition of Done

- [ ] Code merged to main via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] QA reviewed and verified.
- [ ] Telemetry / analytics events in place.
- [ ] Documentation updated (if applicable).

---

## Invariant Compliance

- [x] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [x] No client writes to simplifiedBalances (invariant 2) — N/A, no balance operations.
- [x] Uses system share sheet only (invariant 3) — N/A, no sharing.
- [x] Single Firebase project (invariant 4) — Compliant, no Firebase calls in this PR.

---

## Implementation Notes

- This PR implements the UI shell only. `submit()` calls a stub callback that
  logs telemetry and pops the route. Real Firebase Auth wiring is PR #7.
- The controller follows the `StateNotifier` pattern used by `PhoneEntryController`.
- The `AnalyticsService` interface needs to be extended to support event
  parameters (for the hashed phone number).
- Design artefacts: wireframe section 4 (`docs/design/04-wireframes/auth-flow.md`),
  screen spec SCR-04 (`docs/design/06-screen-specs/01-05-auth-and-profile-setup.md`),
  mockup (`docs/design/05-mockups/02-phone-and-otp.html`).
- The resend counter is in-memory only for this PR. Persistence decision deferred
  to Architect (open question in SCR-04).
- SMS Retriever auto-read is NOT included — that is PR #7.

---

## Architect Notes

Reviewed 2025-01-XX. Evaluates the proposed `OtpEntryController` shape against
`docs/design/07-technical/state-management.md` section 2.2, the existing
`PhoneEntryController` pattern (PR #4), and the telemetry plan.

### Decision 1: StateNotifier (PR #6) with Migration Path to AsyncNotifier (PR #7)

**Approved: manual `StateNotifier<OtpEntryState>` for this PR.**

The state-management doc specifies `@riverpod AsyncNotifier` for `otpNotifierProvider`.
However, `PhoneEntryController` (PR #4) already ships as a manual `StateNotifier`, and
this PR has no async operations (submit and resend are stubs). Introducing
code-generated `AsyncNotifier` now would create an inconsistency with the phone entry
controller in the same feature folder.

Plan:
- PR #6 uses manual `StateNotifierProvider<OtpEntryController, OtpEntryState>`,
  screen-scoped, matching `PhoneEntryController`.
- PR #7 (Firebase Auth wiring) migrates both `PhoneEntryController` and
  `OtpEntryController` to `@riverpod AsyncNotifier` to align with the design doc.
  This migration is tracked as a PR #7 requirement, not deferred indefinitely.

### Decision 2: Timer Ownership

**Approved: controller owns the `Timer`.**

The countdown `Timer` must live inside `OtpEntryController` and be cancelled in
`dispose()` (which is inherited from `StateNotifier` — use `@override`). This
ensures the timer is cancelled when the screen is popped and the provider is
auto-disposed.

One refinement: use `Timer.periodic` with a one-second interval rather than
recursive `Future.delayed`, to avoid drift and simplify cancellation.

### Decision 3: AnalyticsService Extension

**Approved: add optional `parameters` to the existing method.**

Extend `AnalyticsService.logEvent` to:

```dart
Future<void> logEvent({
  required String name,
  Map<String, Object>? parameters,
});
```

This is backward-compatible (existing call sites pass no parameters and continue
to work). The `FirebaseAnalyticsService` implementation already delegates to
`FirebaseAnalytics.logEvent`, which accepts a `parameters` map. Confirm that the
existing `PhoneEntryController` tests still pass after the signature change (they
should, since the new parameter is optional).

**Hand-off:** The `AnalyticsService` interface change is in
`lib/features/auth/application/analytics_provider.dart`, which is outside the
Architect's edit scope. Flutter Dev should implement this change.

### Decision 4: State Shape — Modifications Required

The proposed `OtpEntryState` is mostly sound. The following modifications are
required or recommended:

#### 4a. Immutable Digits List (required)

`List<String> digits` is mutable. An immutable state class must not expose a
mutable `List`. Options:

- Use `List<String>.unmodifiable(digits)` in the constructor/`copyWith`.
- Or use an `IList<String>` from `fast_immutable_collections` if it is already a
  dependency.

The simpler approach (`List.unmodifiable`) is preferred to avoid a new dependency.

#### 4b. Resend Count State (required)

The state has `canResend` but no `resendCount`. FR-AU-05 specifies a max of 3
resends per 10 minutes. The state must track the count so the UI can display
remaining attempts and the controller can enforce the cap. Add:

```dart
final int resendCount; // default 0, incremented on each resend, max 3
```

For PR #6, the cap logic is soft (controller increments and disables at 3). PR #7
adds the 10-minute sliding window with real timer logic.

#### 4c. Remove Callback Parameters from `submit` and `resend` (required)

The proposed signatures take callbacks:

```dart
Future<void> submit(Future<void> Function(String otp) onSubmit);
void resend(VoidCallback onResend);
```

This breaks the `StateNotifier` pattern, where the controller mutates state and
the UI reacts to state changes. Injecting behaviour via callbacks makes the
controller harder to test and couples it to the call site.

Instead:
- `submit()` should set `isSubmitted = true` (and log telemetry). The screen
  widget listens for `isSubmitted` via `ref.listen` and performs navigation.
- `resend()` should increment `resendCount`, reset `remainingSeconds` to 30,
  restart the timer, and log telemetry. The screen widget's `ref.listen` reacts
  if needed.

For PR #6, the stubs simply update state and log events. PR #7 replaces the stubs
with real Firebase Auth calls inside the controller.

#### 4d. Phone Number Hashing (recommendation)

The `phoneNumber` constructor parameter is documented as "used for hashing only."
Good. The controller should hash at construction time (SHA-256) and store only the
hash, never retaining the raw digits in memory longer than necessary. Use
`crypto` package (`sha256.convert(utf8.encode(phoneNumber)).toString()`). The
hashed value is passed to `logEvent` parameters.

### Decision 5: Telemetry Event Name Discrepancy (action required)

The story file uses `signup_otp_screen_viewed` and `signup_otp_resend_requested`,
but the canonical telemetry plan (`docs/design/07-technical/telemetry-plan.md`)
and screen spec (SCR-04) use `otp_screen_viewed` and `otp_resend_tapped`.

**Resolution:** Use the telemetry plan names (`otp_screen_viewed`,
`otp_resend_tapped`). The telemetry plan is the authoritative source for event
names. The story file acceptance criteria (scenarios 7 and 9) should be read as
referencing the telemetry plan names. This discrepancy does not block the PR but
Flutter Dev should use the telemetry plan names in the implementation.

Additionally, `otp_resend_tapped` requires an `attempt_number` parameter (int,
1-3), which is another reason `AnalyticsService` needs the `parameters` map.

### Approved Controller Shape

After the modifications above, the approved shape is:

```dart
class OtpEntryState {
  const OtpEntryState({
    this.digits = const ['', '', '', '', '', ''],
    this.remainingSeconds = 30,
    this.canResend = false,
    this.resendCount = 0,
    this.validationError,
    this.isSubmitted = false,
  });

  final List<String> digits; // must be unmodifiable
  final int remainingSeconds;
  final bool canResend;
  final int resendCount;
  final String? validationError;
  final bool isSubmitted;

  bool get isComplete => digits.every((d) => d.isNotEmpty);
  bool get canSubmit => isComplete && !isSubmitted;
  String get otp => digits.join();

  OtpEntryState copyWith({...}); // use List.unmodifiable for digits
}

class OtpEntryController extends StateNotifier<OtpEntryState> {
  OtpEntryController({
    required AnalyticsService analytics,
    required String phoneNumber, // raw 10 digits; hashed immediately
  });

  void setDigit(int index, String digit);
  void clearDigit(int index);
  void pasteOtp(String code);
  void submit();              // no callback; sets isSubmitted
  void startResendTimer();
  void resend();              // no callback; increments resendCount
  @override
  void dispose();             // cancels Timer
}
```

### Deferred to PR #7

- Migration of `PhoneEntryController` and `OtpEntryController` to
  `@riverpod AsyncNotifier` (code generation).
- Real Firebase Auth OTP send/verify calls.
- 10-minute sliding window for resend rate limiting.
- Android SMS Retriever auto-read.
- `authRepositoryProvider` integration.
