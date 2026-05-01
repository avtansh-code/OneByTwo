# FR-AU-03-04-05-auth-wiring: Wire Firebase Phone Auth to OTP Flow

> Implementation-ready user story for Firebase Phone Auth wiring (PR #7).
> Connects the phone entry and OTP screens (PRs #4 and #6) to Firebase Auth.

---

## SRS Requirement ID(s)

FR-AU-03 (OTP delivery via Firebase Phone Auth),
FR-AU-04 (SMS Retriever auto-read on Android),
FR-AU-05 (3-retry-per-10-minute resend cooldown)

## Priority

**P0 — Must have**

## Story Points

**8** (medium complexity, multiple integration points)

## User Story

As a **user who has entered my phone number**,
I want to **receive and verify an OTP via Firebase Phone Auth**
so that **I can authenticate and proceed to the app**.

## Preconditions

- PR #4 (phone entry screen) merged — screen and controller with stub submit.
- PR #6 (OTP entry screen UI) merged — screen, controller, OTP input widget
  with stub submit and resend callbacks.
- Architect's error-code mapping table delivered at
  `docs/design/07-technical/auth-error-codes.md`.

---

## Acceptance Criteria

**Scenario 1 (happy path — OTP request):**

> Given I have entered a valid +91 10-digit number on the phone entry screen
> When I tap "Continue"
> Then Firebase `verifyPhoneNumber` is called with the E.164-formatted number,
> the `otp_send_succeeded` telemetry event fires with `duration_ms`,
> and I am navigated to the OTP entry screen.

**Scenario 2 (negative — OTP request failure):**

> Given I have entered a valid number that Firebase rejects
> When I tap "Continue"
> Then the error is mapped to a domain `AuthError` per the architect's
> error-code table,
> an inline error message appears matching the user-facing copy from
> `AuthError.message`,
> the `otp_send_failed` telemetry event fires with `error_code` (no PII),
> and no generic `Exception` is caught.

**Scenario 3 (happy path — OTP verification):**

> Given I am on the OTP screen and have entered the correct 6-digit OTP
> When verification completes
> Then `signInWithCredential` succeeds with `PhoneAuthProvider.credential`,
> the `otp_verification_succeeded` telemetry event fires with `is_new_user`
> and `duration_ms`,
> and I am navigated to a placeholder "Authenticated" screen.

**Scenario 4 (negative — OTP verification failure):**

> Given I am on the OTP screen and have entered an incorrect 6-digit OTP
> When verification is attempted
> Then `signInWithCredential` returns an error,
> an inline error appears with the mapped user-facing message,
> the `otp_verification_failed` telemetry event fires with `error_code`,
> and the OTP cells are cleared so I can retry.

**Scenario 5 (happy path — resend OTP):**

> Given the 30-second countdown has elapsed and I have resent fewer than
> 3 times within the current 10-minute window
> When I tap "Resend OTP"
> Then a new OTP is requested via Firebase `verifyPhoneNumber`,
> the `otp_resend_tapped` telemetry event fires with `attempt_number`,
> and the 30-second countdown resets.

**Scenario 6 (negative — resend cap at 3 per 10 minutes):**

> Given I have already resent the OTP 3 times within the current 10-minute
> sliding window
> When I attempt a 4th resend
> Then the "Resend OTP" button remains disabled,
> an error message is displayed indicating the maximum resend limit has been
> reached,
> the `otp_resend_exhausted` telemetry event fires,
> and no Firebase call is made.

**Scenario 7 (happy path — SMS Retriever on Android):**

> Given the app is running on Android and SMS Retriever is available
> When an SMS containing the OTP and the app hash arrives
> Then the OTP cells auto-populate without user action,
> the `otp_auto_read_succeeded` telemetry event fires with `duration_ms`,
> and verification proceeds automatically.

**Scenario 8 (platform behaviour — iOS manual entry):**

> Given the app is running on iOS
> When an OTP SMS arrives
> Then the user must manually enter the 6-digit code,
> and SMS Retriever is not initialised.

**Scenario 9 (telemetry completeness):**

> Given the auth wiring is active
> When the following actions occur
> Then the corresponding telemetry events fire:
>
> | Action | Event | Parameters |
> |---|---|---|
> | Successful OTP request | `otp_send_succeeded` | `duration_ms` |
> | Failed OTP request | `otp_send_failed` | `error_code` (no PII) |
> | Successful OTP verification | `otp_verification_succeeded` | `is_new_user`, `duration_ms` |
> | Failed OTP verification | `otp_verification_failed` | `error_code` |
> | SMS Retriever populates (Android) | `otp_auto_read_succeeded` | `duration_ms` |
> | SMS Retriever fails/times out | `otp_auto_read_failed` | `error_type` |
> | Resend tapped | `otp_resend_tapped` | `attempt_number` (1-3) |
> | Resend cap hit | `otp_resend_exhausted` | — |

**Scenario 10 (negative — error mapping, no generic catches):**

> Given any `FirebaseAuthException` is thrown during OTP send or verify
> When the exception is caught
> Then it is mapped to a user-friendly domain error per the architect's
> error-code table at `docs/design/07-technical/auth-error-codes.md`,
> raw Firebase exception messages are never displayed to the user,
> and no bare `catch (e)` or `on Exception` catch-all is used.

---

## Definition of Done

- Code merged to `main` via approved PR.
- `PhoneAuthRepository` implemented with `requestOtp`, `verifyOtp`,
  `resendOtp`, and `signOut` methods.
- All `FirebaseAuthException` codes mapped to domain `AuthError` values.
- 3-per-10-minute resend cap enforced with a sliding window.
- SMS Retriever integration on Android (no-op on iOS).
- Unit tests with mocked `firebase_auth` — all passing.
- Integration tests against Firebase Auth emulator — all passing.
- Coverage on `lib/features/auth/**` meets or exceeds SRS thresholds.
- All telemetry events verified in tests.
- QA reviewed and signed off.

---

## Invariant Compliance

- [x] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [x] No client writes to `simplifiedBalances` (invariant 2) — N/A.
- [x] Uses system share sheet only (invariant 3) — N/A, no sharing.
- [x] Single Firebase project (invariant 4) — Compliant; all testing uses
      the Firebase Auth emulator, no secondary project.

---

## Out of Scope

- Profile setup screen (FR-AU-06) — deferred to PR #8.
- User document creation in Firestore — deferred to PR #8.
- Sign-out UI (FR-AU-08) — later PR.
- Session persistence beyond native `firebase_auth` token management.
- reCAPTCHA Enterprise custom integration.
- Storing `verificationId` in `SharedPreferences`.

---

## Dependencies

| Dependency | Status |
|---|---|
| PR #4 — phone entry screen | Merged |
| PR #6 — OTP entry screen UI | Merged |
| Architect's error-code mapping table | Delivered |

---

## Test Requirements

- **Unit tests (mocked firebase_auth):**
  - `phone_auth_repository_test.dart` — requestOtp, verifyOtp, resendOtp,
    error mapping for every `FirebaseAuthException` code.
  - `phone_entry_controller_test.dart` (extended) — submit triggers requestOtp,
    navigation event, telemetry, error path.
  - `otp_entry_controller_test.dart` (extended) — submit triggers verifyOtp,
    post-auth navigation, resend cap enforcement, auto-fill path, telemetry.
- **Integration tests (auth emulator):**
  - `integration_test/auth/phone_auth_flow_test.dart` — end-to-end happy path
    and negative case against `localhost:9099`.
- **Coverage:** `lib/features/auth/**` at or above SRS thresholds.

---

## Implementation Notes

- Use `verifyPhoneNumber` on both Android and iOS (per architect notes —
  `signInWithPhoneNumber` is web-only in flutter_fire).
- Repository is the sole layer interacting with `FirebaseAuth`. Controllers
  depend on the repository provider, not on `FirebaseAuth` directly.
- Resend rate limit uses a sliding window tracked in-memory by the controller.
- Placeholder "Authenticated" screen displays the user's UID. PR #8 replaces
  this with the profile setup flow.
- Event names follow the canonical telemetry plan
  (`docs/design/07-technical/telemetry-plan.md`).

---

## References

- SRS: `docs/OneByTwo_Requirements_Spec.md` — FR-AU-03, FR-AU-04, FR-AU-05
- Wireframe: `docs/design/04-wireframes/auth-flow.md`
- Error codes: `docs/design/07-technical/auth-error-codes.md`
- Telemetry plan: `docs/design/07-technical/telemetry-plan.md`
- Feature PR conventions: `docs/patterns/feature-pr-conventions.md`
- Prior stories: `docs/sprint-zero/stories/FR-AU-03-otp-ui.md` (PR #6)
